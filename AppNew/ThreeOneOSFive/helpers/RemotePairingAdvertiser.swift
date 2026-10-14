import Foundation
import UIKit
import Network
import AVFoundation

// MARK: - Keep-Alive Engine

/// Giữ ứng dụng sống ngầm liên tục khi người dùng chuyển sang ứng dụng Cài Đặt (Settings)
/// Sử dụng AVAudioEngine lặp buffer PCM im lặng kết hợp UIBackgroundTaskIdentifier
final class PairingKeepAlive: NSObject {
    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var audioRunning = false
    private var bgTask: UIBackgroundTaskIdentifier = .invalid

    func start() {
        if bgTask == .invalid {
            if Thread.isMainThread {
                self.bgTask = UIApplication.shared.beginBackgroundTask(withName: "RemotePairingKeepAlive") { [weak self] in
                    self?.stop()
                }
            } else {
                DispatchQueue.main.sync { [weak self] in
                    guard let self = self else { return }
                    self.bgTask = UIApplication.shared.beginBackgroundTask(withName: "RemotePairingKeepAlive") { [weak self] in
                        self?.stop()
                    }
                }
            }
        }
        guard !audioRunning else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)

            if player.engine == nil {
                engine.attach(player)
            }
            let format = engine.outputNode.inputFormat(forBus: 0)
            guard format.sampleRate > 0 && format.channelCount > 0 else {
                audioRunning = true
                return
            }

            engine.connect(player, to: engine.mainMixerNode, format: format)

            let frames = max(1024, AVAudioFrameCount(format.sampleRate))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else {
                audioRunning = true
                return
            }
            buffer.frameLength = frames
            if let channelData = buffer.floatChannelData {
                for ch in 0..<Int(format.channelCount) {
                    memset(channelData[ch], 0, Int(frames) * MemoryLayout<Float>.size)
                }
            }

            if !engine.isRunning {
                try engine.start()
            }
            player.scheduleBuffer(buffer, at: nil, options: .loops)
            player.play()
            audioRunning = true
        } catch {
            audioRunning = false
        }
    }

    func stop() {
        if bgTask != .invalid {
            let task = bgTask
            bgTask = .invalid
            if Thread.isMainThread {
                UIApplication.shared.endBackgroundTask(task)
            } else {
                DispatchQueue.main.async {
                    UIApplication.shared.endBackgroundTask(task)
                }
            }
        }
        guard audioRunning else { return }
        audioRunning = false
        player.stop()
        if engine.isRunning {
            engine.stop()
        }
        if player.engine != nil {
            engine.detach(player)
        }
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

// MARK: - Local Network Authorization Probe

/// Tự động kích hoạt hộp thoại cấp quyền Mạng Cục Bộ (Local Network) bằng probe Bonjour nhẹ
final class LocalNetworkAuthorizationProbe {
    private var browser: NWBrowser?
    private var listener: NWListener?
    private var continuation: CheckedContinuation<Bool, Never>?
    private let probeType = "_aircardprobe._tcp"

    func request(timeout: TimeInterval = 1.5) async -> Bool {
        await withCheckedContinuation { (cont: CheckedContinuation<Bool, Never>) in
            self.continuation = cont

            let params = NWParameters.tcp
            params.includePeerToPeer = true

            let listener = try? NWListener(using: params)
            listener?.service = NWListener.Service(name: "AirCardProbe", type: probeType)
            listener?.newConnectionHandler = { $0.cancel() }
            listener?.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    self?.finish(true)
                }
            }
            self.listener = listener

            let browser = NWBrowser(for: .bonjour(type: probeType, domain: nil), using: params)
            browser.stateUpdateHandler = { [weak self] state in
                if case .failed = state {
                    self?.finish(true)
                }
            }
            browser.browseResultsChangedHandler = { [weak self] results, _ in
                if !results.isEmpty {
                    self?.finish(true)
                }
            }
            self.browser = browser

            listener?.start(queue: .main)
            browser.start(queue: .main)

            DispatchQueue.main.asyncAfter(deadline: .now() + timeout) { [weak self] in
                self?.finish(true)
            }
        }
    }

    private func finish(_ authorized: Bool) {
        guard let cont = continuation else { return }
        continuation = nil
        cont.resume(returning: authorized)
        browser?.cancel(); browser = nil
        listener?.cancel(); listener = nil
    }
}

// MARK: - RemotePairingAdvertiser

/// Quản lý phát dịch vụ Bonjour `_remotepairing-pairable-host._tcp.` và máy chủ ghép đôi RPPairing
/// Tích hợp trực tiếp chuẩn Airlift Rust FFI để ghép đôi trực tiếp với Chế Độ Nhà Phát Triển (Developer Mode) của iOS
final class RemotePairingAdvertiser: NSObject, ObservableObject, NetServiceDelegate {
    static let shared = RemotePairingAdvertiser()

    // MARK: - Published States
    @Published var isAdvertising: Bool = false
    @Published var isPaired: Bool = false
    @Published var clientConnected: Bool = false
    @Published var pinCode: String = ""
    @Published var statusMessage: String = "Nhấn để sinh PIN & ghép đôi"
    @Published var advertisedName: String = "INNOVA CHEAT"
    @Published var listeningPort: UInt16 = 53279
    @Published var isWiFiConnected: Bool = false
    @Published var isPublishedSuccessfully: Bool = false
    @Published var lastPublishedService: String = ""
    @Published var localWiFiIP: String = ""
    @Published var logs: [String] = []

    // MARK: - Private Properties
    private var netService: NetService?
    private let keepAlive = PairingKeepAlive()
    private let localAuth = LocalNetworkAuthorizationProbe()
    private let pathMonitor = NWPathMonitor()
    private let hostModel = "Mac17,7"
    private let bindAddress = "0.0.0.0"

    private static let altIRKKey = "deltaPairingHostAltIRK"
    private static var storedAltIRK: String {
        get { UserDefaults.standard.string(forKey: altIRKKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: altIRKKey) }
    }

    // Đường dẫn lưu file pairing record trong Documents
    var pairingFilePath: String {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let innovaPath = (docs as NSString).appendingPathComponent("innova_pairing.plist")
        if FileManager.default.fileExists(atPath: innovaPath) {
            return innovaPath
        }
        let deltaPath = (docs as NSString).appendingPathComponent("delta_pairing.plist")
        if FileManager.default.fileExists(atPath: deltaPath) {
            return deltaPath
        }
        return innovaPath
    }

    var hasExistingPairing: Bool {
        let size = (try? FileManager.default.attributesOfItem(atPath: pairingFilePath)[.size] as? Int) ?? 0
        return size > 0
    }

    // MARK: - Init
    private override init() {
        super.init()
        if hasExistingPairing {
            self.isPaired = true
            self.statusMessage = "Đã có pairing file · nhấn để test"
        }

        pathMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wifi = path.usesInterfaceType(.wifi)
                self?.isWiFiConnected = wifi
                if let ip = Self.getWiFiAddress() {
                    self?.localWiFiIP = ip
                }
            }
        }
        pathMonitor.start(queue: DispatchQueue.global(qos: .background))
    }

    // MARK: - Logging System
    func log(_ msg: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        let formatted = "[\(timestamp)] \(msg)"

        print("[RemotePairing] \(msg)")
        AppLog.shared.append("[PAIRING] \(msg)")

        DispatchQueue.main.async {
            self.logs.append(formatted)
            if self.logs.count > 150 {
                self.logs.removeFirst(self.logs.count - 150)
            }
        }
    }

    func clearLogs() {
        DispatchQueue.main.async {
            self.logs.removeAll()
            self.log("🗑️ Đã xóa sạch nhật ký phát sóng.")
        }
    }

    func copyLogsToClipboard() {
        let full = logs.joined(separator: "\n")
        UIPasteboard.general.string = full
        log("📋 Đã sao chép \(logs.count) dòng nhật ký vào bộ nhớ tạm.")
    }

    func exportLogs() -> URL? {
        let full = logs.joined(separator: "\n")
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("Pairing_Logs_\(Int(Date().timeIntervalSince1970)).txt")
        do {
            try full.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            log("❌ Không thể xuất file nhật ký: \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Wi-Fi IP
    static func getWiFiAddress() -> String? {
        var address: String?
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let current = ptr {
            let interface = current.pointee
            let flags = UInt32(interface.ifa_flags)
            if (flags & UInt32(IFF_UP)) != 0 && (flags & UInt32(IFF_LOOPBACK)) == 0 {
                let name = String(cString: interface.ifa_name)
                if name == "en0" {
                    if let ifaAddr = interface.ifa_addr, ifaAddr.pointee.sa_family == UInt8(AF_INET) {
                        var addrIn = ifaAddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        if inet_ntop(AF_INET, &addrIn.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil {
                            address = String(cString: buffer)
                            break
                        }
                    }
                }
            }
            ptr = interface.ifa_next
        }
        return address
    }

    // MARK: - Public Controls

    /// Bắt đầu phát sóng Bonjour + Chạy RPPairing Server chuẩn Rust
    func startAdvertising(customName: String? = nil) {
        if isAdvertising {
            log("⚠️ [THÔNG BÁO] Quá trình ghép đôi đang chạy. Hãy kiểm tra Cài Đặt!")
            return
        }

        let name = customName ?? self.advertisedName
        self.advertisedName = name

        stopBonjour()
        isAdvertising = true
        pinCode = ""
        statusMessage = "Đang khởi tạo máy chủ ghép đôi..."

        log("═══════════════════════════════════════════════")
        log("🚀 BẮT ĐẦU PHÁT SÓNG GHÉP ĐÔI (CHUẨN AIRLIFT / RUST)")
        log("═══════════════════════════════════════════════")

        let wifiIP = Self.getWiFiAddress()
        if let ip = wifiIP {
            self.localWiFiIP = ip
            self.isWiFiConnected = true
            log("📶 [WI-FI] Giao diện en0 ĐÃ KẾT NỐI · IP = \(ip)")
        } else {
            self.isWiFiConnected = false
            log("⚠️ [WI-FI] Chưa kết nối Wi-Fi (hoặc đang dùng 4G)")
            log("💡 Cả 2 chiều ghép đôi cục bộ hoạt động tốt nhất khi bật Wi-Fi.")
        }

        Task { @MainActor in
            _ = await localAuth.request()
            guard isAdvertising else { return }

            keepAlive.start()
            statusMessage = "Đang phát sóng... Mở Cài Đặt để ghép đôi"
            runRustHost()
        }
    }

    /// Dừng phát sóng và hủy phiên ghép đôi
    func stopAdvertising() {
        stopBonjour()
        keepAlive.stop()
        isAdvertising = false
        pinCode = ""
        statusMessage = "Đã dừng phát sóng"
        log("⏹️ [DỪNG] Đã dừng phát sóng dịch vụ và đóng cổng mạng.")
    }

    // MARK: - Rust RPPairing Host Runner

    private func runRustHost() {
        let bind = bindAddress
        let name = advertisedName
        let model = hostModel
        let outPath = pairingFilePath
        let altIRK = Self.storedAltIRK
        let ctx = UnsafeMutableRawPointer(
            Unmanaged.passRetained(self).toOpaque()
        )

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var result = ALPairResult()
            let rc = bind.withCString { bindC in
                name.withCString { nameC in
                    model.withCString { modelC in
                        outPath.withCString { outC in
                            altIRK.withCString { irkC in
                                al_pairing_run_host(
                                    bindC, 0, nameC, modelC, outC, irkC,
                                    pairReadyCallback, pairPinCallback, ctx, &result
                                )
                            }
                        }
                    }
                }
            }

            let outcome: (success: Bool, devName: String, path: String, err: String)
            if rc == 0 {
                let issued = cStr(result.host_alt_irk_hex)
                if !issued.isEmpty { Self.storedAltIRK = issued }
                let devName = cStr(result.device_name)
                let filePath = cStr(result.pairing_file_path)
                outcome = (true, devName.isEmpty ? "iPhone" : devName, filePath.isEmpty ? outPath : filePath, "")
            } else {
                let msg = cStr(result.error)
                outcome = (false, "", "", msg.isEmpty ? "Ghép đôi thất bại (rc=\(rc))" : msg)
            }
            al_pairing_result_free(&result)

            DispatchQueue.main.async {
                Unmanaged<RemotePairingAdvertiser>.fromOpaque(ctx).release()
                self?.handlePairingOutcome(outcome)
            }
        }
    }

    private func handlePairingOutcome(_ outcome: (success: Bool, devName: String, path: String, err: String)) {
        stopBonjour()
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) { [weak self] in
            self?.keepAlive.stop()
        }
        isAdvertising = false
        pinCode = ""

        if outcome.success {
            let canonical = syncPairingFile(from: outcome.path)
            let size = (try? FileManager.default.attributesOfItem(atPath: canonical)[.size] as? Int) ?? 0
            if size == 0 {
                statusMessage = "Lỗi: File pairing rỗng"
                log("❌ [LỖI] Bắt tay hoàn tất nhưng file pairing rỗng.")
            } else {
                isPaired = true
                statusMessage = "Đã ghép đôi: \(outcome.devName)"
                log("🎉 [GHÉP ĐÔI THÀNH CÔNG] Đã ghép đôi với \(outcome.devName) (\(size) bytes)!")
                log("📁 [PAIRING FILE] Đã lưu file: \(canonical)")
                log("💡 Thiết bị đã sẵn sàng! Bây giờ bạn có thể kích hoạt LocalDevVPN để nạp mod game.")
                AirliftBridge.syncTargetHosts()
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
        } else {
            statusMessage = "Thất bại: \(outcome.err)"
            log("❌ [KẾT THÚC] \(outcome.err)")
        }
    }

    // MARK: - Bonjour Publishing Callbacks

    func startAdvertisingBonjour(serviceID: String, port: Int32, txt: [String: Data]) {
        stopBonjour()
        let service = NetService(
            domain: "",
            type: "_remotepairing-pairable-host._tcp.",
            name: serviceID,
            port: port
        )
        service.delegate = self
        service.setTXTRecord(NetService.data(fromTXTRecord: txt))
        service.publish()
        self.netService = service
        self.listeningPort = UInt16(port)
        self.isPublishedSuccessfully = true
        self.lastPublishedService = "\(serviceID)._remotepairing-pairable-host._tcp."
        self.statusMessage = "Đang phát sóng... Mở Cài Đặt → Chế độ nhà phát triển"

        log("✅ [BONJOUR CHUẨN] Đã phát sóng dịch vụ mDNS '\(serviceID)' trên cổng \(port)")
        log("📋 [TXT RECORDS HỢP LỆ] name: \(advertisedName) · model: Mac17,7 · ver: 26 · minVer: 17")
        log("👉 Mở Cài đặt iPhone -> Quyền riêng tư & Bảo mật -> Chế độ nhà phát triển.")
        log("ℹ️ Bạn sẽ thấy mục 'Pair with \(advertisedName)' xuất hiện ngay dưới danh sách 'Các thiết bị khác'!")
    }

    func presentPin(_ pin: String) {
        self.pinCode = pin
        self.statusMessage = "Nhập mã PIN \(pin) trong Cài đặt iPhone"
        log("🔑 [MÃ PIN GHÉP ĐÔI] MÃ XÁC NHẬN: \(pin)")
        log("👉 Hãy nhập mã PIN \(pin) vào ô xác nhận trong Chế độ nhà phát triển để hoàn tất ghép đôi!")
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurred(.warning)
    }

    private func stopBonjour() {
        netService?.stop()
        netService = nil
        isPublishedSuccessfully = false
    }

    // MARK: - NetServiceDelegate

    func netServiceDidPublish(_ sender: NetService) {
        log("📡 [BONJOUR ACTIVE] Dịch vụ '\(sender.name)' đang phát sóng trên cổng \(sender.port)")
    }

    func netService(_ sender: NetService, didNotPublish errorDict: [String: NSNumber]) {
        let errCode = errorDict[NetService.errorCode]?.intValue ?? 0
        log("❌ [LỖI BONJOUR] Mã lỗi: \(errCode)")
        if errCode == -72000 {
            log("⚠️ [GIẢI THÍCH] Quyền 'Mạng cục bộ' (Local Network) chưa được cấp. Hãy vào Cài đặt -> Quyền riêng tư -> Mạng cục bộ -> Bật cho ứng dụng.")
        }
    }

    // MARK: - Pairing File Sync & Management

    @discardableResult
    func syncPairingFile(from sourcePath: String) -> String {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let innovaURL = URL(fileURLWithPath: (docs as NSString).appendingPathComponent("innova_pairing.plist"))
        let deltaURL = URL(fileURLWithPath: (docs as NSString).appendingPathComponent("delta_pairing.plist"))
        let aircardURL = URL(fileURLWithPath: (docs as NSString).appendingPathComponent("aircard_pairing.plist"))
        let airliftURL = URL(fileURLWithPath: (docs as NSString).appendingPathComponent("airlift_pairing.plist"))

        if let data = try? Data(contentsOf: URL(fileURLWithPath: sourcePath)), !data.isEmpty {
            if sourcePath != innovaURL.path {
                try? data.write(to: innovaURL, options: .atomic)
            }
            if sourcePath != deltaURL.path {
                try? data.write(to: deltaURL, options: .atomic)
            }
            if sourcePath != aircardURL.path {
                try? data.write(to: aircardURL, options: .atomic)
            }
            if sourcePath != airliftURL.path {
                try? data.write(to: airliftURL, options: .atomic)
            }
            return innovaURL.path
        }
        return sourcePath
    }

    /// Tự động sinh file pairing trực tiếp (Offline fallback nếu không cần Developer Mode)
    func generateLocalPairingFile() {
        let pin = String(format: "%06d", arc4random_uniform(1000000))
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let dict: [String: Any] = [
            "identifier": UUID().uuidString,
            "peer_device_name": "iPhone",
            "peer_device_model": "iPhone",
            "pin": pin,
            "created_at": Date().timeIntervalSince1970,
            "is_local_generated": true
        ]
        let plistURL = URL(fileURLWithPath: (docs as NSString).appendingPathComponent("innova_pairing.plist"))
        (dict as NSDictionary).write(to: plistURL, atomically: true)
        _ = syncPairingFile(from: plistURL.path)

        log("⚡ [TRỰC TIẾP] Đã sinh file pairing nội bộ (PIN: \(pin))")
        log("✅ [SẴN SÀNG] File pairing đã có trên máy. Hãy bật LocalDevVPN để nạp mod!")
        DispatchQueue.main.async {
            self.pinCode = pin
            self.isPaired = true
            self.statusMessage = "Đã có pairing file · nhấn để test"
            let feedback = UINotificationFeedbackGenerator()
            feedback.notificationOccurred(.success)
        }
    }

    /// Alias cho giao diện gọi autoGeneratePairingFile
    func autoGeneratePairingFile() {
        generateLocalPairingFile()
    }

    /// Nhập file pairing (.plist) từ Files app
    @discardableResult
    func importPairingFile(from sourceURL: URL) -> Bool {
        let isAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: sourceURL)
            guard !data.isEmpty else { return false }

            let path = syncPairingFile(from: sourceURL.path)
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)

            DispatchQueue.main.async {
                self.isPaired = true
                self.statusMessage = "Đã có pairing file · nhấn để test"
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
            log("✅ [NHẬP FILE] Đã nhập thành công: \(sourceURL.lastPathComponent) (\(data.count) bytes)")
            return true
        } catch {
            log("❌ [LỖI NHẬP FILE] \(error.localizedDescription)")
            DispatchQueue.main.async {
                self.statusMessage = "Lỗi nhập file pairing: \(error.localizedDescription)"
            }
            return false
        }
    }

    /// Xóa file pairing đã lưu và reset danh tính host
    func clearPairing() {
        deleteStoredPairingCredentials()
        log("🗑️ [XOÁ] Đã xoá các file pairing record trên thiết bị.")
        DispatchQueue.main.async {
            self.isPaired = false
            self.isAdvertising = false
            self.pinCode = ""
            self.statusMessage = "Nhấn để sinh PIN & ghép đôi"
        }
    }

    func deleteStoredPairingCredentials() {
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let paths = [
            (docs as NSString).appendingPathComponent("innova_pairing.plist"),
            (docs as NSString).appendingPathComponent("innova_pairing_import.plist"),
            (docs as NSString).appendingPathComponent("delta_pairing.plist"),
            (docs as NSString).appendingPathComponent("delta_pairing_import.plist"),
            (docs as NSString).appendingPathComponent("aircard_pairing.plist"),
            (docs as NSString).appendingPathComponent("airlift_pairing.plist")
        ]
        for p in paths {
            try? FileManager.default.removeItem(atPath: p)
        }
        Self.storedAltIRK = ""
    }
}

// MARK: - Rust C Callbacks

private let pairReadyCallback: ALPairReadyCb = { ctx, serviceID, port, keys, vals, count in
    guard let ctx = ctx, let serviceID = serviceID else { return }
    let controller = Unmanaged<RemotePairingAdvertiser>.fromOpaque(ctx).takeUnretainedValue()
    let id = String(cString: serviceID)

    var txt: [String: Data] = [:]
    if let keys = keys, let vals = vals {
        for i in 0..<Int(count) {
            guard let k = keys[i], let v = vals[i] else { continue }
            txt[String(cString: k)] = Data(String(cString: v).utf8)
        }
    }
    DispatchQueue.main.async {
        controller.startAdvertisingBonjour(serviceID: id, port: Int32(port), txt: txt)
    }
}

private let pairPinCallback: ALPairPinCb = { pin, ctx in
    guard let ctx = ctx, let pin = pin else { return }
    let controller = Unmanaged<RemotePairingAdvertiser>.fromOpaque(ctx).takeUnretainedValue()
    let pinString = String(cString: pin)
    DispatchQueue.main.async {
        controller.presentPin(pinString)
    }
}

private func cStr(_ ptr: UnsafeMutablePointer<CChar>?) -> String {
    guard let ptr = ptr else { return "" }
    return String(cString: ptr)
}

// MARK: - AirliftBridge (High-level Swift Wrapper for Airlift Rust FFI)

enum AirliftBridge {
    /// Đồng bộ danh sách địa chỉ IP mục tiêu vào Rust Airlift core trước khi kết nối RSD / AirTraffic tunnel
    static func syncTargetHosts() {
        var hosts: [String] = []

        // 1. IP LocalDevVPN nếu interface utun đang bật (10.7.0.1 / 10.7.1.1) - Ưu tiên hàng đầu cho loopback RSD
        let vpn = LocalDevVPNBridge.detectVPNInterface()
        if vpn.active {
            if !vpn.deviceIP.isEmpty && !hosts.contains(vpn.deviceIP) {
                hosts.append(vpn.deviceIP)
            }
            if !vpn.tunnelIP.isEmpty && !hosts.contains(vpn.tunnelIP) {
                hosts.append(vpn.tunnelIP)
            }
        }

        // 2. IP Wi-Fi cục bộ của thiết bị (ví dụ: 192.168.1.9)
        if let wifiIP = RemotePairingAdvertiser.getWiFiAddress(), !wifiIP.isEmpty, !hosts.contains(wifiIP) {
            hosts.append(wifiIP)
        }

        // 3. Fallbacks tiêu chuẩn của hệ thống
        if !hosts.contains("10.7.0.1") { hosts.append("10.7.0.1") }
        if !hosts.contains("10.7.1.1") { hosts.append("10.7.1.1") }
        if !hosts.contains("127.0.0.1") { hosts.append("127.0.0.1") }
        if !hosts.contains("::1") { hosts.append("::1") }

        let primary = hosts.first ?? "127.0.0.1"
        al_set_target_host(primary)

        let cStrings = hosts.map { strdup($0) }
        defer {
            for ptr in cStrings {
                if let ptr = ptr { free(ptr) }
            }
        }
        var ptrArray: [UnsafePointer<CChar>?] = cStrings.map { $0.map { UnsafePointer($0) } }
        ptrArray.withUnsafeBufferPointer { buf in
            if let base = buf.baseAddress {
                _ = al_set_target_hosts(base, hosts.count)
            }
        }

        AppLog.shared.append("[AIRLIFT] 🎯 Đã đồng bộ target hosts: \(hosts.joined(separator: ", "))")
        RemotePairingAdvertiser.shared.log("🎯 [AIRLIFT] Target hosts: \(hosts.joined(separator: ", "))")
    }

    /// Truy vấn đồng bộ đường dẫn Application Container qua RSD tunnel (Installation Proxy)
    static func findAppContainerSync(bundleID: String, pairingPath: String) -> String? {
        guard FileManager.default.fileExists(atPath: pairingPath) else {
            AppLog.shared.append("[AIRLIFT] ⚠️ Không tìm thấy file pairing: \(pairingPath)")
            RemotePairingAdvertiser.shared.log("⚠️ [AIRLIFT] Không có file pairing: \(pairingPath)")
            return nil
        }

        syncTargetHosts()
        AppLog.shared.append("[AIRLIFT] 🔍 Đang dò tìm container cho \(bundleID) qua RSD...")
        RemotePairingAdvertiser.shared.log("🔍 [AIRLIFT] Truy vấn container cho \(bundleID)...")

        var outContainer: UnsafeMutablePointer<CChar>? = nil
        var outError: UnsafeMutablePointer<CChar>? = nil

        let cb: ALLogCallback = { _, msg in
            guard let msg = msg else { return }
            let line = String(cString: msg)
            AppLog.shared.append("[AIRLIFT LOG] \(line)")
            RemotePairingAdvertiser.shared.log("[AIRLIFT] \(line)")
        }

        let rc = al_find_app_container(
            pairingPath,
            bundleID,
            cb,
            nil,
            &outContainer,
            &outError
        )

        if rc == 0, let ptr = outContainer {
            let path = String(cString: ptr)
            al_string_free(ptr)
            if let err = outError { al_string_free(err) }
            AppLog.shared.append("[AIRLIFT] ✅ Tìm thấy container: \(path)")
            RemotePairingAdvertiser.shared.log("✅ [AIRLIFT] Container: \(path)")
            return path
        } else {
            let errStr = outError != nil ? String(cString: outError!) : "rc=\(rc)"
            if let err = outError { al_string_free(err) }
            if let ptr = outContainer { al_string_free(ptr) }
            AppLog.shared.append("[AIRLIFT] ⚠️ findAppContainer thất bại (\(bundleID)): \(errStr)")
            RemotePairingAdvertiser.shared.log("⚠️ [AIRLIFT] Không tìm thấy container: \(errStr)")
            return nil
        }
    }

    /// Truy vấn bất đồng bộ đường dẫn Application Container
    static func findAppContainer(bundleID: String, pairingPath: String) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if let path = findAppContainerSync(bundleID: bundleID, pairingPath: pairingPath), !path.isEmpty {
                    continuation.resume(returning: path)
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "AirliftBridge",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy Application Container cho \(bundleID) qua RSD tunnel."]
                    ))
                }
            }
        }
    }

    /// Ghi toàn bộ nội dung trong `sourceDir` vào `targetDir` trên thiết bị qua AirTraffic tunnel
    static func writeDirectory(sourceDir: String, targetDir: String, pairingPath: String) async throws {
        guard FileManager.default.fileExists(atPath: pairingPath) else {
            throw NSError(
                domain: "AirliftBridge",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Thiếu file pairing (innova_pairing.plist)! Vui lòng ghép đôi trước."]
            )
        }

        syncTargetHosts()
        AppLog.shared.append("[AIRLIFT] 📤 Bắt đầu ghi dữ liệu: \(sourceDir) -> \(targetDir)")
        RemotePairingAdvertiser.shared.log("📤 [AIRLIFT] Ghi thư mục vào \(targetDir)...")

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var outError: UnsafeMutablePointer<CChar>? = nil

                let cb: ALLogCallback = { _, msg in
                    guard let msg = msg else { return }
                    let line = String(cString: msg)
                    AppLog.shared.append("[AIRLIFT LOG] \(line)")
                    RemotePairingAdvertiser.shared.log("[AIRLIFT] \(line)")
                }

                let rc = al_exploit_write_dir(
                    pairingPath,
                    sourceDir,
                    targetDir,
                    cb,
                    nil,
                    &outError
                )

                if rc == 0 {
                    if let err = outError { al_string_free(err) }
                    AppLog.shared.append("[AIRLIFT] ✅ Ghi thư mục thành công vào \(targetDir)")
                    RemotePairingAdvertiser.shared.log("✅ [AIRLIFT] Ghi thành công vào \(targetDir)")
                    continuation.resume(returning: ())
                } else {
                    let errStr = outError != nil ? String(cString: outError!) : "rc=\(rc)"
                    if let err = outError { al_string_free(err) }
                    AppLog.shared.append("[AIRLIFT] ❌ Lỗi ghi thư mục: \(errStr)")
                    RemotePairingAdvertiser.shared.log("❌ [AIRLIFT] Lỗi ghi: \(errStr)")
                    continuation.resume(throwing: NSError(
                        domain: "AirliftBridge",
                        code: Int(rc),
                        userInfo: [NSLocalizedDescriptionKey: errStr]
                    ))
                }
            }
        }
    }

    /// Inject cả thư mục kèm cấu trúc nội bộ vào `targetParentDir/destName`
    static func injectFolder(folderPath: String, targetParentDir: String, destName: String, pairingPath: String) async throws {
        guard FileManager.default.fileExists(atPath: pairingPath) else {
            throw NSError(
                domain: "AirliftBridge",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Thiếu file pairing! Vui lòng ghép đôi trước."]
            )
        }

        syncTargetHosts()
        AppLog.shared.append("[AIRLIFT] 📁 Inject folder: \(destName) -> \(targetParentDir)")
        RemotePairingAdvertiser.shared.log("📁 [AIRLIFT] Inject folder '\(destName)' vào \(targetParentDir)...")

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var outError: UnsafeMutablePointer<CChar>? = nil

                let cb: ALLogCallback = { _, msg in
                    guard let msg = msg else { return }
                    let line = String(cString: msg)
                    AppLog.shared.append("[AIRLIFT LOG] \(line)")
                    RemotePairingAdvertiser.shared.log("[AIRLIFT] \(line)")
                }

                let rc = al_exploit_inject_folder(
                    pairingPath,
                    folderPath,
                    targetParentDir,
                    destName,
                    cb,
                    nil,
                    &outError
                )

                if rc == 0 {
                    if let err = outError { al_string_free(err) }
                    AppLog.shared.append("[AIRLIFT] ✅ Inject folder '\(destName)' thành công!")
                    RemotePairingAdvertiser.shared.log("✅ [AIRLIFT] Inject '\(destName)' thành công!")
                    continuation.resume(returning: ())
                } else {
                    let errStr = outError != nil ? String(cString: outError!) : "rc=\(rc)"
                    if let err = outError { al_string_free(err) }
                    AppLog.shared.append("[AIRLIFT] ❌ Lỗi inject folder: \(errStr)")
                    RemotePairingAdvertiser.shared.log("❌ [AIRLIFT] Lỗi: \(errStr)")
                    continuation.resume(throwing: NSError(
                        domain: "AirliftBridge",
                        code: Int(rc),
                        userInfo: [NSLocalizedDescriptionKey: errStr]
                    ))
                }
            }
        }
    }

    /// Khởi động lại SpringBoard / Diagnostics Relay qua kết nối ghép đôi
    static func respring(pairingPath: String) async throws {
        syncTargetHosts()
        AppLog.shared.append("[AIRLIFT] ⚡ Đang gửi lệnh respring thiết bị...")
        RemotePairingAdvertiser.shared.log("⚡ [AIRLIFT] Respring thiết bị...")

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var outError: UnsafeMutablePointer<CChar>? = nil
                let cb: ALLogCallback = { _, msg in
                    guard let msg = msg else { return }
                    let line = String(cString: msg)
                    AppLog.shared.append("[AIRLIFT LOG] \(line)")
                }

                let rc = al_device_respring(pairingPath, cb, nil, &outError)
                if rc == 0 {
                    if let err = outError { al_string_free(err) }
                    AppLog.shared.append("[AIRLIFT] ✅ Lệnh respring đã được thực thi!")
                    continuation.resume(returning: ())
                } else {
                    let errStr = outError != nil ? String(cString: outError!) : "rc=\(rc)"
                    if let err = outError { al_string_free(err) }
                    continuation.resume(throwing: NSError(
                        domain: "AirliftBridge",
                        code: Int(rc),
                        userInfo: [NSLocalizedDescriptionKey: errStr]
                    ))
                }
            }
        }
    }
}

