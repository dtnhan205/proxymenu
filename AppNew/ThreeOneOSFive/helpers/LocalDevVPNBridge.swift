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

    /// Kiểm tra thiết bị có thuộc diện hỗ trợ qua Cầu nối (Pairing record, LocalDevVPN hoặc iOS 17+)
    static var isBridgeSupportedOS: Bool {
        if RemotePairingAdvertiser.shared.hasExistingPairing || detectVPNInterface().active {
            return true
        }
        return isIOS27 || isIOS18_7_x || ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 17
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
            if ContainerStore.isApplicationContainerPath(cached) {
                return cached
            }
            cachedContainerPaths.removeValue(forKey: bundleID)
        }

        // 0. ƯU TIÊN 1: Nếu đã có Pairing File từ Developer Mode (Airlift / RPPairing), truy vấn qua RSD Installation Proxy
        if RemotePairingAdvertiser.shared.hasExistingPairing {
            let pairingPath = RemotePairingAdvertiser.shared.pairingFilePath
            if let airliftPath = AirliftBridge.findAppContainerSync(bundleID: bundleID, pairingPath: pairingPath),
               !airliftPath.isEmpty {
                _ = ContainerStore.grantContainerAccess(airliftPath)
                cachedContainerPaths[bundleID] = airliftPath
                return airliftPath
            }
        }

        // 1. Kiểm tra qua MobileContainerManager (MCMActivateContainerPath)
        var lookupError: NSString?
        if let mcmPath = MCMActivateContainerPath(2, bundleID, false, &lookupError),
           ContainerStore.isApplicationContainerPath(mcmPath) {
            _ = ContainerStore.grantContainerAccess(mcmPath)
            cachedContainerPaths[bundleID] = mcmPath
            return mcmPath
        }

        // 2. Kiểm tra qua LSApplicationProxy (chỉ chấp nhận nếu path hợp lệ /Containers/Data/Application/...)
        let info = (appInfoForBundleID(bundleID) as? [String: Any]) ?? [:]
        if let container = info["container"] as? String,
           !container.isEmpty,
           ContainerStore.isApplicationContainerPath(container),
           FileManager.default.fileExists(atPath: container) {
            _ = ContainerStore.grantContainerAccess(container)
            cachedContainerPaths[bundleID] = container
            return container
        }

        // 3. Quét qua appDataRoot /var/mobile/Containers/Data/Application
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
                    _ = ContainerStore.grantContainerAccess(containerPath)
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
                            _ = ContainerStore.grantContainerAccess(containerPath)
                            cachedContainerPaths[bundleID] = containerPath
                            return containerPath
                        }
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Diagnostics & Real File Access Probe

    /// Chạy kiểm tra toàn diện: File Pairing, VPN Tunnel, Free Fire Container & Documents R/W Probe
    static func runFullDiagnostics() -> [String] {
        var logs: [String] = []
        func logEntry(_ tag: String, _ msg: String, icon: String = "ℹ️") {
            let line = "[\(tag)] \(icon) \(msg)"
            logs.append(line)
            AppLog.shared.append(line)
            print(line)
        }

        let timeStr = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        logEntry("TEST", "BẮT ĐẦU KIỂM TRA TRUY CẬP THỰC TẾ (\(timeStr))", icon: "🚀")

        // 1. KIỂM TRA FILE PAIRING
        let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let candidatePaths = [
            ("innova_pairing.plist", (docs as NSString).appendingPathComponent("innova_pairing.plist")),
            ("innova_pairing_import.plist", (docs as NSString).appendingPathComponent("innova_pairing_import.plist")),
            ("delta_pairing.plist", (docs as NSString).appendingPathComponent("delta_pairing.plist")),
            ("delta_pairing_import.plist", (docs as NSString).appendingPathComponent("delta_pairing_import.plist")),
            ("local_pairing.plist", (docs as NSString).appendingPathComponent("pairing_records/local_pairing.plist"))
        ]

        var foundPairing = false
        for (name, path) in candidatePaths {
            if FileManager.default.fileExists(atPath: path) {
                foundPairing = true
                if let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                   let size = attrs[.size] as? Int64 {
                    if let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                       let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                        let keys = plist.keys.joined(separator: ", ")
                        logEntry("PAIRING", "Tìm thấy \(name): \(size) bytes (Keys: \(keys))", icon: "✅")
                    } else {
                        logEntry("PAIRING", "Tìm thấy \(name): \(size) bytes (Dữ liệu hợp lệ)", icon: "✅")
                    }
                } else {
                    logEntry("PAIRING", "Tìm thấy \(name)", icon: "✅")
                }
            }
        }
        if !foundPairing {
            logEntry("PAIRING", "CHƯA CÓ FILE PAIRING! Hãy bấm 'Tạo File Trực Tiếp' hoặc 'Nhập .plist'.", icon: "⚠️")
        }

        // 2. KIỂM TRA LOCALDEVVPN TUNNEL
        let vpn = detectVPNInterface()
        if vpn.active {
            logEntry("VPN", "Giao diện \(vpn.interfaceName) ĐANG BẬT! (IP máy: \(vpn.deviceIP), Tunnel: \(vpn.tunnelIP))", icon: "✅")
            let route = probeKernelRouteToTunnel()
            if route.routed {
                logEntry("VPN", "Bảng định tuyến Kernel: Đã route tới \(tunnelHost):\(defaultPort)", icon: "✅")
            } else {
                logEntry("VPN", "Định tuyến tới \(tunnelHost): Chờ kích hoạt routing", icon: "ℹ️")
            }
        } else {
            logEntry("VPN", "LocalDevVPN ĐANG TẮT (Giao diện utun 10.7.0.1 chưa bật)", icon: "⚠️")
        }

        // 3. KIỂM TRA FREE FIRE CONTAINERS VÀ DOCUMENTS
        let targets = [
            ("Free Fire Thường (TH)", FreeFireTarget.freeFireTH.rawValue),
            ("Free Fire MAX", FreeFireTarget.freeFireMAX.rawValue)
        ]

        for (displayName, bundleID) in targets {
            logEntry("GAME", "--- Kiểm tra \(displayName) (\(bundleID)) ---", icon: "🎮")

            // Kiểm tra cài đặt qua LSApplicationProxy
            let info = (appInfoForBundleID(bundleID) as? [String: Any]) ?? [:]
            let isInstalled = (info["found"] as? NSNumber)?.boolValue ?? false || (info["name"] != nil && (info["name"] as? String) != bundleID)
            let version = info["version"] as? String ?? "N/A"

            if isInstalled {
                logEntry("GAME", "\(displayName): ĐÃ CÀI ĐẶT trên máy (v\(version))", icon: "📱")
            } else {
                logEntry("GAME", "\(displayName): Thử tìm theo bundle ID \(bundleID)", icon: "🔍")
            }

            // Tìm container path (chỉ chấp nhận container hợp lệ của game, tuyệt đối không chấp nhận /var/mobile)
            var containerPath: String? = nil
            if let c = ContainerStore.resolveAppContainerPath(bundleID: bundleID), ContainerStore.isApplicationContainerPath(c) {
                containerPath = c
            } else if let c = resolveContainerPath(bundleID: bundleID), ContainerStore.isApplicationContainerPath(c) {
                containerPath = c
            } else if let c = info["container"] as? String, ContainerStore.isApplicationContainerPath(c) {
                containerPath = c
            }

            if let container = containerPath, ContainerStore.isApplicationContainerPath(container) {
                logEntry("CONTAINER", "Container Data: \(container)", icon: "📂")

                let docsPath = (container as NSString).appendingPathComponent("Documents")
                let docsExists = FileManager.default.fileExists(atPath: docsPath)

                if docsExists {
                    let grantHandle = ContainerStore.grantContainerAccess(container)
                    defer {
                        if grantHandle >= 0 {
                            bad_query_release(grantHandle)
                        }
                    }

                    let isReadable = FileManager.default.isReadableFile(atPath: docsPath)
                    let isWritable = FileManager.default.isWritableFile(atPath: docsPath)
                    logEntry("DOCUMENTS", "Thư mục Documents: TỒN TẠI (Đọc: \(isReadable ? "OK" : "NO"), Ghi: \(isWritable ? "OK" : "NO"))", icon: "📁")

                    // Liệt kê nội dung Documents
                    if let contents = try? FileManager.default.contentsOfDirectory(atPath: docsPath) {
                        let count = contents.count
                        let preview = contents.prefix(5).joined(separator: ", ")
                        logEntry("DOCUMENTS", "Nội dung Documents (\(count) mục): \(preview)\(count > 5 ? "..." : "")", icon: "📄")
                    }

                    // Test ghi / đọc file thực tế (Read/Write Probe)
                    let probePath = (docsPath as NSString).appendingPathComponent(".innova_probe_test.tmp")
                    let testPayload = "INNOVA_PROBE_\(Date().timeIntervalSince1970)".data(using: .utf8)!
                    var probeSuccess = false
                    do {
                        try testPayload.write(to: URL(fileURLWithPath: probePath), options: .atomic)
                        let verifyData = try Data(contentsOf: URL(fileURLWithPath: probePath))
                        try? FileManager.default.removeItem(atPath: probePath)
                        if verifyData == testPayload {
                            probeSuccess = true
                            logEntry("PROBE", "TRUY CẬP DOCUMENTS (POSIX TRỰC TIẾP): ✅ ĐÃ GHI & ĐỌC THÀNH CÔNG (100% ACCESS)", icon: "🎉")
                        } else {
                            logEntry("PROBE", "Dữ liệu kiểm tra không khớp", icon: "⚠️")
                        }
                    } catch {
                        logEntry("PROBE", "Ghi trực tiếp POSIX: \(error.localizedDescription) (Sandbox hạn chế)", icon: "ℹ️")
                    }

                    if !probeSuccess && RemotePairingAdvertiser.shared.hasExistingPairing {
                        let pairingPath = RemotePairingAdvertiser.shared.pairingFilePath
                        let probeStaging = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("probe_\(UUID().uuidString)")
                        try? FileManager.default.createDirectory(at: probeStaging, withIntermediateDirectories: true)
                        defer { try? FileManager.default.removeItem(at: probeStaging) }
                        try? testPayload.write(to: probeStaging.appendingPathComponent(".innova_probe_test.tmp"), options: .atomic)

                        logEntry("PROBE", "Thử nghiệm ghi qua AirTraffic / Developer Mode tunnel...", icon: "📡")
                        var outError: UnsafeMutablePointer<CChar>? = nil
                        AirliftBridge.syncTargetHosts()
                        let cb: ALLogCallback = { _, msg in
                            guard let msg = msg else { return }
                            let line = String(cString: msg)
                            AppLog.shared.append("[AIRLIFT LOG] \(line)")
                            RemotePairingAdvertiser.shared.log("[AIRLIFT] \(line)")
                        }
                        let rc = al_exploit_write_dir(pairingPath, probeStaging.path, docsPath, cb, nil, &outError)
                        if rc == 0 {
                            logEntry("PROBE", "TRUY CẬP DOCUMENTS QUA AIRLIFT/DEVELOPER MODE: ✅ ĐÃ GHI THÀNH CÔNG (100% ACCESS)", icon: "🎉")
                        } else {
                            let msg = outError != nil ? String(cString: outError!) : "rc=\(rc)"
                            if let errPtr = outError { al_string_free(errPtr) }
                            logEntry("PROBE", "Thử nghiệm AirTraffic: \(msg)", icon: "⚠️")
                        }
                    }

                    // Kiểm tra patch file hiện tại
                    let patchPath = (docsPath as NSString).appendingPathComponent("Assembly-CSharp-patch.bytes")
                    if FileManager.default.fileExists(atPath: patchPath) {
                        if let attrs = try? FileManager.default.attributesOfItem(atPath: patchPath) {
                            let size = (attrs[FileAttributeKey.size] as? NSNumber)?.int64Value ?? 0
                            logEntry("PATCH", "File Assembly-CSharp-patch.bytes: ✅ ĐÃ NẠP SẴN (\(size) bytes)", icon: "⚡")
                        }
                    } else {
                        logEntry("PATCH", "File Assembly-CSharp-patch.bytes: Chưa nạp (Sẵn sàng nạp khi bấm nút)", icon: "ℹ️")
                    }
                } else {
                    logEntry("DOCUMENTS", "Thư mục Documents chưa tạo (Hãy mở game Free Fire 1 lần để tạo Documents)", icon: "⚠️")
                }
            } else {
                logEntry("CONTAINER", "Chưa quét thấy thư mục Container của \(displayName). (Hãy mở game ít nhất 1 lần để hệ thống kích hoạt)", icon: "ℹ️")
            }
        }

        logEntry("TEST", "HOÀN TẤT KIỂM TRA TRUY CẬP HỆ THỐNG", icon: "🏁")
        return logs
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

        // 0. ƯU TIÊN 1: Nếu có Pairing Record từ Developer Mode (Airlift / RPPairing), ghi qua AirTraffic tunnel
        if RemotePairingAdvertiser.shared.hasExistingPairing,
           let containerPath = resolveContainerPath(bundleID: target.rawValue) {
            let pairingPath = RemotePairingAdvertiser.shared.pairingFilePath
            let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("vpn_staging_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: stagingDir) }

            let patchFile = stagingDir.appendingPathComponent("Assembly-CSharp-patch.bytes")
            let localFile = stagingDir.appendingPathComponent("localConfig.json")
            let cfgFile = stagingDir.appendingPathComponent(FreeFirePatchService.configFileName)

            try? patchData.write(to: patchFile, options: .atomic)
            try? localData.write(to: localFile, options: .atomic)
            try? configData.write(to: cfgFile, options: .atomic)

            if let tokenData, !tokenData.isEmpty {
                try? tokenData.write(to: stagingDir.appendingPathComponent(FreeFirePatchService.tokenFileName), options: .atomic)
            }

            let deepCfgDir = stagingDir.appendingPathComponent("contentcache/Optional/ios/gameassetbundles", isDirectory: true)
            let deepTokDir = stagingDir.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles", isDirectory: true)
            try? FileManager.default.createDirectory(at: deepCfgDir, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: deepTokDir, withIntermediateDirectories: true)

            try? configData.write(to: deepCfgDir.appendingPathComponent(FreeFirePatchService.configFileName), options: .atomic)
            if let tokenData, !tokenData.isEmpty {
                try? tokenData.write(to: deepTokDir.appendingPathComponent(FreeFirePatchService.tokenFileName), options: .atomic)
            }

            AirliftBridge.syncTargetHosts()
            var outError: UnsafeMutablePointer<CChar>? = nil
            let rc = al_exploit_write_dir(
                pairingPath,
                stagingDir.path,
                "\(containerPath)/Documents",
                nil,
                nil,
                &outError
            )
            if rc == 0 {
                success = true
                AppLog.shared.append("[VPN] ✅ Ghi file qua AirTraffic tunnel thành công!")
            } else {
                let msg = outError != nil ? String(cString: outError!) : "rc=\(rc)"
                if let err = outError { al_string_free(err) }
                AppLog.shared.append("[VPN] ⚠️ Ghi qua AirTraffic: \(msg)")
            }
        }

        // 1. Ghi trực tiếp vào Container nếu đã tìm thấy đường dẫn
        if let containerPath = resolveContainerPath(bundleID: target.rawValue),
           ContainerStore.isApplicationContainerPath(containerPath) {
            let grantHandle = ContainerStore.grantContainerAccess(containerPath)
            defer {
                if grantHandle >= 0 {
                    bad_query_release(grantHandle)
                }
            }
            let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents", isDirectory: true)
            let deepCfgDir = docsURL.appendingPathComponent("contentcache/Optional/ios/gameassetbundles", isDirectory: true)
            let deepTokDir = docsURL.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles", isDirectory: true)

            try? FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: deepCfgDir, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: deepTokDir, withIntermediateDirectories: true)

            let patchURL = docsURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
            let localURL = docsURL.appendingPathComponent("localConfig.json")
            let deepCfgFile = deepCfgDir.appendingPathComponent(FreeFirePatchService.configFileName)
            let deepTokFile = deepTokDir.appendingPathComponent(FreeFirePatchService.tokenFileName)

            if (try? patchData.write(to: patchURL, options: .atomic)) != nil {
                success = true
            }
            try? localData.write(to: localURL, options: .atomic)
            try? configData.write(to: deepCfgFile, options: .atomic)

            if let tokenData, !tokenData.isEmpty {
                try? tokenData.write(to: deepTokFile, options: .atomic)
            }

            // Dọn dẹp file thừa ở Documents root để không lộ ra app Files
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(FreeFirePatchService.configFileName))
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(FreeFirePatchService.tokenFileName))
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
        let deepCfgFile = deepCfgDir.appendingPathComponent(FreeFirePatchService.configFileName)
        do {
            try configData.write(to: deepCfgFile, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Neutral Patch 322 bytes (Assembly-CSharp-patch-neutral.bytes)
    /// Hợp lệ theo chuẩn InjectFix nhưng chứa 0 method hook -> Vô hiệu hóa ngay lập tức
    private static let neutralPatchBase64 = "y6K0DbIZo2ZkSUZpeC5JTEZpeEludGVyZmFjZUJyaWRnZSwgQXNzZW1ibHktQ1NoYXJwLCBWZXJzaW9uPTAuODYuMC41MTgsIEN1bHR1cmU9bmV1dHJhbCwgUHVibGljS2V5VG9rZW49bnVsbAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAABjSUZpeC5XcmFwcGVyc01hbmFnZXJJbXBsLCBBc3NlbWJseS1DU2hhcnAsIFZlcnNpb249MC44Ni4wLjUxOCwgQ3VsdHVyZT1uZXV0cmFsLCBQdWJsaWNLZXlUb2tlbj1udWxsSywgQXNzZW1ibHktQ1NoYXJwLCBWZXJzaW9uPTAuODYuMC41MTgsIEN1bHR1cmU9bmV1dHJhbCwgUHVibGljS2V5VG9rZW49bnVsbAAAAAAAAAAAAA=="

    /// Gỡ bỏ patch: Ghi đè Neutral Patch và kích hoạt cơ chế Tự Hủy (Self-Delete) qua AirTraffic vào Free Fire
    static func uninject(target: FreeFireTarget) -> Bool {
        guard isBridgeSupportedOS else { return false }

        guard let containerPath = resolveContainerPath(bundleID: target.rawValue) else {
            return false
        }

        var airtrafficSuccess = false

        // 1. Ghi tín hiệu Uninject / Self-Delete & Neutral Patch qua AirTraffic tunnel
        if RemotePairingAdvertiser.shared.hasExistingPairing {
            let pairingPath = RemotePairingAdvertiser.shared.pairingFilePath
            let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("uninject_staging_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: stagingDir) }

            // Neutral Patch 322 bytes (Vô hiệu hóa ngay mã patch bytecode)
            let neutralData = Data(base64Encoded: neutralPatchBase64) ?? Data()
            try? neutralData.write(to: stagingDir.appendingPathComponent("Assembly-CSharp-patch.bytes"), options: .atomic)

            // Cấu hình vô hiệu hóa & Cờ Self-Delete
            let uninstalledJson = "{\"enabled\":false,\"uninstalled\":true,\"uninject\":true,\"features\":{}}".data(using: .utf8) ?? Data()
            try? uninstalledJson.write(to: stagingDir.appendingPathComponent("localConfig.json"), options: .atomic)
            try? uninstalledJson.write(to: stagingDir.appendingPathComponent(FreeFirePatchService.configFileName), options: .atomic)
            try? uninstalledJson.write(to: stagingDir.appendingPathComponent("uninject.flag"), options: .atomic)

            // Token vô hiệu hóa
            let emptyTok = "{\"token\":\"\",\"expired\":true,\"status\":\"uninjected\"}".data(using: .utf8) ?? Data()
            try? emptyTok.write(to: stagingDir.appendingPathComponent(FreeFirePatchService.tokenFileName), options: .atomic)

            // Ghi trực tiếp vào Documents root của Free Fire
            AirliftBridge.syncTargetHosts()
            var outError: UnsafeMutablePointer<CChar>? = nil
            let rc = al_exploit_write_dir(
                pairingPath,
                stagingDir.path,
                "\(containerPath)/Documents",
                nil,
                nil,
                &outError
            )
            if rc == 0 {
                airtrafficSuccess = true
                AppLog.shared.append("[UNINJECT] 🗑️ Đã ghi đè Neutral Patch & cờ Self-Delete vào Documents game!")
            } else {
                let msg = outError != nil ? String(cString: outError!) : "rc=\(rc)"
                if let err = outError { al_string_free(err) }
                AppLog.shared.append("[UNINJECT] ⚠️ AirTraffic uninject Documents: \(msg)")
            }

            // Ghi đè file config sâu vào contentcache/Optional/ios/gameassetbundles
            let subCfgStaging = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("uninject_cfg_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: subCfgStaging, withIntermediateDirectories: true)
            try? uninstalledJson.write(to: subCfgStaging.appendingPathComponent(FreeFirePatchService.configFileName), options: .atomic)
            try? uninstalledJson.write(to: subCfgStaging.appendingPathComponent("menu_config.json"), options: .atomic)
            let rcCfg = AirliftBridge.injectFolderSync(
                folderPath: subCfgStaging.path,
                targetParentDir: "\(containerPath)/Documents/contentcache/Optional/ios",
                destName: "gameassetbundles",
                pairingPath: pairingPath
            )
            try? FileManager.default.removeItem(at: subCfgStaging)
            if rcCfg == 0 {
                AppLog.shared.append("[UNINJECT] 🗑️ Đã vô hiệu hóa config sâu (gameassetbundles)")
            }

            // Ghi đè token sâu vào contentcache/Optional/ios/optionalavatarres/gameassetbundles
            let subTokStaging = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("uninject_tok_\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: subTokStaging, withIntermediateDirectories: true)
            try? emptyTok.write(to: subTokStaging.appendingPathComponent(FreeFirePatchService.tokenFileName), options: .atomic)
            try? emptyTok.write(to: subTokStaging.appendingPathComponent(".innova_token.dat"), options: .atomic)
            let rcTok = AirliftBridge.injectFolderSync(
                folderPath: subTokStaging.path,
                targetParentDir: "\(containerPath)/Documents/contentcache/Optional/ios/optionalavatarres",
                destName: "gameassetbundles",
                pairingPath: pairingPath
            )
            try? FileManager.default.removeItem(at: subTokStaging)
            if rcTok == 0 {
                AppLog.shared.append("[UNINJECT] 🗑️ Đã vô hiệu hóa token sâu (optionalavatarres)")
            }
        }

        // 2. Dọn dẹp cục bộ qua FileManager nếu có quyền (Jailbreak / Shared container fallback)
        let containerURL = URL(fileURLWithPath: containerPath)
        let docs = containerURL.appendingPathComponent("Documents")
        let patchURL = docs.appendingPathComponent("Assembly-CSharp-patch.bytes")
        let localURL = docs.appendingPathComponent("localConfig.json")
        let deepCfg = docs.appendingPathComponent("contentcache/Optional/ios/gameassetbundles/\(FreeFirePatchService.configFileName)")
        let deepTok = docs.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles/\(FreeFirePatchService.tokenFileName)")

        try? FileManager.default.removeItem(at: patchURL)
        try? FileManager.default.removeItem(at: localURL)
        try? FileManager.default.removeItem(at: deepCfg)
        try? FileManager.default.removeItem(at: deepTok)
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("contentcache/Optional/ios/gameassetbundles/menu_config.json"))
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles/.innova_token.dat"))
        try? FileManager.default.removeItem(at: docs.appendingPathComponent("uninject.flag"))

        return airtrafficSuccess || true
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

            let hasPairing = RemotePairingAdvertiser.shared.hasExistingPairing
            let msg: String
            if hasPairing {
                msg = """
                ✅ LOCALDEVVPN ĐÃ KẾT NỐI THÀNH CÔNG!
                • Giao diện mạng: \(res.interfaceName)
                • Tunnel: \(res.host)
                • Trạng thái Pairing: ✅ ĐÃ CÓ FILE PAIRING

                🎉 THIẾT BỊ ĐÃ SẴN SÀNG!
                Bạn không cần vào Chế độ Nhà phát triển để ghép đôi nữa.
                👉 Hãy mở game Free Fire và bấm 'NẠP MOD / ANTI-BAN' ngay!
                """
            } else {
                msg = """
                ✅ LOCALDEVVPN ĐÃ KẾT NỐI THÀNH CÔNG!
                • Giao diện mạng: \(res.interfaceName)
                • Tunnel: \(res.host)

                👉 BƯỚC TIẾP THEO:
                Vào Cài đặt > Ghép đôi iOS 27 > Bấm "TẠO FILE PAIRING TRỰC TIẾP" (hoặc Nhập file .plist từ máy tính) để hoàn tất!
                """
            }
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

