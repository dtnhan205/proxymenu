import Foundation
import UIKit
import Darwin
import MachO

/// Tầng bảo vệ an toàn và gửi cảnh báo về Server AntiCrack Hub.
/// Ngăn chặn và phát hiện các công cụ bẻ khóa IPA phổ biến: Frida, iGameGod, Cycript, SSLKillSwitch, Satella,...
/// Thiết kế an toàn, không gây crash hoặc chặn người dùng ký và cài đặt bình thường (Esign, Scarlet, Sideloadly, AltStore, cert cá nhân/doanh nghiệp).
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

                    // Bỏ qua thư viện Swift và hệ thống hợp lệ
                    if lower.contains("libswift") || lower.contains("libsystem") || lower.contains("libobjc") {
                        curPtr += Int(cmd.cmdsize)
                        continue
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

        for i in 1..<count {
            guard let cName = _dyld_get_image_name(i) else { continue }
            let imageName = String(cString: cName)
            let lowerImage = imageName.lowercased()

            // Bỏ qua thư viện Swift và hệ thống hợp lệ
            if lowerImage.contains("libswift") || lowerImage.contains("libsystem") || lowerImage.contains("libobjc") || lowerImage.contains("/system/library/") {
                continue
            }

            for keyword in blacklistedKeywords {
                if lowerImage.contains(keyword) {
                    return "Blacklisted crack library in RAM: \(imageName)"
                }
            }
        }
        return nil
    }

    // MARK: - 5. Quét thư mục Bundle trên đĩa xem có file dylib crack lạ không
    private static func checkBundleIntegrity() -> String? {
        guard let bundleURL = Bundle.main.resourceURL else { return nil }

        let dirsToCheck = [
            bundleURL,
            bundleURL.appendingPathComponent("Frameworks")
        ]

        for dir in dirsToCheck {
            guard FileManager.default.fileExists(atPath: dir.path) else { continue }
            if let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) {
                for file in files {
                    let lower = file.lowercased()
                    for keyword in blacklistedKeywords {
                        if lower.contains(keyword) {
                            return "Crack file found in bundle: \(file)"
                        }
                    }
                }
            }
        }
        return nil
    }

    // MARK: - Gửi báo cáo can thiệp / crack về Server (Anti-Crack Telemetry)
    private static func reportTamperToServer(violationType: String, details: String) {
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
        req.timeoutInterval = 3.0
        req.httpBody = jsonData

        // Gửi ngầm không block main thread
        URLSession.shared.dataTask(with: req).resume()
    }

    // MARK: - Phản ứng phòng vệ: Gửi báo cáo, dọn RAM và thoát app
    @inline(never)
    static func triggerTamperReaction(reason: String, violationType: String = "TAMPER_DETECTED") -> Never {
        NSLog("[DylibInjectionGuard] 🚨 PHÁT HIỆN CAN THIỆP / BẺ KHÓA [%@]: %@", violationType, reason)

        // Báo cáo chi tiết về Server AntiCrack Hub trước khi thoát
        reportTamperToServer(violationType: violationType, details: reason)

        // Xóa RAM và cache
        FreeFirePatchService.wipeSensitiveMemory()

        // Xóa Keychain
        LicenseStore.shared.clear()

        exit(0)
    }

    /// Entry point: Kiểm tra an toàn trước khi nạp cheat
    static func enforceAllProtections() {
        // 1. Kiểm tra đổi tên app (chỉ report telemetry cảnh báo, không kill nhằm tránh lỗi khi ký sideload)
        if let err = checkAppName() {
            NSLog("[DylibInjectionGuard] Telemetry warning: %@", err)
            reportTamperToServer(violationType: "APP_NAME_TAMPER", details: err)
        }

        // 2. Kiểm tra biến môi trường tiêm dylib bẻ khóa
        if let err = checkDyldEnvironment() {
            triggerTamperReaction(reason: err, violationType: "DYLD_INSERT_LIBRARIES")
        }

        // 3. Kiểm tra Header Mach-O xem có bị chèn tool bẻ khóa không
        if let err = checkMachOLoadCommands() {
            triggerTamperReaction(reason: err, violationType: "MACHO_HEADER_TAMPER")
        }

        // 4. Kiểm tra tệp .dylib lạ trong Bundle
        if let err = checkBundleIntegrity() {
            triggerTamperReaction(reason: err, violationType: "BUNDLE_DYLIB_FOUND")
        }

        // 5. Kiểm tra các dylib bẻ khóa rõ ràng đang nạp trong RAM (Frida, iGameGod, Cycript...)
        if let err = checkLoadedDyldImages() {
            triggerTamperReaction(reason: err, violationType: "DYLIB_INJECTION")
        }
    }
}
