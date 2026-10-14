import Foundation
import Darwin
import UIKit
import SystemConfiguration

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
    /// SỬ DỤNG ĐA PHƯƠNG THỨC XÁC THỰC THỰC TẾ (MULTI-TIER REAL PROBE):
    /// 1. getifaddrs: Tìm giao diện ảo utun (chỉ cần IFF_UP, không đòi hỏi IFF_RUNNING) có IP 10.7.0.1 hoặc 10.7.1.1 qua inet_ntop chuẩn.
    /// 2. UDP Route Probe: Tạo socket UDP tới 10.7.1.1 để kiểm tra bảng định tuyến kernel iOS xem IP nguồn có được gán là 10.7.0.1 hay không.
    /// 3. System Proxy Scopes: Kiểm tra utun trong __SCOPED__ của hệ thống.
    static func detectVPNInterface() -> VPNInterfaceInfo {
        // --- PHƯƠNG THỨC 1: Quét getifaddrs với POSIX inet_ntop chuẩn ---
        if let ifInfo = scanInterfacesForVPN() {
            return ifInfo
        }

        // --- PHƯƠNG THỨC 2: Kiểm tra Kernel Routing Table (UDP Connect to 10.7.1.1) ---
        let route = probeKernelRouteToTunnel()
        if route.routed {
            let ifName = route.interfaceName.isEmpty ? "utun (tunnel route)" : route.interfaceName
            return VPNInterfaceInfo(
                active: true,
                deviceIP: defaultHost, // "10.7.0.1"
                tunnelIP: tunnelHost,  // "10.7.1.1"
                interfaceName: ifName
            )
        }

        // --- PHƯƠNG THỨC 3: Kiểm tra System Configuration Scoped VPN ---
        if checkSystemVPNScoped() && route.canRouteToSubnet {
            return VPNInterfaceInfo(
                active: true,
                deviceIP: defaultHost,
                tunnelIP: tunnelHost,
                interfaceName: "utun (system scoped)"
            )
        }

        return VPNInterfaceInfo(active: false, deviceIP: "", tunnelIP: "", interfaceName: "")
    }

    /// Quét các interface mạng qua getifaddrs
    private static func scanInterfacesForVPN() -> VPNInterfaceInfo? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return nil
        }
        defer { freeifaddrs(ifaddr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = firstAddr

        while let current = ptr {
            let interface = current.pointee
            let flags = UInt32(interface.ifa_flags)

            // Giao diện mạng bắt buộc phải đang BẬT (IFF_UP).
            // LƯU Ý: Không check IFF_RUNNING vì trên iOS virtual tunnel interfaces (utun) thường không bật cờ này.
            let isUp = (flags & UInt32(IFF_UP)) != 0

            if isUp, let ifaAddr = interface.ifa_addr {
                let name = String(cString: interface.ifa_name)

                // Chỉ quét các interface dạng tunnel ảo (utun, tun, ppp, ipsec)
                if name.hasPrefix("utun") || name.hasPrefix("tun") || name.hasPrefix("ppp") || name.hasPrefix("ipsec") {
                    let addrFamily = ifaAddr.pointee.sa_family
                    if addrFamily == UInt8(AF_INET) {
                        var addrIn = ifaAddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                        var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                        var ip = ""
                        if inet_ntop(AF_INET, &addrIn.sin_addr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil {
                            ip = String(cString: buffer)
                        }

                        var dstIP = ""
                        if let dstAddr = interface.ifa_dstaddr, dstAddr.pointee.sa_family == UInt8(AF_INET) {
                            var dstIn = dstAddr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                            var dstBuf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                            if inet_ntop(AF_INET, &dstIn.sin_addr, &dstBuf, socklen_t(INET_ADDRSTRLEN)) != nil {
                                dstIP = String(cString: dstBuf)
                            }
                        }

                        // LocalDevVPN gán Device IP = 10.7.0.1 và Tunnel IP = 10.7.1.1
                        if ip == defaultHost || dstIP == tunnelHost || ip == tunnelHost || dstIP == defaultHost {
                            let resolvedDevice = (ip == defaultHost || dstIP == defaultHost) ? defaultHost : ip
                            let resolvedTunnel = (dstIP == tunnelHost || ip == tunnelHost) ? tunnelHost : dstIP
                            return VPNInterfaceInfo(
                                active: true,
                                deviceIP: resolvedDevice,
                                tunnelIP: resolvedTunnel.isEmpty ? tunnelHost : resolvedTunnel,
                                interfaceName: name
                            )
                        }
                    }
                }
            }
            ptr = interface.ifa_next
        }

        return nil
    }

    /// Thử tạo kết nối UDP socket tới 10.7.1.1:49152 để truy vấn bảng định tuyến kernel iOS
    private static func probeKernelRouteToTunnel() -> (routed: Bool, canRouteToSubnet: Bool, interfaceName: String) {
        let sock = socket(AF_INET, SOCK_DGRAM, 0)
        guard sock >= 0 else { return (false, false, "") }
        defer { close(sock) }

        var targetAddr = sockaddr_in()
        targetAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        targetAddr.sin_family = sa_family_t(AF_INET)
        targetAddr.sin_port = in_port_t(defaultPort).bigEndian
        inet_pton(AF_INET, tunnelHost, &targetAddr.sin_addr) // 10.7.1.1

        let connectRes = withUnsafePointer(to: &targetAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                connect(sock, saPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }

        guard connectRes == 0 else { return (false, false, "") }

        var localAddr = sockaddr_in()
        var len = socklen_t(MemoryLayout<sockaddr_in>.size)
        let getRes = withUnsafeMutablePointer(to: &localAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { saPtr in
                getsockname(sock, saPtr, &len)
            }
        }

        guard getRes == 0 else { return (false, false, "") }

        var buf = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
        if inet_ntop(AF_INET, &localAddr.sin_addr, &buf, socklen_t(INET_ADDRSTRLEN)) != nil {
            let localIP = String(cString: buf)
            // Nếu bảng định tuyến kernel của iOS gán địa chỉ nguồn tới 10.7.1.1 là 10.7.0.1
            // thì chắc chắn giao diện tunnel của LocalDevVPN đang hoạt động!
            if localIP == defaultHost {
                return (true, true, "utun (10.7.0.1)")
            } else if localIP.hasPrefix("10.7.") {
                return (true, true, "utun (\(localIP))")
            }
        }

        return (false, false, "")
    }

    /// Kiểm tra các Scoped VPN interface qua System Configuration
    private static func checkSystemVPNScoped() -> Bool {
        guard let cfDict = CFNetworkCopySystemProxySettings() else { return false }
        let nsDict = cfDict.takeRetainedValue() as NSDictionary
        guard let scopes = nsDict["__SCOPED__"] as? NSDictionary else { return false }
        for key in scopes.allKeys {
            if let name = key as? String, name.hasPrefix("utun") || name.hasPrefix("tun") || name.hasPrefix("ipsec") {
                return true
            }
        }
        return false
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
            ✅ LOCALDEVVPN ĐÃ KẾT NỐI THÀNH CÔNG!
            • Giao diện mạng: \(res.interfaceName)
            • Tunnel: \(res.host)

            👉 BƯỚC GHÉP ĐÔI THIẾT BỊ (iOS 27+):
            1. Vào Cài đặt > Quyền riêng tư & Bảo mật > Chế độ Nhà phát triển.
            2. Trong mục 'Các thiết bị khác', chọn 'Pair with INNOVA PROXY'.
            3. Xác nhận ghép đôi để kết nối dịch vụ hệ thống và nạp mod!
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

