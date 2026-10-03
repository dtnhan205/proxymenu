import Foundation
import UIKit
import Darwin
import MachO

/// Tầng bảo vệ cấp thấp chống tiêm tệp dylib, chống công cụ bẻ khóa và gửi cảnh báo về Server.
/// Ngăn chặn các công cụ bẻ khóa IPA phổ biến: Frida, iGameGod, Cycript, CydiaSubstrate, Substitute, ElleKit, Dobby,...
enum DylibInjectionGuard {

    // MARK: - Constants
    private static let expectedAppName = "INNOVA CHEAT"

    // Danh sách đen các dylib / công cụ bẻ khóa / hooking phổ biến
    private static let blacklistedKeywords: [String] = [
        "frida",
        "gadget",
        "cydiasubstrate",
        "substitute",
        "libhooker",
        "ellekit",
        "dobby",
        "shadow",
        "igamegod",
        "cycript",
        "sslkillswitch",
        "flexing",
        "fishhook",
        "charlie",
        "satella",
        "libsparkapplist",
        "tweakinject"
    ]

    // MARK: - 1. Chống đổi tên App (Anti-App-Name-Tampering)
    private static func checkAppName() -> String? {
        let displayName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let displayName, !displayName.isEmpty, displayName != expectedAppName {
            return "CFBundleDisplayName tampered: '\(displayName)' (expected '\(expectedAppName)')"
        }

        let bundleName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bundleName, !bundleName.isEmpty, bundleName != expectedAppName {
            return "CFBundleName tampered: '\(bundleName)' (expected '\(expectedAppName)')"
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
                    return "Injected environment variable: \(env)=\(str)"
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
            if lowerImage.contains("libswift") || lowerImage.contains("libsystem") || lowerImage.contains("libobjc") {
                continue
            }

            for keyword in blacklistedKeywords {
                if lowerImage.contains(keyword) {
                    return "Blacklisted dynamic library in RAM: \(imageName)"
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

    // MARK: - 6. Chống gắn Debugger / Tracing Tool (chỉ bật trên Release thực tế ngoài Xcode)
    private static func checkDebugger() -> Bool {
        #if DEBUG || targetEnvironment(simulator)
        return false
        #else
        var info = kinfo_proc()
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var size = MemoryLayout<kinfo_proc>.stride
        let junk = sysctl(&mib, UInt32(mib.count), &info, &size, nil, 0)
        if junk == 0 && (info.kp_proc.p_flag & P_TRACED) != 0 {
            return true
        }
        return false
        #endif
    }

    private static func denyDebuggerAttach() {
        #if !DEBUG && !targetEnvironment(simulator)
        let handle = dlopen(nil, RTLD_GLOBAL | RTLD_NOW)
        if let ptracePtr = dlsym(handle, "ptrace") {
            typealias PtraceType = @convention(c) (CInt, pid_t, CInt, CInt) -> CInt
            let ptraceFunc = unsafeBitCast(ptracePtr, to: PtraceType.self)
            _ = ptraceFunc(31, 0, 0, 0) // PT_DENY_ATTACH = 31
        }
        #endif
    }

    // MARK: - 7. Lắng nghe dylib nạp động (chống dlopen muộn)
    private static var isListenerRegistered = false
    private static func registerDynamicDyldListener() {
        guard !isListenerRegistered else { return }
        isListenerRegistered = true

        _dyld_register_func_for_add_image { header, _ in
            guard let h = header else { return }
            var dlInfo = Dl_info()
            if dladdr(UnsafeRawPointer(h), &dlInfo) != 0, let fname = dlInfo.dli_fname {
                let path = String(cString: fname).lowercased()

                // Bỏ qua thư viện Swift và hệ thống
                if path.contains("libswift") || path.contains("libsystem") || path.contains("libobjc") {
                    return
                }

                for kw in DylibInjectionGuard.blacklistedKeywords {
                    if path.contains(kw) {
                        DylibInjectionGuard.triggerTamperReaction(reason: "Blacklisted dylib loaded: \(path)", violationType: "DYLIB_INJECTION")
                    }
                }
            }
        }
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
        req.timeoutInterval = 1.5
        req.httpBody = jsonData

        let sema = DispatchSemaphore(value: 0)
        let task = URLSession.shared.dataTask(with: req) { _, _, _ in
            sema.signal()
        }
        task.resume()
        _ = sema.wait(timeout: .now() + 1.2)
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

    /// Entry point: Kiểm tra an toàn trước khi nạp cheat hoặc trong quá trình chạy
    static func enforceAllProtections() {
        // 1. Chống đổi tên app
        if let err = checkAppName() {
            triggerTamperReaction(reason: err, violationType: "APP_NAME_TAMPER")
        }

        // 2. Kiểm tra debugger (chỉ active trên bản Release không có debugger Xcode)
        if checkDebugger() {
            triggerTamperReaction(reason: "Active debugger / tracing tool attached (P_TRACED)", violationType: "DEBUGGER_ATTACHED")
        }

        // 3. Chặn gắn debugger
        denyDebuggerAttach()

        // 4. Kiểm tra biến môi trường DYLD_INSERT_LIBRARIES
        if let err = checkDyldEnvironment() {
            triggerTamperReaction(reason: err, violationType: "DYLD_INSERT_LIBRARIES")
        }

        // 5. Kiểm tra Header Mach-O xem có bị chèn tool bẻ khóa không
        if let err = checkMachOLoadCommands() {
            triggerTamperReaction(reason: err, violationType: "MACHO_HEADER_TAMPER")
        }

        // 6. Kiểm tra tệp .dylib lạ trong Bundle
        if let err = checkBundleIntegrity() {
            triggerTamperReaction(reason: err, violationType: "BUNDLE_DYLIB_FOUND")
        }

        // 7. Kiểm tra các dylib đang nạp trong RAM
        if let err = checkLoadedDyldImages() {
            triggerTamperReaction(reason: err, violationType: "DYLIB_INJECTION")
        }

        // 8. Kích hoạt giám sát thời gian thực
        registerDynamicDyldListener()
    }
}
