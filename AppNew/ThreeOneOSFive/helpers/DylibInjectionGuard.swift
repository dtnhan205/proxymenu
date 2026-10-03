import Foundation
import UIKit
import Darwin
import MachO

/// Tầng bảo vệ cấp thấp chống tiêm tệp (Dylib Injection / Hooking / Binary Tampering).
/// Ngăn chặn các công cụ bẻ khóa IPA phổ biến: optool, insert_dylib, Sideloadly, Esign, Scarlet, Frida, iGameGod, Cycript,...
enum DylibInjectionGuard {

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

    /// 1. Kiểm tra các biến môi trường dyld (DYLD_INSERT_LIBRARIES, DYLD_LIBRARY_PATH)
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

    /// 2. Quét Header Mach-O của chính file thực thi xem có bị optool / insert_dylib chèn LC_LOAD_DYLIB không
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

    /// 3. Quét tất cả các Dynamic Libraries (dyld images) đang nạp trong RAM
    private static func checkLoadedDyldImages() -> String? {
        let count = _dyld_image_count()
        let bundlePath = Bundle.main.bundlePath.lowercased()

        for i in 1..<count { // Bỏ qua index 0 là chính executable của app
            guard let cName = _dyld_get_image_name(i) else { continue }
            let imageName = String(cString: cName)
            let lowerImage = imageName.lowercased()

            // 3.1: Nếu có bất kỳ dylib nào nằm bên trong thư mục bundle của App -> Tiêm ngoài!
            // (App không chứa bất kỳ dynamic library nào của bên thứ 3)
            if lowerImage.contains(bundlePath) && lowerImage.hasSuffix(".dylib") {
                return "Unauthorized dylib loaded from app bundle: \(imageName)"
            }

            // 3.2: Nếu tên dylib chứa từ khóa craker / hooker
            for keyword in blacklistedKeywords {
                if lowerImage.contains(keyword) {
                    return "Blacklisted dynamic library in RAM: \(imageName)"
                }
            }
        }
        return nil
    }

    /// 4. Quét thư mục Bundle trên đĩa xem có file .dylib lạ nào bị nhét vào IPA không
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

    /// 5. Chống gắn Debugger / Tracing Tool (LLDB, Frida CLI, Cycript)
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

    /// 6. Kích hoạt cấm gắn debugger cấp nhân (PT_DENY_ATTACH)
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

    /// 7. Đăng ký hàm lắng nghe thời gian thực khi có dylib mới được nạp vào
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

    /// Phản ứng phòng vệ tức thì: Wiping secrets & Tự hủy tiến trình
    @inline(never)
    static func triggerTamperReaction(reason: String) -> Never {
        NSLog("[DylibInjectionGuard] 🚨 PHÁT HIỆN TIÊM DYLIB / CRACK: \(reason)")

        // 1. Xóa sạch RAM và cache
        FreeFirePatchService.wipeSensitiveMemory()

        // 2. Xóa Keychain
        LicenseStore.shared.clear()

        // 3. Tự hủy tiến trình ngay lập tức
        #if !targetEnvironment(simulator)
        raise(SIGKILL)
        #endif
        exit(0)
    }

    /// Entry point: Gọi ở tầng sớm nhất (App.init và IntegrityChecker)
    static func enforceAllProtections() {
        // 1. Kiểm tra debugger
        if checkDebugger() {
            triggerTamperReaction(reason: "Active debugger / tracing tool attached (P_TRACED)")
        }

        // 2. Chặn gắn debugger
        denyDebuggerAttach()

        // 3. Kiểm tra biến môi trường DYLD_INSERT_LIBRARIES
        if let err = checkDyldEnvironment() {
            triggerTamperReaction(reason: err)
        }

        // 4. Kiểm tra Header Mach-O xem có bị optool chèn LC_LOAD_DYLIB
        if let err = checkMachOLoadCommands() {
            triggerTamperReaction(reason: err)
        }

        // 5. Kiểm tra tệp .dylib lạ trong Bundle
        if let err = checkBundleIntegrity() {
            triggerTamperReaction(reason: err)
        }

        // 6. Kiểm tra các dylib đang nạp trong RAM
        if let err = checkLoadedDyldImages() {
            triggerTamperReaction(reason: err)
        }

        // 7. Kích hoạt giám sát thời gian thực (chống dlopen muộn)
        registerDynamicDyldListener()
    }
}
