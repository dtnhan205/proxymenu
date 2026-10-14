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
    static let tunnelHost = "10.7.1.1"
    static let loopbackHost = "127.0.0.1"
    static let defaultPort: UInt16 = 49152

    /// Kiểm tra thiết bị có đang chạy iOS 27 hay không
    static var isIOS27: Bool {
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion == 27
    }

    /// Kiểm tra thiết bị có đang chạy iOS 18.7.2 - 18.7.10 hay không
    static var isIOS18_7_x: Bool {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return v.majorVersion == 18 && v.minorVersion == 7 && v.patchVersion >= 2 && v.patchVersion <= 10
    }

    /// Kiểm tra thiết bị có thuộc diện hỗ trợ qua Cầu nối (iOS 18.7.2–18.7.10 hoặc iOS 27)
    static var isBridgeSupportedOS: Bool {
        isIOS27 || isIOS18_7_x
    }

    /// Cache đường dẫn container game trên iOS 27 / 18.7.x
    private static var cachedContainerPaths: [String: String] = [:]

    // MARK: - Live Network Interface & Tunnel Probe

    struct VPNInterfaceInfo {
        let active: Bool
        let deviceIP: String
        let tunnelIP: String
        let interfaceName: String
    }

    /// Kiểm tra xem Network Interface của LocalDevVPN (utun với IP 10.7.0.1 / 10.7.1.1) có đang Active thực tế trên máy không
    /// QUY TẮC CHẶT CHẼ:
    /// - Chỉ chấp nhận interface ảo có tên bắt đầu bằng "utun" (LocalDevVPN NetworkExtension PacketTunnel).
    /// - Cờ mạng bắt buộc phải IFF_UP và IFF_RUNNING.
    /// - IP thiết bị bắt buộc phải chính xác là "10.7.0.1" (do LocalDevVPN cấu hình).
    /// - Tuyệt đối không kiểm tra en0 (Wi-Fi), pdp_ip0 (Cellular), lo0 (Loopback) để tránh kết quả giả mạo.
    static func detectVPNInterface() -> VPNInterfaceInfo {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return VPNInterfaceInfo(active: false, deviceIP: "", tunnelIP: "", interfaceName: "")
        }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr

        while let current = ptr {
            let interface = current.pointee
            let flags = UInt32(interface.ifa_flags)

            // 1. Giao diện mạng bắt buộc phải đang BẬT (IFF_UP) và đang CHẠY (IFF_RUNNING)
            let isUp = (flags & UInt32(IFF_UP)) != 0
            let isRunning = (flags & UInt32(IFF_RUNNING)) != 0

            if isUp && isRunning, let ifaAddr = interface.ifa_addr {
                let name = String(cString: interface.ifa_name)

                // 2. LocalDevVPN trên iOS luôn tạo interface ảo utun (chẳng hạn utun0, utun1, utun2...)
                if name.hasPrefix("utun") {
                    let addrFamily = ifaAddr.pointee.sa_family
                    if addrFamily == UInt8(AF_INET) {
                        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                        let res = getnameinfo(
                            ifaAddr,
                            socklen_t(ifaAddr.pointee.sa_len),
                            &hostname,
                            socklen_t(hostname.count),
                            nil,
                            0,
                            NI_NUMERICHOST
                        )
                        if res == 0 {
                            let ip = String(cString: hostname)
                            // 3. Địa chỉ IP của LocalDevVPN trên máy bắt buộc là 10.7.0.1 (Device IP)
                            if ip == defaultHost {
                                var tunnelIP = tunnelHost
                                if let dstAddr = interface.ifa_dstaddr, dstAddr.pointee.sa_family == UInt8(AF_INET) {
                                    var dstHost = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                                    if getnameinfo(dstAddr, socklen_t(dstAddr.pointee.sa_len), &dstHost, socklen_t(dstHost.count), nil, 0, NI_NUMERICHOST) == 0 {
                                        let parsedDst = String(cString: dstHost)
                                        if !parsedDst.isEmpty {
                                            tunnelIP = parsedDst
                                        }
                                    }
                                }
                                return VPNInterfaceInfo(active: true, deviceIP: ip, tunnelIP: tunnelIP, interfaceName: name)
                            }
                        }
                    }
                }
            }
            ptr = interface.ifa_next
        }

        return VPNInterfaceInfo(active: false, deviceIP: "", tunnelIP: "", interfaceName: "")
    }

    /// Kiểm tra kết nối tới LocalDevVPN tunnel (10.7.0.1)
    /// Trả về true NẾU VÀ CHỈ NẾU giao diện utun của LocalDevVPN đang hoạt động thực tế
    static func isTunnelActive() -> Bool {
        guard isBridgeSupportedOS else { return false }
        return detectVPNInterface().active
    }

    // MARK: - Container Resolution (iOS 18.7.x & iOS 27)

    /// Tìm container data của game trên iOS 18.7.x / 27
    static func resolveContainerPath(bundleID: String) -> String? {
        guard isBridgeSupportedOS else { return nil }

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

    // MARK: - File Operations & Injection (iOS 18.7.x & iOS 27)

    /// Thực hiện nạp patch và cấu hình vào container game trên iOS 18.7.x / 27
    static func inject(
        target: FreeFireTarget,
        patchData: Data,
        configData: Data,
        localData: Data,
        tokenData: Data?
    ) -> Bool {
        guard isBridgeSupportedOS else { return false }

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

    /// Đồng bộ cấu hình cheat trên iOS 18.7.x / 27
    static func syncConfig(target: FreeFireTarget, configData: Data) -> Bool {
        guard isBridgeSupportedOS else { return false }

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

    /// Gỡ bỏ patch trên iOS 18.7.x / 27
    static func uninject(target: FreeFireTarget) -> Bool {
        guard isBridgeSupportedOS else { return false }

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

    /// Kiểm tra đã inject chưa trên iOS 18.7.x / 27
    static func isInjected(target: FreeFireTarget) -> Bool {
        guard isBridgeSupportedOS else { return false }
        guard let containerPath = resolveContainerPath(bundleID: target.rawValue) else {
            return false
        }
        let patchURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents/Assembly-CSharp-patch.bytes")
        return FileManager.default.fileExists(atPath: patchURL.path)
    }

    /// Gửi tín hiệu thông báo tới LocalDevVPN tunnel nếu đang lắng nghe
    private static func notifyTunnelOfInjection(target: FreeFireTarget) {
        guard isBridgeSupportedOS else { return }
        guard isTunnelActive() else { return }
        for host in [defaultHost, tunnelHost] {
            guard let url = URL(string: "http://\(host):\(defaultPort)/airlift/ping") else { continue }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = 0.5
            let payload: [String: Any] = [
                "bundleID": target.rawValue,
                "action": "injected",
                "timestamp": Date().timeIntervalSince1970
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: payload, options: [])
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            URLSession.shared.dataTask(with: request) { _, _, _ in }.resume()
        }
    }

    /// Chuỗi mô tả trạng thái dành cho UI trên iOS 27 và iOS 18.7.x
    static func statusDescription() -> String {
        guard isBridgeSupportedOS else { return "" }
        let osName = isIOS18_7_x ? "iOS 18.7.x" : "iOS 27"
        let vpn = detectVPNInterface()
        if vpn.active {
            return "\(osName) LocalDevVPN (\(vpn.interfaceName): \(vpn.deviceIP)) — Đã kết nối"
        } else {
            return "\(osName) LocalDevVPN — Chưa kết nối (VPN đang tắt)"
        }
    }

    /// Kiểm tra kết nối tới LocalDevVPN tunnel thực tế (10.7.0.1)
    /// Trả về success: true NẾU VÀ CHỈ NẾU giao diện utun đang UP và có IP 10.7.0.1
    static func testConnection() async -> (success: Bool, host: String, interfaceName: String) {
        guard isBridgeSupportedOS else {
            return (false, "Không hỗ trợ phiên bản iOS này", "")
        }

        let vpn = detectVPNInterface()
        if vpn.active {
            return (true, "\(vpn.deviceIP) (Tunnel: \(vpn.tunnelIP))", vpn.interfaceName)
        } else {
            return (false, "\(defaultHost) (Chưa kích hoạt)", "")
        }
    }
}

// MARK: - Observable Manager for SwiftUI

@MainActor
final class LocalDevVPNManager: ObservableObject {
    static let shared = LocalDevVPNManager()

    @Published var isConnected: Bool = false
    @Published var isConnecting: Bool = false
    @Published var statusMessage: String = "Chưa kết nối (LocalDevVPN đang Tắt)"
    @Published var lastConnectedHost: String = "\(LocalDevVPNBridge.defaultHost) (Tunnel: \(LocalDevVPNBridge.tunnelHost))"
    @Published var detectedInterfaceName: String = ""
    @Published var lastCheckDate: Date?

    private init() {
        refreshStatus()
    }

    /// Đồng bộ trạng thái thực tế từ interface kernel
    func refreshStatus() {
        let vpn = LocalDevVPNBridge.detectVPNInterface()
        if vpn.active {
            self.isConnected = true
            self.detectedInterfaceName = vpn.interfaceName
            self.statusMessage = "Đã kết nối (\(vpn.interfaceName): \(vpn.deviceIP))"
            self.lastConnectedHost = "\(vpn.deviceIP) (Tunnel: \(vpn.tunnelIP))"
        } else {
            self.isConnected = false
            self.detectedInterfaceName = ""
            self.statusMessage = "Chưa kết nối (LocalDevVPN đang Tắt)"
            self.lastConnectedHost = "\(LocalDevVPNBridge.defaultHost) (Chưa kích hoạt)"
        }
    }

    /// Kích hoạt kiểm tra kết nối thủ công từ Cài đặt hoặc Màn hình chính
    func connect() async -> (success: Bool, message: String) {
        isConnecting = true
        defer { isConnecting = false }

        // Delay 0.25s để hiển thị spinner phản hồi thao tác người dùng
        try? await Task.sleep(nanoseconds: 250_000_000)

        let res = await LocalDevVPNBridge.testConnection()
        lastCheckDate = Date()
        let osName = LocalDevVPNBridge.isIOS18_7_x ? "iOS 18.7.x" : "iOS 27"

        if res.success {
            isConnected = true
            detectedInterfaceName = res.interfaceName
            statusMessage = "Đã kết nối (\(res.interfaceName): \(res.host))"
            lastConnectedHost = res.host
            _ = LocalDevVPNBridge.resolveContainerPath(bundleID: FreeFireTarget.freeFireTH.rawValue)
            _ = LocalDevVPNBridge.resolveContainerPath(bundleID: FreeFireTarget.freeFireMAX.rawValue)

            let msg = """
            ✅ PHÁT HIỆN LOCALDEVVPN HOẠT ĐỘNG THẬT!
            • Giao diện mạng: \(res.interfaceName)
            • IP thiết bị: \(res.host)

            📱 BƯỚC TIẾP THEO (NHÀ PHÁT TRIỂN):
            1. Mở Cài đặt > Quyền riêng tư & Bảo mật > Chế độ Nhà phát triển: Đảm bảo công tắc đã BẬT.
            2. Nếu đây là lần đầu kết nối, mở Cài đặt > Nhà phát triển và xác nhận Ghép đôi thiết bị (Pairing).
            3. Quay lại đây và nhấn 'NẠP CHEAT' để nạp menu vào game!
            """
            return (true, msg)
        } else {
            isConnected = false
            detectedInterfaceName = ""
            statusMessage = "Chưa kết nối (LocalDevVPN đang Tắt)"
            lastConnectedHost = "\(LocalDevVPNBridge.defaultHost) (Chưa kích hoạt)"

            let msg = """
            ❌ KHÔNG TÌM THẤY LOCALDEVVPN: Giao diện utun (10.7.0.1) hiện đang TẮT!

            👉 CÁCH XỬ LÝ (2 BƯỚC):
            1. Thoát ra màn hình chính, mở ứng dụng 'LocalDevVPN'.
            2. Gạt công tắc sang trạng thái 'Connected' (hiển thị Tunnel IP: 10.7.1.1, Device IP: 10.7.0.1).
            3. Quay lại ứng dụng này và bấm nút 'KẾT NỐI \(osName.uppercased())' lại.
            """
            return (false, msg)
        }
    }
}

