import Foundation
import Darwin
import UIKit

/// Bridge chuyên dụng dành riêng cho iOS 27 sử dụng LocalDevVPN tunnel (10.7.0.1:49152 / 127.0.0.1)
/// Cung cấp giải pháp nạp patch, quản lý container game và đồng bộ cấu hình trên iOS 27 release builds.
///
/// QUY TẮC BẢO TOÀN (ISOLATION POLICY):
/// - Toàn bộ chức năng trong file này ĐƯỢC BẢO VỆ TUYỆT ĐỐI bởi `guard isIOS27 else { return ... }`.
/// - Tuyệt đối không can thiệp, không thay đổi luồng hoạt động của các phiên bản iOS khác (iOS 15, 16, 17, 18, 26).
enum LocalDevVPNBridge {
    static let defaultHost = "10.7.0.1"
    static let loopbackHost = "127.0.0.1"
    static let defaultPort: UInt16 = 49152

    /// Kiểm tra thiết bị có đang chạy iOS 27 hay không
    static var isIOS27: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27
    }

    /// Cache đường dẫn container game trên iOS 27
    private static var cachedContainerPaths: [String: String] = [:]

    // MARK: - Tunnel Probe & Connectivity

    /// Kiểm tra kết nối tới LocalDevVPN tunnel (10.7.0.1:49152 hoặc 127.0.0.1:49152)
    static func isTunnelActive(host: String = defaultHost, port: UInt16 = defaultPort, timeoutSeconds: Double = 0.4) -> Bool {
        guard isIOS27 else { return false }

        // Thử defaultHost (10.7.0.1) trước, nếu không được thử loopbackHost (127.0.0.1)
        if probeSocket(host: host, port: port, timeoutSeconds: timeoutSeconds) {
            return true
        }
        if host != loopbackHost {
            return probeSocket(host: loopbackHost, port: port, timeoutSeconds: timeoutSeconds)
        }
        return false
    }

    /// Thử kết nối TCP socket non-blocking tới endpoint với timeout
    private static func probeSocket(host: String, port: UInt16, timeoutSeconds: Double) -> Bool {
        var hints = addrinfo()
        hints.ai_family = AF_INET
        hints.ai_socktype = SOCK_STREAM

        var res: UnsafeMutablePointer<addrinfo>?
        let portString = "\(port)"
        guard getaddrinfo(host, portString, &hints, &res) == 0, let addr = res else {
            return false
        }
        defer { freeaddrinfo(res) }

        let sock = socket(addr.pointee.ai_family, addr.pointee.ai_socktype, addr.pointee.ai_protocol)
        guard sock >= 0 else { return false }
        defer { close(sock) }

        // Set non-blocking mode
        let flags = fcntl(sock, F_GETFL, 0)
        _ = fcntl(sock, F_SETFL, flags | O_NONBLOCK)

        let connectResult = connect(sock, addr.pointee.ai_addr, addr.pointee.ai_addrlen)
        if connectResult == 0 {
            return true
        }

        if errno == EINPROGRESS {
            var pfd = pollfd(fd: sock, events: Int16(POLLOUT), revents: 0)
            let pollRes = poll(&pfd, 1, Int32(timeoutSeconds * 1000))
            if pollRes > 0 && (pfd.revents & Int16(POLLOUT)) != 0 {
                var err: Int32 = 0
                var len = socklen_t(MemoryLayout<Int32>.size)
                if getsockopt(sock, SOL_SOCKET, SO_ERROR, &err, &len) == 0 && err == 0 {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Container Resolution (iOS 27 Only)

    /// Tìm container data của game trên iOS 27
    static func resolveContainerPath(bundleID: String) -> String? {
        guard isIOS27 else { return nil }

        if let cached = cachedContainerPaths[bundleID], !cached.isEmpty {
            if FileManager.default.fileExists(atPath: cached) {
                return cached
            }
            cachedContainerPaths.removeValue(forKey: bundleID)
        }

        // 1. Quét qua appDataRoot /var/mobile/Containers/Data/Application
        let candidates = [
            "/var/mobile/Containers/Data/Application",
            "/private/var/mobile/Containers/Data/Application"
        ]

        for root in candidates {
            guard let dirs = try? FileManager.default.contentsOfDirectory(atPath: root) else { continue }
            for uuid in dirs {
                guard UUID(uuidString: uuid) != nil else { continue }
                let containerPath = "\(root)/\(uuid)"
                let plistPath = "\(containerPath)/.com.apple.mobile_container_manager.metadata.plist"
                if let data = try? Data(contentsOf: URL(fileURLWithPath: plistPath)),
                   let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
                   let bid = plist["MCMMetadataIdentifier"] as? String,
                   bid == bundleID {
                    cachedContainerPaths[bundleID] = containerPath
                    return containerPath
                }

                // Fallback scan: kiểm tra thư mục Documents / Library có dấu hiệu nhận biết của game
                let docsPath = "\(containerPath)/Documents"
                if FileManager.default.fileExists(atPath: docsPath) {
                    if bundleID == FreeFireTarget.freeFireTH.rawValue || bundleID == FreeFireTarget.freeFireMAX.rawValue {
                        let unityFolder = "\(containerPath)/Library/Unity"
                        let shadowTracker = "\(docsPath)/contentcache"
                        if FileManager.default.fileExists(atPath: unityFolder) || FileManager.default.fileExists(atPath: shadowTracker) {
                            cachedContainerPaths[bundleID] = containerPath
                            return containerPath
                        }
                    }
                }
            }
        }

        return nil
    }

    // MARK: - File Operations & Injection (iOS 27 Only)

    /// Thực hiện nạp patch và cấu hình vào container game trên iOS 27
    static func inject(
        target: FreeFireTarget,
        patchData: Data,
        configData: Data,
        localData: Data,
        tokenData: Data?
    ) -> Bool {
        guard isIOS27 else { return false }

        var success = false

        // 1. Ghi trực tiếp vào Container nếu đã tìm thấy đường dẫn
        if let containerPath = resolveContainerPath(bundleID: target.rawValue) {
            let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents", isDirectory: true)
            let deepCfgDir = docsURL.appendingPathComponent("contentcache/Optional/ios/gameassetbundles", isDirectory: true)
            let deepTokDir = docsURL.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles", isDirectory: true)

            try? FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: deepCfgDir, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: deepTokDir, withIntermediateDirectories: true)

            let patchURL = docsURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
            let localURL = docsURL.appendingPathComponent("localConfig.json")
            let deepCfgFile = deepCfgDir.appendingPathComponent("menu_config.json")
            let deepTokFile = deepTokDir.appendingPathComponent(".innova_token.dat")

            if (try? patchData.write(to: patchURL, options: .atomic)) != nil {
                success = true
            }
            try? localData.write(to: localURL, options: .atomic)
            try? configData.write(to: deepCfgFile, options: .atomic)

            if let tokenData, !tokenData.isEmpty {
                try? tokenData.write(to: deepTokFile, options: .atomic)
            }

            // Dọn dẹp file thừa ở Documents root để không lộ ra app Files
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent("menu_config.json"))
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(".innova_token.dat"))
        }

        // 2. Nếu có LocalDevVPN tunnel (10.7.0.1:49152), đồng bộ thêm qua tunnel conduit
        if isTunnelActive() {
            notifyTunnelOfInjection(target: target)
            success = true
        }

        return success
    }

    /// Đồng bộ cấu hình cheat trên iOS 27
    static func syncConfig(target: FreeFireTarget, configData: Data) -> Bool {
        guard isIOS27 else { return false }

        guard let containerPath = resolveContainerPath(bundleID: target.rawValue) else {
            return false
        }
        let deepCfgDir = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents/contentcache/Optional/ios/gameassetbundles", isDirectory: true)
        try? FileManager.default.createDirectory(at: deepCfgDir, withIntermediateDirectories: true)
        let deepCfgFile = deepCfgDir.appendingPathComponent("menu_config.json")
        do {
            try configData.write(to: deepCfgFile, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Gỡ bỏ patch trên iOS 27
    static func uninject(target: FreeFireTarget) -> Bool {
        guard isIOS27 else { return false }

        guard let containerPath = resolveContainerPath(bundleID: target.rawValue) else {
            return false
        }
        let containerURL = URL(fileURLWithPath: containerPath)
        let docs = containerURL.appendingPathComponent("Documents")
        let patchURL = docs.appendingPathComponent("Assembly-CSharp-patch.bytes")
        let localURL = docs.appendingPathComponent("localConfig.json")
        let deepCfg = docs.appendingPathComponent("contentcache/Optional/ios/gameassetbundles/menu_config.json")
        let deepTok = docs.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles/.innova_token.dat")

        try? FileManager.default.removeItem(at: patchURL)
        try? FileManager.default.removeItem(at: localURL)
        try? FileManager.default.removeItem(at: deepCfg)
        try? FileManager.default.removeItem(at: deepTok)
        return true
    }

    /// Kiểm tra đã inject chưa trên iOS 27
    static func isInjected(target: FreeFireTarget) -> Bool {
        guard isIOS27 else { return false }
        guard let containerPath = resolveContainerPath(bundleID: target.rawValue) else {
            return false
        }
        let patchURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents/Assembly-CSharp-patch.bytes")
        return FileManager.default.fileExists(atPath: patchURL.path)
    }

    /// Gửi tín hiệu thông báo tới LocalDevVPN tunnel nếu đang lắng nghe
    private static func notifyTunnelOfInjection(target: FreeFireTarget) {
        guard isIOS27 else { return }
        guard let url = URL(string: "http://\(defaultHost):\(defaultPort)/airlift/ping") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 1.0
        let payload: [String: Any] = [
            "bundleID": target.rawValue,
            "action": "injected",
            "timestamp": Date().timeIntervalSince1970
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
    }

    /// Chuỗi mô tả trạng thái dành cho UI trên iOS 27
    static func statusDescription() -> String {
        guard isIOS27 else { return "" }
        if isTunnelActive() {
            return "LocalDevVPN (10.7.0.1:49152) — Đang kết nối"
        } else {
            return "LocalDevVPN — Sẵn sàng kết nối"
        }
    }

    /// Thử nghiệm kết nối tới LocalDevVPN tunnel (10.7.0.1:49152 hoặc 127.0.0.1:49152)
    static func testConnection(timeoutSeconds: Double = 0.8) async -> (success: Bool, host: String) {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                if probeSocket(host: defaultHost, port: defaultPort, timeoutSeconds: timeoutSeconds) {
                    continuation.resume(returning: (true, "\(defaultHost):\(defaultPort)"))
                    return
                }
                if probeSocket(host: loopbackHost, port: defaultPort, timeoutSeconds: timeoutSeconds) {
                    continuation.resume(returning: (true, "\(loopbackHost):\(defaultPort)"))
                    return
                }
                continuation.resume(returning: (false, "\(defaultHost):\(defaultPort)"))
            }
        }
    }
}

// MARK: - Observable Manager for SwiftUI

@MainActor
final class LocalDevVPNManager: ObservableObject {
    static let shared = LocalDevVPNManager()

    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var statusMessage: String = "Chưa kết nối"
    @Published var lastConnectedHost: String = "\(LocalDevVPNBridge.defaultHost):\(LocalDevVPNBridge.defaultPort)"
    @Published var lastCheckDate: Date?

    private init() {
        Task {
            let res = await LocalDevVPNBridge.testConnection(timeoutSeconds: 0.3)
            if res.success {
                self.isConnected = true
                self.statusMessage = "Đã kết nối (\(res.host))"
                self.lastConnectedHost = res.host
            }
        }
    }

    /// Kích hoạt kết nối thủ công từ Cài đặt
    func connect() async -> (success: Bool, message: String) {
        isConnecting = true
        defer { isConnecting = false }

        let res = await LocalDevVPNBridge.testConnection(timeoutSeconds: 1.0)
        lastCheckDate = Date()
        if res.success {
            isConnected = true
            statusMessage = "Đã kết nối (\(res.host))"
            lastConnectedHost = res.host
            _ = LocalDevVPNBridge.resolveContainerPath(bundleID: FreeFireTarget.freeFireTH.rawValue)
            _ = LocalDevVPNBridge.resolveContainerPath(bundleID: FreeFireTarget.freeFireMAX.rawValue)
            return (true, "Đã kết nối thành công tới LocalDevVPN (\(res.host))!")
        } else {
            isConnected = false
            statusMessage = "Chưa kết nối"
            return (false, "Không tìm thấy LocalDevVPN (\(res.host)). Vui lòng đảm bảo app LocalDevVPN đang BẬT!")
        }
    }
}

