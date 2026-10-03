import Foundation
import UIKit
import Darwin
import MachO

/// Tầng bảo vệ an toàn và gửi cảnh báo về Server AntiCrack Hub.
/// Ngăn chặn và phát hiện các công cụ bẻ khóa IPA và tiêm dylib: Esign / Scarlet injection, optool, Frida, iGameGod, Cycript,...
/// Thiết kế chuẩn xác: Không gây lỗi khi ký bình thường, nhưng phát hiện ngay lập tức khi bị tiêm bất kỳ tệp dylib nào từ bên ngoài.
enum DylibInjectionGuard {

    // MARK: - Constants
    private static let expectedAppNames: Set<String> = [
        "INNOVA CHEAT",
        "INNOVACHEAT",
        "ThreeOneOSFive"
    ]

    // Danh sách đen các dylib / công cụ bẻ khóa rõ ràng (không chặn jailbreak engine thông thường như ElleKit, Substitute, libhooker)
    private static let blacklistedKeywords: [String] = [
        "frida",
        "fridagadget",
        "igamegod",
        "cycript",
        "sslkillswitch",
        "flexing",
        "satella",
        "libsparkapplist"
    ]

    // MARK: - 1. Kiểm tra tên App (Anti-App-Name-Tampering)
    private static func checkAppName() -> String? {
        let displayName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let displayName, !displayName.isEmpty, !expectedAppNames.contains(displayName) {
            return "CFBundleDisplayName modified: '\(displayName)'"
        }

        let bundleName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bundleName, !bundleName.isEmpty, !expectedAppNames.contains(bundleName) {
            return "CFBundleName modified: '\(bundleName)'"
        }

        return nil
    }

    // MARK: - 2. Kiểm tra các biến môi trường dyld (DYLD_INSERT_LIBRARIES)
    private static func checkDyldEnvironment() -> String? {
        let envVars = [
            "DYLD_INSERT_LIBRARIES",
            "_MSSafeMode"
        ]
        for env in envVars {
            if let val = getenv(env) {
                let str = String(cString: val)
                if !str.isEmpty {
                    let lower = str.lowercased()
                    for kw in blacklistedKeywords {
                        if lower.contains(kw) {
                            return "Injected crack environment variable: \(env)=\(str)"
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - 3. Quét Header Mach-O của chính file thực thi xem có bị chèn dylib crack không
    private static func checkMachOLoadCommands() -> String? {
        guard let headerPtr = _dyld_get_image_header(0) else { return nil }

        let is64 = headerPtr.pointee.magic == MH_MAGIC_64 || headerPtr.pointee.magic == MH_CIGAM_64
        var curPtr = UnsafeRawPointer(headerPtr)
        curPtr += is64 ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size

        let ncmds = headerPtr.pointee.ncmds
        for _ in 0..<ncmds {
            let cmd = curPtr.load(as: load_command.self)
            if cmd.cmd == LC_LOAD_DYLIB || cmd.cmd == LC_LOAD_WEAK_DYLIB || cmd.cmd == LC_REEXPORT_DYLIB || cmd.cmd == UInt32(LC_LAZY_LOAD_DYLIB) {
                let dylibCmd = curPtr.load(as: dylib_command.self)
                let nameOffset = Int(dylibCmd.dylib.name.offset)
                if nameOffset < Int(cmd.cmdsize) {
                    let nameCStr = curPtr.advanced(by: nameOffset).assumingMemoryBound(to: CChar.self)
                    let dylibName = String(cString: nameCStr)
                    let lower = dylibName.lowercased()

                    // Thư viện hệ thống iOS hợp lệ: libSystem, libobjc, libswift, /System/Library, /usr/lib
                    if lower.hasPrefix("/system/library/") || lower.hasPrefix("/usr/lib/") || lower.contains("libswift") || lower.contains("libsystem") || lower.contains("libobjc") {
                        curPtr += Int(cmd.cmdsize)
                        continue
                    }

                    // Phát hiện bất kỳ dylib nào được tiêm qua @executable_path, @rpath, hoặc đường dẫn cục bộ (do Esign/optool/Sideloadly thêm vào)
                    if lower.contains("@executable_path") || lower.contains("@rpath") || lower.hasSuffix(".dylib") {
                        return "Injected dylib load command in Mach-O: \(dylibName)"
                    }

                    for keyword in blacklistedKeywords {
                        if lower.contains(keyword) {
                            return "Blacklisted dylib in Mach-O header: \(dylibName)"
                        }
                    }
                }
            }
            curPtr += Int(cmd.cmdsize)
        }
        return nil
    }

    // MARK: - 4. Quét tất cả các Dynamic Libraries (dyld images) đang nạp trong RAM
    private static func checkLoadedDyldImages() -> String? {
        let count = _dyld_image_count()
        let bundlePath = Bundle.main.bundlePath.lowercased()

        for i in 1..<count {
            guard let cName = _dyld_get_image_name(i) else { continue }
            let imageName = String(cString: cName)
            let lowerImage = imageName.lowercased()

            // Bỏ qua thư viện hệ thống
            if lowerImage.hasPrefix("/system/library/") || lowerImage.hasPrefix("/usr/lib/") || lowerImage.contains("libswift") || lowerImage.contains("libsystem") || lowerImage.contains("libobjc") {
                continue
            }

            // Bất kỳ dylib nào được nạp từ trong App Bundle đều là dylib tiêm ngoài (Esign, Scarlet, Sideloadly)
            if (lowerImage.contains(bundlePath) || lowerImage.contains("/containers/bundle/application/")) && lowerImage.hasSuffix(".dylib") {
                return "Injected dylib active in RAM: \(imageName)"
            }

            // Kiểm tra các công cụ bẻ khóa / hooking nổi tiếng
            for keyword in blacklistedKeywords {
                if lowerImage.contains(keyword) {
                    return "Blacklisted crack library in RAM: \(imageName)"
                }
            }
        }
        return nil
    }

    // MARK: - 5. Quét thư mục Bundle trên đĩa: Phát hiện bất kỳ file .dylib nào bị nhét vào IPA
    private static func checkBundleIntegrity() -> String? {
        guard let bundleURL = Bundle.main.bundleURL as URL? else { return nil }

        let dirsToCheck = [
            bundleURL,
            bundleURL.appendingPathComponent("Frameworks")
        ]

        for dir in dirsToCheck {
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
                for file in files {
                    let lower = file.lowercased()
                    // 1. Mọi file .dylib nằm trong thư mục app bundle đều là dylib tiêm lậu từ bên ngoài
                    if lower.hasSuffix(".dylib") {
                        return "Injected dylib found in bundle: \(file)"
                    }
                    // 2. Kiểm tra các tool bẻ khóa phổ biến
                    for keyword in blacklistedKeywords {
                        if lower.contains(keyword) {
                            return "Crack tool found in bundle: \(file)"
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Gửi báo cáo can thiệp / crack về Server (Anti-Crack Telemetry)
    private static func reportTamperToServer(violationType: String, details: String, waitTimeout: TimeInterval = 0) {
        let key = LicenseStore.shared.savedKey ?? ""
        let devSerial = DeviceIdentity.serial()
        let idfv = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let devModel = UIDevice.current.model
        let sysVersion = "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
        let devName = UIDevice.current.name
        let bundleId = Bundle.main.bundleIdentifier ?? ""
        let appName = (Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String)
            ?? (Bundle.main.infoDictionary?["CFBundleName"] as? String) ?? "Unknown"
        let locale = Locale.current.identifier
        let timezone = TimeZone.current.identifier
        let screen = "\(Int(UIScreen.main.bounds.width))x\(Int(UIScreen.main.bounds.height))@\(Int(UIScreen.main.scale))x"

        let payload: [String: Any] = [
            "key": key,
            "deviceSerial": devSerial,
            "idfv": idfv,
            "deviceModel": devModel,
            "systemVersion": sysVersion,
            "deviceName": devName,
            "bundleId": bundleId,
            "appName": appName,
            "locale": locale,
            "timezone": timezone,
            "screenResolution": screen,
            "violationType": violationType,
            "details": details,
            "timestamp": Int(Date().timeIntervalSince1970)
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else { return }

        let url = PatchHubService.baseURL.appendingPathComponent("api/security/tamper-report")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 2.0
        req.httpBody = jsonData

        let sema = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: req) { _, _, _ in
            if waitTimeout > 0 { sema.signal() }
        }
        task.resume()

        if waitTimeout > 0 {
            _ = sema.wait(timeout: .now() + waitTimeout)
        }
    }

    // MARK: - Phản ứng phòng vệ: Gửi báo cáo, dọn RAM và thoát app
    @inline(never)
    static func triggerTamperReaction(reason: String, violationType: String = "TAMPER_DETECTED") -> Never {
        NSLog("[DylibInjectionGuard] 🚨 PHÁT HIỆN CAN THIỆP / BẺ KHÓA [%@]: %@", violationType, reason)

        // Báo cáo chi tiết về Server AntiCrack Hub trước khi thoát (đợi tối đa 0.8s để gói tin gửi thành công)
        reportTamperToServer(violationType: violationType, details: reason, waitTimeout: 0.8)

        // Xóa RAM và cache
        FreeFirePatchService.wipeSensitiveMemory()

        // Xóa Keychain
        LicenseStore.shared.clear()

        exit(0)
    }

    /// Entry point: Kiểm tra an toàn chống tiêm dylib và can thiệp nhị phân
    static func enforceAllProtections() {
        // 1. Kiểm tra file .dylib bị tiêm vào Bundle (Esign, Scarlet, Sideloadly)
        if let err = checkBundleIntegrity() {
            triggerTamperReaction(reason: err, violationType: "DYLIB_INJECTION")
        }

        // 2. Kiểm tra Header Mach-O xem có bị optool / Esign chèn lệnh nạp dylib không
        if let err = checkMachOLoadCommands() {
            triggerTamperReaction(reason: err, violationType: "MACHO_HEADER_TAMPER")
        }

        // 3. Kiểm tra các dylib tiêm lậu đang nạp trong RAM
        if let err = checkLoadedDyldImages() {
            triggerTamperReaction(reason: err, violationType: "DYLIB_INJECTION")
        }

        // 4. Kiểm tra biến môi trường tiêm dylib bẻ khóa
        if let err = checkDyldEnvironment() {
            triggerTamperReaction(reason: err, violationType: "DYLD_INSERT_LIBRARIES")
        }

        // 5. Kiểm tra đổi tên app (chỉ report telemetry cảnh báo, không kill nhằm tránh lỗi khi ký sideload)
        if let err = checkAppName() {
            NSLog("[DylibInjectionGuard] Telemetry warning: %@", err)
            reportTamperToServer(violationType: "APP_NAME_TAMPER", details: err)
        }
    }
}
