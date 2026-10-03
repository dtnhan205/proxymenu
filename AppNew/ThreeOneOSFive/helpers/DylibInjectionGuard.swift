import Foundation
import UIKit
import Darwin
import MachO
import CryptoKit

/// Tầng bảo vệ cấp thấp chống tiêm tệp, chống đổi tên và chống thay logo app.
/// Ngăn chặn các công cụ bẻ khóa IPA phổ biến: optool, insert_dylib, Sideloadly, Esign, Scarlet, Frida, iGameGod, Cycript,...
enum DylibInjectionGuard {

    // MARK: - Constants
    private static let expectedAppName = "INNOVA CHEAT"
    private static let expectedLogoHashHex = "e69a84bf756dd47159be10ea4f08f210686961e98c4a50d9e5fb8a6ba5b61b02"
    private static let expectedLogoFileSize = 1774901

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
        // A. Kiểm tra trong InfoDictionary
        let displayName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if displayName != expectedAppName {
            return "CFBundleDisplayName tampered: '\(displayName ?? "")' (expected '\(expectedAppName)')"
        }

        let bundleName = (Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if bundleName != expectedAppName {
            return "CFBundleName tampered: '\(bundleName ?? "")' (expected '\(expectedAppName)')"
        }

        // B. Kiểm tra localized InfoDictionary
        if let locDisplay = (Bundle.main.localizedInfoDictionary?["CFBundleDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
           locDisplay != expectedAppName {
            return "Localized CFBundleDisplayName tampered: '\(locDisplay)'"
        }

        // C. Đọc trực tiếp tệp Info.plist trên đĩa trong Bundle
        if let infoURL = Bundle.main.url(forResource: "Info", withExtension: "plist"),
           let infoDict = NSDictionary(contentsOf: infoURL) as? [String: Any] {
            let diskDisplay = (infoDict["CFBundleDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if diskDisplay != expectedAppName {
                return "On-disk Info.plist CFBundleDisplayName tampered: '\(diskDisplay ?? "")'"
            }
            let diskName = (infoDict["CFBundleName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            if diskName != expectedAppName {
                return "On-disk Info.plist CFBundleName tampered: '\(diskName ?? "")'"
            }
        }

        // D. Quét toàn bộ file localization strings
        if let resPath = Bundle.main.resourcePath,
           let items = try? FileManager.default.contentsOfDirectory(atPath: resPath) {
            for item in items where item.hasSuffix(".lproj") {
                let p = (resPath as NSString).appendingPathComponent("\(item)/InfoPlist.strings")
                if FileManager.default.fileExists(atPath: p),
                   let dict = NSDictionary(contentsOfFile: p) as? [String: Any] {
                    if let n = (dict["CFBundleDisplayName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       n != expectedAppName {
                        return "InfoPlist.strings in \(item) tampered: '\(n)'"
                    }
                    if let n = (dict["CFBundleName"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                       n != expectedAppName {
                        return "InfoPlist.strings CFBundleName in \(item) tampered: '\(n)'"
                    }
                }
            }
        }

        return nil
    }

    // MARK: - 2. Chống thay đổi Logo / Icon App (Anti-Logo-Tampering)
    private static func checkAppLogo() -> String? {
        // A. Kiểm tra cấu hình icon trong Info.plist
        if let infoIcons = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
           let primary = infoIcons["CFBundlePrimaryIcon"] as? [String: Any] {
            let iconName = (primary["CFBundleIconName"] as? String) ?? ""
            if !iconName.isEmpty && iconName != "AppIcon" {
                return "CFBundleIconName tampered: '\(iconName)' (expected 'AppIcon')"
            }
        }

        // B. Kiểm tra tệp ảnh AppIcon-1024.png trực tiếp trên đĩa (đối chiếu hash SHA256 & kích thước)
        if let iconURL = Bundle.main.url(forResource: "AppIcon-1024", withExtension: "png") {
            guard let data = try? Data(contentsOf: iconURL) else {
                return "Cannot read AppIcon-1024.png from bundle"
            }
            if data.count != expectedLogoFileSize {
                return "AppIcon-1024.png file size tampered: \(data.count) != \(expectedLogoFileSize)"
            }
            let digest = SHA256.hash(data: data)
            let hash = digest.map { String(format: "%02x", $0) }.joined()
            if hash != expectedLogoHashHex {
                return "AppIcon-1024.png SHA256 tampered: \(hash)"
            }
        }

        // C. Kiểm tra ảnh Logo nạp vào bộ nhớ RAM (AppIcon-1024 hoặc AppIcon)
        if let image = UIImage(named: "AppIcon-1024") ?? UIImage(named: "AppIcon"),
           let cgImage = image.cgImage {
            let width = cgImage.width
            let height = cgImage.height
            if width != 1024 || height != 1024 {
                return "App logo resolution mismatch: \(width)x\(height) (expected 1024x1024)"
            }

            // Vẽ vào buffer bitmap RGBA để kiểm tra điểm ảnh đặc trưng
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            var pixelBuffer = [UInt8](repeating: 0, count: width * height * 4)
            if let ctx = CGContext(
                data: &pixelBuffer,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: width * 4,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) {
                ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

                func pixelAt(_ x: Int, _ y: Int) -> (r: UInt8, g: UInt8, b: UInt8) {
                    let idx = (y * width + x) * 4
                    return (pixelBuffer[idx], pixelBuffer[idx + 1], pixelBuffer[idx + 2])
                }

                // Điểm tâm logo (512, 512): xanh lá thương hiệu INNOVA (G >= 80, G > R, G > B)
                let center = pixelAt(512, 512)
                if center.g < 80 || center.g <= center.r {
                    return "Logo center color mismatch (tampered logo image)"
                }

                // Điểm góc (100, 100): nền tối cyberpunk (R < 35, G < 35, B < 35)
                let corner = pixelAt(100, 100)
                if corner.r > 35 || corner.g > 35 || corner.b > 35 {
                    return "Logo corner background mismatch (tampered logo background)"
                }
            }
        }

        return nil
    }

    // MARK: - 3. Kiểm tra các biến môi trường dyld (DYLD_INSERT_LIBRARIES, DYLD_LIBRARY_PATH)
    private static func checkDyldEnvironment() -> String? {
        let envVars = [
            "DYLD_INSERT_LIBRARIES",
            "DYLD_LIBRARY_PATH",
            "DYLD_FRAMEWORK_PATH",
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

    // MARK: - 4. Quét Header Mach-O của chính file thực thi xem có bị optool / insert_dylib chèn LC_LOAD_DYLIB không
    private static func checkMachOLoadCommands() -> String? {
        guard let headerPtr = _dyld_get_image_header(0) else { return nil }

        let is64 = headerPtr.pointee.magic == MH_MAGIC_64 || headerPtr.pointee.magic == MH_CIGAM_64
        var curPtr = UnsafeRawPointer(headerPtr)
        curPtr += is64 ? MemoryLayout<mach_header_64>.size : MemoryLayout<mach_header>.size

        let ncmds = headerPtr.pointee.ncmds
        for _ in 0..<ncmds {
            let cmd = curPtr.load(as: load_command.self)
            // Kiểm tra các lệnh tải dynamic library
            if cmd.cmd == LC_LOAD_DYLIB || cmd.cmd == LC_LOAD_WEAK_DYLIB || cmd.cmd == LC_REEXPORT_DYLIB || cmd.cmd == UInt32(LC_LAZY_LOAD_DYLIB) {
                let dylibCmd = curPtr.load(as: dylib_command.self)
                let nameOffset = Int(dylibCmd.dylib.name.offset)
                if nameOffset < Int(cmd.cmdsize) {
                    let nameCStr = curPtr.advanced(by: nameOffset).assumingMemoryBound(to: CChar.self)
                    let dylibName = String(cString: nameCStr)

                    // Trong app INNOVA, toàn bộ thư viện hợp lệ đều nằm ở /System/Library/ hoặc /usr/lib/.
                    // Bất kỳ lệnh nào trỏ vào @executable_path, @rpath hoặc đường dẫn ngoài đều do tool tiêm vào.
                    if dylibName.hasPrefix("@executable_path") || dylibName.hasPrefix("@rpath") {
                        return "Injected LC_LOAD_DYLIB in Mach-O header: \(dylibName)"
                    }

                    let lower = dylibName.lowercased()
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

    // MARK: - 5. Quét tất cả các Dynamic Libraries (dyld images) đang nạp trong RAM
    private static func checkLoadedDyldImages() -> String? {
        let count = _dyld_image_count()
        let bundlePath = Bundle.main.bundlePath.lowercased()

        for i in 1..<count { // Bỏ qua index 0 là chính executable của app
            guard let cName = _dyld_get_image_name(i) else { continue }
            let imageName = String(cString: cName)
            let lowerImage = imageName.lowercased()

            // 5.1: Nếu có bất kỳ dylib nào nằm bên trong thư mục bundle của App -> Tiêm ngoài!
            if lowerImage.contains(bundlePath) && lowerImage.hasSuffix(".dylib") {
                return "Unauthorized dylib loaded from app bundle: \(imageName)"
            }

            // 5.2: Nếu tên dylib chứa từ khóa craker / hooker
            for keyword in blacklistedKeywords {
                if lowerImage.contains(keyword) {
                    return "Blacklisted dynamic library in RAM: \(imageName)"
                }
            }
        }
        return nil
    }

    // MARK: - 6. Quét thư mục Bundle trên đĩa xem có file .dylib lạ nào bị nhét vào IPA không
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
                    if lower.hasSuffix(".dylib") {
                        return "Illegal .dylib file found in bundle: \(file)"
                    }
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

    // MARK: - 7. Chống gắn Debugger / Tracing Tool (LLDB, Frida CLI, Cycript)
    private static func checkDebugger() -> Bool {
        #if targetEnvironment(simulator)
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

    // MARK: - 8. Kích hoạt cấm gắn debugger cấp nhân (PT_DENY_ATTACH)
    private static func denyDebuggerAttach() {
        #if !targetEnvironment(simulator)
        let handle = dlopen(nil, RTLD_GLOBAL | RTLD_NOW)
        if let ptracePtr = dlsym(handle, "ptrace") {
            typealias PtraceType = @convention(c) (CInt, pid_t, CInt, CInt) -> CInt
            let ptraceFunc = unsafeBitCast(ptracePtr, to: PtraceType.self)
            _ = ptraceFunc(31, 0, 0, 0) // PT_DENY_ATTACH = 31
        }
        #endif
    }

    // MARK: - 9. Đăng ký hàm lắng nghe thời gian thực khi có dylib mới được nạp vào
    private static var isListenerRegistered = false
    private static func registerDynamicDyldListener() {
        guard !isListenerRegistered else { return }
        isListenerRegistered = true

        _dyld_register_func_for_add_image { header, _ in
            guard let h = header else { return }
            var dlInfo = Dl_info()
            if dladdr(UnsafeRawPointer(h), &dlInfo) != 0, let fname = dlInfo.dli_fname {
                let path = String(cString: fname).lowercased()
                let bundlePath = Bundle.main.bundlePath.lowercased()

                if path.contains(bundlePath) && path.hasSuffix(".dylib") {
                    DylibInjectionGuard.triggerTamperReaction(reason: "Dynamic dylib loaded: \(path)")
                }
                for kw in DylibInjectionGuard.blacklistedKeywords {
                    if path.contains(kw) {
                        DylibInjectionGuard.triggerTamperReaction(reason: "Blacklisted dylib loaded: \(path)")
                    }
                }
            }
        }
    }

    // MARK: - Phản ứng phòng vệ tức thì: Wiping secrets & Tự hủy tiến trình
    @inline(never)
    static func triggerTamperReaction(reason: String) -> Never {
        NSLog("[DylibInjectionGuard] 🚨 PHÁT HIỆN CAN THIỆP / BẺ KHÓA: \(reason)")

        // 1. Xóa sạch RAM và cache
        FreeFirePatchService.wipeSensitiveMemory()

        // 2. Xóa Keychain
        LicenseStore.shared.clear()

        // 3. Tự hủy tiến trình ngay lập tức (Không cho dylib kịp hook)
        #if !targetEnvironment(simulator)
        raise(SIGKILL)
        #endif
        exit(0)
    }

    /// Entry point: Gọi ở tầng sớm nhất (App.init, IntegrityChecker, RootView, FreeFirePatchService)
    static func enforceAllProtections() {
        // 1. Chống đổi tên app
        if let err = checkAppName() {
            triggerTamperReaction(reason: err)
        }

        // 2. Chống thay đổi logo / icon app
        if let err = checkAppLogo() {
            triggerTamperReaction(reason: err)
        }

        // 3. Kiểm tra debugger
        if checkDebugger() {
            triggerTamperReaction(reason: "Active debugger / tracing tool attached (P_TRACED)")
        }

        // 4. Chặn gắn debugger
        denyDebuggerAttach()

        // 5. Kiểm tra biến môi trường DYLD_INSERT_LIBRARIES
        if let err = checkDyldEnvironment() {
            triggerTamperReaction(reason: err)
        }

        // 6. Kiểm tra Header Mach-O xem có bị optool chèn LC_LOAD_DYLIB
        if let err = checkMachOLoadCommands() {
            triggerTamperReaction(reason: err)
        }

        // 7. Kiểm tra tệp .dylib lạ trong Bundle
        if let err = checkBundleIntegrity() {
            triggerTamperReaction(reason: err)
        }

        // 8. Kiểm tra các dylib đang nạp trong RAM
        if let err = checkLoadedDyldImages() {
            triggerTamperReaction(reason: err)
        }

        // 9. Kích hoạt giám sát thời gian thực (chống dlopen muộn)
        registerDynamicDyldListener()
    }
}
