import Combine
import Foundation
import Network

// MARK: - ProxyClientError

enum ProxyClientError: LocalizedError {
    case invalidConfiguration(String)
    case authenticationRequired
    case connectionRefused
    case timeout
    case httpStatus(Int)
    case probeFailed(String)
    case cancelled
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration(let reason):
            return reason
        case .authenticationRequired:
            return "Proxy yêu cầu xác thực. Kiểm tra username/password."
        case .connectionRefused:
            return "Proxy từ chối kết nối (port đóng hoặc sai địa chỉ)."
        case .timeout:
            return "Proxy không phản hồi (timeout)."
        case .httpStatus(let code):
            return "Proxy trả về HTTP \(code)."
        case .probeFailed(let detail):
            return detail
        case .cancelled:
            return "Đã huỷ."
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - ProxySessionDelegate
//
// Xử lý thử thách xác thực của proxy.
//
// Quan trọng: KHÔNG bỏ qua kiểm tra TLS. Với `NSURLAuthenticationMethodServerTrust`
// luôn trả `.performDefaultHandling` để hệ thống xác thực chứng chỉ máy chủ.
// Điều này giữ nguyên nguyên tắc: không MITM, không cài CA, không giải mã HTTPS.
final class ProxySessionDelegate: NSObject, URLSessionTaskDelegate {

    private let proxyHost: String
    private let proxyPort: Int
    private let credential: URLCredential?

    /// CFNetwork dùng method này cho xác thực proxy. Hằng số không có trong
    /// Foundation nên dùng đúng chuỗi mà CFNetwork phát ra.
    private static let proxyAuthMethod = "NSURLAuthenticationMethodHTTPProxyAuthentication"

    init(proxyHost: String, proxyPort: Int, credential: URLCredential?) {
        self.proxyHost = proxyHost
        self.proxyPort = proxyPort
        self.credential = credential
        super.init()
    }

    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        resolve(challenge, completionHandler: completionHandler)
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        resolve(challenge, completionHandler: completionHandler)
    }

    private func resolve(
        _ challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let space = challenge.protectionSpace
        let method = space.authenticationMethod

        // Chứng chỉ máy chủ: luôn để hệ thống xác thực. Không bypass.
        if method == NSURLAuthenticationMethodServerTrust {
            completionHandler(.performDefaultHandling, nil)
            return
        }

        // CFNetwork báo xác thực proxy bằng method riêng. Khi đó chắc chắn là
        // proxy hỏi, không cần so host (với CONNECT, protectionSpace có thể mang
        // host đích thay vì host proxy).
        if method == ProxySessionDelegate.proxyAuthMethod, let credential {
            completionHandler(.useCredential, credential)
            return
        }

        // Basic/Digest/NTLM: chỉ trả credential khi đúng endpoint proxy, để
        // không gửi nhầm mật khẩu cho máy chủ đích.
        let isStandardAuth =
            method == NSURLAuthenticationMethodHTTPBasic ||
            method == NSURLAuthenticationMethodHTTPDigest ||
            method == NSURLAuthenticationMethodNTLM

        let matchesProxyEndpoint =
            space.host.caseInsensitiveCompare(proxyHost) == .orderedSame &&
            (space.port == proxyPort || space.port == 0)

        if isStandardAuth, matchesProxyEndpoint, let credential {
            completionHandler(.useCredential, credential)
            return
        }

        completionHandler(.performDefaultHandling, nil)
    }
}

// MARK: - LatencyState
//
// Cờ hoàn tất an toàn luồng cho phép đo latency. Đặt ở phạm vi file (không nằm
// trong @MainActor class) để dùng được từ callback của NWConnection.
final class LatencyState {
    private let lock = NSLock()
    private var completed = false

    func claimCompletion() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        if completed { return false }
        completed = true
        return true
    }
}

// MARK: - ProxySessionProvider
//
// Cầu nối để các service khác trong app dùng chung session có proxy.
//
// Trước đây mọi service gọi `URLSession.shared`, mà session đó không thể gắn
// `connectionProxyDictionary` — nên chỉ các request do ProxyClient tự tạo mới
// đi qua proxy. Provider này giữ một session cấu hình proxy (khi đã kết nối)
// và trả về session mặc định khi chưa kết nối.
//
// An toàn luồng: các service gọi từ background queue, nên dùng NSLock.
enum ProxySessionProvider {

    private static let lock = NSLock()
    private static var proxiedSession: URLSession?
    private static var proxyDictionarySnapshot: [AnyHashable: Any]?

    /// Session dùng cho request của app.
    static var session: URLSession {
        lock.lock()
        defer { lock.unlock() }
        return proxiedSession ?? URLSession.shared
    }

    static var isRoutingThroughProxy: Bool {
        lock.lock()
        defer { lock.unlock() }
        return proxiedSession != nil
    }

    /// Dictionary proxy hiện hành, để nơi nào buộc phải tự tạo
    /// `URLSessionConfiguration` vẫn gắn được proxy.
    static var currentProxyDictionary: [AnyHashable: Any]? {
        lock.lock()
        defer { lock.unlock() }
        return proxyDictionarySnapshot
    }

    static func install(_ session: URLSession?, proxyDictionary: [AnyHashable: Any]? = nil) {
        lock.lock()
        let previous = proxiedSession
        proxiedSession = session
        proxyDictionarySnapshot = proxyDictionary
        lock.unlock()

        if let previous, previous !== session {
            previous.finishTasksAndInvalidate()
        }
    }
}

// MARK: - ProxyClient

/// Quản lý kết nối proxy cấp ứng dụng và kiểm chứng kết nối bằng request thật.
///
/// PHẠM VI (quan trọng):
/// - Proxy áp dụng cho các `URLSession` do class này tạo ra.
/// - KHÔNG định tuyến toàn bộ traffic của hệ thống/ứng dụng khác.
/// - Muốn toàn hệ thống cần `NEPacketTunnelProvider` + entitlement
///   `com.apple.developer.networking.networkextension` trên App ID thật.
///
/// Trạng thái `.connected` chỉ được đặt sau khi request thật đi xuyên proxy
/// thành công và trả về IP egress.
@MainActor
final class ProxyClient: ObservableObject {

    static let shared = ProxyClient()

    // MARK: Published state

    @Published private(set) var state: ProxyConnectionState = .disconnected
    @Published private(set) var activeConfiguration: ProxyConfiguration?
    @Published private(set) var egressIP: String?
    @Published private(set) var connectedAt: Date?
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var networkType: ProxyNetworkType = .other
    @Published private(set) var lastTest: ProxyTestResult?
    @Published private(set) var isTesting: Bool = false
    @Published private(set) var lastError: String?
    /// Cảnh báo khi proxy chỉ hoạt động được một phần (ví dụ chỉ HTTP).
    @Published private(set) var connectionWarning: String?

    // MARK: Private

    private var session: URLSession?
    private var durationTimer: Timer?
    private let pathMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.innova.cheat.proxy.pathmonitor")
    private var isMonitoring = false

    /// Người dùng đang mong muốn kết nối (dùng cho auto-reconnect).
    private var wantsConnection = false
    private var lastPathWasSatisfied = true

    private let probeTimeout: TimeInterval = 12

    private init() {
        // Theo dõi kiểu mạng (Wi-Fi / 4G) suốt vòng đời app để hiển thị chính xác.
        // Auto-reconnect chỉ chạy khi `wantsConnection == true`.
        startPathMonitoring()
    }

    // MARK: - Session construction

    /// Tạo `URLSession` đi xuyên proxy. Public để các thành phần khác có thể
    /// chủ động dùng proxy nếu cần (không tự động áp dụng cho toàn app).
    func makeProxiedSession(for config: ProxyConfiguration, password: String?) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = probeTimeout
        configuration.timeoutIntervalForResource = probeTimeout * 2
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.connectionProxyDictionary = Self.proxyDictionary(for: config)

        let credential: URLCredential?
        if config.requiresAuthentication, let password, !password.isEmpty {
            credential = URLCredential(
                user: config.username,
                password: password,
                persistence: .forSession
            )
        } else {
            credential = nil
        }

        let delegate = ProxySessionDelegate(
            proxyHost: config.normalizedHost,
            proxyPort: config.port,
            credential: credential
        )
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    /// Dictionary proxy cho CFNetwork.
    ///
    /// Ghi chú kỹ thuật:
    /// - `.http` / `.https` đều là HTTP proxy: HTTPS đi qua CONNECT.
    ///   CFNetwork không hỗ trợ "proxy nói TLS" (TLS tới chính proxy) qua
    ///   `connectionProxyDictionary`, nên không có cấu hình riêng cho việc đó.
    /// - `.socks5` dùng khoá SOCKS. CFNetwork KHÔNG truyền username/password
    ///   cho SOCKS5 — xem `ProxyProtocol.credentialNote`.
    static func proxyDictionary(for config: ProxyConfiguration) -> [AnyHashable: Any] {
        let host = config.normalizedHost
        let port = config.port

        switch config.proto {
        case .http, .https:
            return [
                "HTTPEnable": 1,
                "HTTPProxy": host,
                "HTTPPort": port,
                "HTTPSEnable": 1,
                "HTTPSProxy": host,
                "HTTPSPort": port,
                "ProxyAutoConfigEnable": 0,
                "ProxyAutoDiscoveryEnable": 0
            ]
        case .socks5:
            return [
                "SOCKSEnable": 1,
                "SOCKSProxy": host,
                "SOCKSPort": port,
                "ProxyAutoConfigEnable": 0,
                "ProxyAutoDiscoveryEnable": 0
            ]
        }
    }

    // MARK: - Connect / Disconnect

    func connect(_ config: ProxyConfiguration, password: String?) async {
        if let message = config.validationMessage {
            state = .failed(message)
            lastError = message
            return
        }

        wantsConnection = true
        state = .connecting
        lastError = nil
        activeConfiguration = config
        egressIP = nil
        connectionWarning = nil

        let newSession = makeProxiedSession(for: config, password: password)
        session?.invalidateAndCancel()
        session = newSession

        do {
            let outcome = try await runProbe(using: newSession)
            guard wantsConnection else {
                newSession.invalidateAndCancel()
                return
            }
            egressIP = outcome.ip
            connectionWarning = outcome.httpsBlocked
                ? "Proxy chỉ cho phép HTTP. Kết nối HTTPS (CONNECT) bị chặn — các trang https sẽ không tải được."
                : nil
            connectedAt = Date()
            elapsed = 0
            state = .connected
            ProxySessionProvider.install(newSession, proxyDictionary: Self.proxyDictionary(for: config))
            startDurationTimer()
        } catch {
            newSession.invalidateAndCancel()
            session = nil
            wantsConnection = false
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastError = message
            state = .failed(message)
            stopDurationTimer()
        }
    }

    /// Session đang kết nối, để tái sử dụng cho traffic thật của ứng dụng.
    /// `nil` khi chưa kết nối thành công.
    func activeProxiedSession() -> URLSession? {
        guard state.isConnected else { return nil }
        return session
    }

    func disconnect() {
        wantsConnection = false
        ProxySessionProvider.install(nil)
        session?.invalidateAndCancel()
        session = nil
        connectedAt = nil
        egressIP = nil
        elapsed = 0
        lastError = nil
        state = .disconnected
        stopDurationTimer()
    }

    // MARK: - Probe (egress IP)

    /// Một endpoint kiểm tra.
    ///
    /// `httpsProbe == true` nghĩa là request sẽ đi qua CONNECT tới cổng 443.
    /// Một số proxy chỉ cho phép HTTP thường (cổng 80) và chặn CONNECT — khi đó
    /// request HTTPS trả 403 nhưng HTTP lại thành công.
    private struct ProbeEndpoint {
        let url: URL
        let httpsProbe: Bool
    }

    /// Danh sách endpoint kiểm tra, ưu tiên HTTPS rồi fallback HTTP.
    ///
    /// Việc thử cả HTTP giúp phân biệt hai nguyên nhân 403:
    /// 1. Proxy chặn CONNECT (HTTPS fail, HTTP pass) → cảnh báo, vẫn dùng được HTTP.
    /// 2. Proxy/đích từ chối hoàn toàn (cả hai fail) → lỗi thật.
    private func probeEndpoints() -> [ProbeEndpoint] {
        var result: [ProbeEndpoint] = []
        if let u = URL(string: "https://api.ipify.org?format=json") {
            result.append(ProbeEndpoint(url: u, httpsProbe: true))
        }
        if let u = URL(string: "http://api.ipify.org?format=json") {
            result.append(ProbeEndpoint(url: u, httpsProbe: false))
        }
        if let u = URL(string: "https://ifconfig.me/ip") {
            result.append(ProbeEndpoint(url: u, httpsProbe: true))
        }
        if let u = URL(string: "http://ifconfig.me/ip") {
            result.append(ProbeEndpoint(url: u, httpsProbe: false))
        }
        return result
    }

    /// Kết quả dò: IP lấy được, hoặc lỗi kèm chẩn đoán.
    private struct ProbeOutcome {
        let ip: String
        /// `true` nếu chỉ HTTP hoạt động, HTTPS (CONNECT) bị chặn.
        let httpsBlocked: Bool
    }

    private func runProbe(using session: URLSession) async throws -> ProbeOutcome {
        let endpoints = probeEndpoints()

        // Lượt 1: HTTPS (đi qua CONNECT).
        var httpsFailure: ProxyClientError?
        for endpoint in endpoints where endpoint.httpsProbe {
            do {
                let ip = try await performProbe(endpoint, session: session)
                return ProbeOutcome(ip: ip, httpsBlocked: false)
            } catch let error as ProxyClientError {
                if case .authenticationRequired = error { throw error }
                httpsFailure = error
            }
        }

        // Lượt 2: HTTP thường. Nếu chạy được thì proxy sống, chỉ chặn CONNECT.
        var httpFailure: ProxyClientError?
        for endpoint in endpoints where !endpoint.httpsProbe {
            do {
                let ip = try await performProbe(endpoint, session: session)
                return ProbeOutcome(ip: ip, httpsBlocked: httpsFailure != nil)
            } catch let error as ProxyClientError {
                if case .authenticationRequired = error { throw error }
                httpFailure = error
            }
        }

        let finalFailure = httpFailure ?? httpsFailure ?? .unknown("Không có endpoint kiểm tra.")

        // 403/407 trên HTTPS mà không có endpoint nào chạy được: nêu rõ nguyên nhân
        // để không bị hiểu nhầm là sai mật khẩu.
        if case .httpStatus(403) = finalFailure {
            throw ProxyClientError.probeFailed(
                "Proxy trả HTTP 403. Nếu mật khẩu đúng, nguyên nhân thường là: "
                + "proxy chỉ cho phép một số đích, proxy chặn CONNECT/cổng 443, "
                + "hoặc đích chặn IP của proxy. Không phải lỗi xác thực."
            )
        }

        throw finalFailure
    }

    /// Thực hiện một request kiểm tra, trả về IP đọc được.
    private func performProbe(_ endpoint: ProbeEndpoint, session: URLSession) async throws -> String {
        var request = URLRequest(url: endpoint.url)
        request.httpMethod = "GET"
        request.timeoutInterval = probeTimeout
        request.setValue("application/json, text/plain", forHTTPHeaderField: "Accept")

        do {
            let (data, response) = try await session.data(for: request)

            if let http = response as? HTTPURLResponse {
                if http.statusCode == 407 {
                    throw ProxyClientError.authenticationRequired
                }
                guard (200...299).contains(http.statusCode) else {
                    throw ProxyClientError.httpStatus(http.statusCode)
                }
            }

            guard let ip = Self.parseEgressIP(from: data) else {
                throw ProxyClientError.unknown("Không đọc được IP từ phản hồi kiểm tra.")
            }
            return ip
        } catch let error as ProxyClientError {
            throw error
        } catch let error as URLError {
            if error.code == .userAuthenticationRequired ||
               error.code == .userCancelledAuthentication {
                throw ProxyClientError.authenticationRequired
            }
            throw Self.mapURLError(error)
        } catch {
            throw ProxyClientError.unknown(error.localizedDescription)
        }
    }

    nonisolated private static func parseEgressIP(from data: Data) -> String? {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ip = object["ip"] as? String {
            let trimmed = ip.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        if let text = String(data: data, encoding: .utf8) {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            // Chỉ nhận nếu trông giống một địa chỉ IP (tránh HTML lỗi).
            if !trimmed.isEmpty,
               trimmed.count <= 45,
               trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: "<> \n\r\t")) == nil {
                return trimmed
            }
        }
        return nil
    }

    private static func mapURLError(_ error: URLError) -> ProxyClientError {
        switch error.code {
        case .timedOut:
            return ProxyClientError.timeout
        case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .dnsLookupFailed:
            return ProxyClientError.connectionRefused
        case .cancelled:
            return ProxyClientError.cancelled
        case .userAuthenticationRequired, .userCancelledAuthentication:
            return ProxyClientError.authenticationRequired
        default:
            return ProxyClientError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Test (latency + egress IP)

    func test(_ config: ProxyConfiguration, password: String?) async -> ProxyTestResult {
        isTesting = true
        defer { isTesting = false }

        if let message = config.validationMessage {
            let result = ProxyTestResult(success: false, tcpLatencyMs: nil, egressIP: nil, message: message)
            lastTest = result
            return result
        }

        let latency = await Self.measureTCPLatency(host: config.normalizedHost, port: config.port)

        let testSession = makeProxiedSession(for: config, password: password)
        defer { testSession.invalidateAndCancel() }

        do {
            let outcome = try await runProbe(using: testSession)
            let latencyText = latency.map { " · \($0) ms" } ?? ""
            let httpsNote = outcome.httpsBlocked ? " (chỉ HTTP — HTTPS bị proxy chặn)" : ""
            let result = ProxyTestResult(
                success: true,
                tcpLatencyMs: latency,
                egressIP: outcome.ip,
                message: "Proxy hoạt động. IP: \(outcome.ip)\(latencyText)\(httpsNote)"
            )
            lastTest = result
            return result
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            let latencyText = latency.map { "TCP \($0) ms · " } ?? ""
            let result = ProxyTestResult(
                success: false,
                tcpLatencyMs: latency,
                egressIP: nil,
                message: latencyText + message
            )
            lastTest = result
            return result
        }
    }

    // MARK: - Routing verification

    /// Xác minh rằng request thực sự đi qua proxy.
    ///
    /// Cách làm: lấy IP egress hai lần — một lần bằng kết nối trực tiếp (không
    /// proxy), một lần qua proxy — rồi so sánh.
    ///
    /// Ý nghĩa:
    /// - Hai IP khác nhau → proxy đang thay đổi đường ra ⇒ request đi qua proxy.
    /// - IP qua proxy trùng IP của host proxy ⇒ proxy NAT ra chính nó.
    /// - Hai IP giống nhau → KHÔNG chứng minh được proxy có tác dụng (có thể
    ///   proxy trong suốt, cùng mạng, hoặc cấu hình không được áp dụng).
    func verifyRouting(_ config: ProxyConfiguration, password: String?) async -> ProxyRoutingVerification {
        let directIP = await Self.fetchDirectIP()

        let session = makeProxiedSession(for: config, password: password)
        defer { session.invalidateAndCancel() }

        var proxiedIP: String?
        var failureText: String?

        do {
            let outcome = try await runProbe(using: session)
            proxiedIP = outcome.ip
        } catch {
            failureText = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }

        guard let proxiedIP else {
            return ProxyRoutingVerification(
                directIP: directIP,
                proxiedIP: nil,
                proxyHost: config.normalizedHost,
                routedThroughProxy: false,
                message: "Không lấy được IP qua proxy. " + (failureText ?? "")
            )
        }

        if let directIP, directIP == proxiedIP {
            return ProxyRoutingVerification(
                directIP: directIP,
                proxiedIP: proxiedIP,
                proxyHost: config.normalizedHost,
                routedThroughProxy: false,
                message: "IP trực tiếp và IP qua proxy giống nhau (\(proxiedIP)). "
                    + "Không chứng minh được lưu lượng đã đi qua proxy — "
                    + "có thể proxy nằm cùng mạng hoặc cấu hình chưa được áp dụng."
            )
        }

        let matchesProxyHost = proxiedIP == config.normalizedHost
        var message = "IP trực tiếp: \(directIP ?? "không rõ") → IP qua proxy: \(proxiedIP). "
        if matchesProxyHost {
            message += "IP qua proxy trùng địa chỉ máy chủ proxy, nên lưu lượng đã rời máy qua proxy."
        } else {
            message += "Hai IP khác nhau, nên lưu lượng đã đi qua một đường khác (proxy)."
        }

        return ProxyRoutingVerification(
            directIP: directIP,
            proxiedIP: proxiedIP,
            proxyHost: config.normalizedHost,
            routedThroughProxy: true,
            message: message
        )
    }

    /// Lấy IP công khai KHÔNG dùng proxy, làm mốc so sánh.
    nonisolated static func fetchDirectIP() async -> String? {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 10
        configuration.waitsForConnectivity = false
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.connectionProxyDictionary = [
            "HTTPEnable": 0,
            "HTTPSEnable": 0,
            "SOCKSEnable": 0,
            "ProxyAutoConfigEnable": 0,
            "ProxyAutoDiscoveryEnable": 0
        ]

        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let urls = [
            URL(string: "https://api.ipify.org?format=json"),
            URL(string: "https://ifconfig.me/ip")
        ].compactMap { $0 }

        for url in urls {
            var request = URLRequest(url: url)
            request.timeoutInterval = 10
            request.setValue("application/json, text/plain", forHTTPHeaderField: "Accept")
            if let (data, response) = try? await session.data(for: request),
               let http = response as? HTTPURLResponse,
               (200...299).contains(http.statusCode),
               let ip = parseEgressIP(from: data) {
                return ip
            }
        }
        return nil
    }

    /// Đo thời gian bắt tay TCP tới proxy. `nil` nếu không kết nối được.
    nonisolated static func measureTCPLatency(host: String, port: Int) async -> Int? {
        guard let nwPort = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else { return nil }
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: nwPort,
            using: .tcp
        )

        return await withCheckedContinuation { (continuation: CheckedContinuation<Int?, Never>) in
            let start = Date()
            let state = LatencyState()

            func finish(_ value: Int?) {
                guard state.claimCompletion() else { return }
                connection.cancel()
                continuation.resume(returning: value)
            }

            connection.stateUpdateHandler = { nwState in
                switch nwState {
                case .ready:
                    let ms = Int(Date().timeIntervalSince(start) * 1000)
                    finish(ms)
                case .failed, .cancelled:
                    finish(nil)
                default:
                    break
                }
            }

            connection.start(queue: DispatchQueue.global(qos: .utility))

            DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 6) {
                finish(nil)
            }
        }
    }

    // MARK: - Duration timer

    private func startDurationTimer() {
        stopDurationTimer()
        let timer = Timer(timeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, let start = self.connectedAt else { return }
                self.elapsed = Date().timeIntervalSince(start)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        durationTimer = timer
    }

    private func stopDurationTimer() {
        durationTimer?.invalidate()
        durationTimer = nil
    }

    // MARK: - Network path monitoring (Wi-Fi / 4G / auto-reconnect)

    private func startPathMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true
        lastPathWasSatisfied = true

        pathMonitor.pathUpdateHandler = { [weak self] path in
            let type: ProxyNetworkType
            if path.status != .satisfied {
                type = .offline
            } else if path.usesInterfaceType(.wifi) {
                type = .wifi
            } else if path.usesInterfaceType(.cellular) {
                type = .cellular
            } else if path.usesInterfaceType(.wiredEthernet) {
                type = .wired
            } else {
                type = .other
            }
            let satisfied = path.status == .satisfied

            Task { @MainActor in
                guard let self else { return }
                let previousType = self.networkType
                self.networkType = type
                await self.handlePathChange(
                    satisfied: satisfied,
                    type: type,
                    previousType: previousType
                )
            }
        }
        pathMonitor.start(queue: monitorQueue)
    }

    private func handlePathChange(
        satisfied: Bool,
        type: ProxyNetworkType,
        previousType: ProxyNetworkType
    ) async {
        guard wantsConnection, let config = activeConfiguration else {
            lastPathWasSatisfied = satisfied
            return
        }

        if !satisfied {
            // Mất mạng: đánh dấu lỗi nhưng vẫn giữ ý định kết nối để tự nối lại.
            if state.isConnected || state.isBusy {
                state = .failed("Mất kết nối mạng. Đang chờ mạng trở lại…")
            }
            lastPathWasSatisfied = false
            return
        }

        // Chuyển Wi-Fi ↔ 4G/5G: interface đổi thì phải kiểm chứng lại.
        let interfaceChanged =
            previousType != type &&
            previousType != .other &&
            previousType != .offline

        if !lastPathWasSatisfied || !state.isConnected || interfaceChanged {
            lastPathWasSatisfied = true
            await reconnectIfNeeded(config: config)
        }
    }

    private func reconnectIfNeeded(config: ProxyConfiguration) async {
        guard wantsConnection else { return }
        let password: String?
        if config.requiresAuthentication {
            password = ProxyConfigStore.shared.password(for: config.id)
        } else {
            password = nil
        }

        let reconnectSession = makeProxiedSession(for: config, password: password)
        session?.invalidateAndCancel()
        session = reconnectSession
        state = .connecting

        do {
            let outcome = try await runProbe(using: reconnectSession)
            guard wantsConnection else {
                reconnectSession.invalidateAndCancel()
                return
            }
            egressIP = outcome.ip
            connectionWarning = outcome.httpsBlocked
                ? "Proxy chỉ cho phép HTTP. Kết nối HTTPS (CONNECT) bị chặn — các trang https sẽ không tải được."
                : nil
            connectedAt = Date()
            elapsed = 0
            state = .connected
            ProxySessionProvider.install(reconnectSession, proxyDictionary: Self.proxyDictionary(for: config))
            startDurationTimer()
        } catch {
            reconnectSession.invalidateAndCancel()
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            lastError = message
            state = .failed(message)
            stopDurationTimer()
        }
    }
}

// MARK: - ProxyDiagnostics
//
// Tiện ích chẩn đoán: cho biết môi trường build hiện tại có khả năng
// NetworkExtension hay không, để UI báo giới hạn một cách trung thực.
enum ProxyDiagnostics {

    /// Bundle ID hiện tại. NetworkExtension yêu cầu App ID thật đã đăng ký
    /// capability `com.apple.developer.networking.networkextension`.
    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "(unknown)"
    }

    /// `true` nếu bundle ID trông giống App ID thật (không phải bundle hệ thống
    /// bị mạo danh như `com.apple.*`).
    static var hasRealAppIdentifier: Bool {
        let id = bundleIdentifier
        return !id.hasPrefix("com.apple.")
    }

    /// Giải thích vì sao tunnel toàn hệ thống không khả dụng trong build này.
    static var networkExtensionLimitMessage: String {
        if hasRealAppIdentifier {
            return "Proxy áp dụng cho mọi request URLSession của app. Còn loại trừ: kiểm tra toàn vẹn RSA, WKWebView và Safari (iOS không cho đặt proxy cho hai loại này). Muốn toàn hệ thống: thêm Packet Tunnel Extension và entitlement NetworkExtension, rồi ký lại app."
        }
        return "Proxy áp dụng cho mọi request URLSession của app. Còn loại trừ: kiểm tra toàn vẹn RSA, WKWebView và Safari (iOS không cho đặt proxy cho hai loại này). Toàn hệ thống cần Packet Tunnel Extension + entitlement NetworkExtension trên App ID thật — build này dùng \(bundleIdentifier) nên không thể đăng ký App ID đó."
    }
}
