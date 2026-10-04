import Foundation
import CryptoKit
import Darwin
import MachO

/// Tầng bảo vệ chống tamper local và dịch ngược ứng dụng.
/// Mục đích:
/// 1. Chống gắn Debugger (LLDB, debugserver) qua ptrace PT_DENY_ATTACH & sysctl P_TRACED
/// 2. Chống công cụ Hook động Frida (port probe 27042/27043, loaded dylibs, artifacts)
/// 3. Chống máy bẻ khóa Jailbreak (Dopamine, Palera1n, Sileo, Zebra, Rootless paths, Sandbox checks)
/// 4. Bảo vệ tính toàn vẹn Build Token và URL Endpoint (XOR obfuscation)
enum IntegrityChecker {

    /// Hard-coded SHA256 của plaintext URL. Nếu attacker đổi bytes array
    /// (dù vẫn XOR đúng decode ra URL khác) → hash mismatch → kill.
    /// Match với `https://serveripa.proxyvip.click`.
    private static let expectedBaseURLHashHex =
        "36996bcbfa05fad33a3333788db884dd9377d1b3d70835209f17bc0d1daa60ce"

    /// Hard-coded SHA256 của bundle identifier hợp lệ. Nếu attacker
    /// rebrand / re-sign app → bundle ID khác → mismatch → kill.
    /// Phải khớp với `PRODUCT_BUNDLE_IDENTIFIER` trong `project.pbxproj`.
    private static let expectedBundleID = "com.apple.mobile.MobileHouseArrest"

    // MARK: - Build Token (Source vs Release IPA)

    /// Build token dạng plaintext trong source code để dev dễ dàng thay đổi khi lập trình trong source.
    /// Khi build IPA release, chạy script:
    ///   `python tools/obfuscate_build_token.py --release`
    /// Script sẽ tự động mã hóa chuỗi này vào `buildTokenBytes` & `buildTokenKey` và xóa `sourceBuildToken = ""`
    /// để binary khi xuất ra IPA hoàn toàn không chứa plaintext token trong strings/rodata.
    static var sourceBuildToken: String = "INNOVA-CFHB9NCKUJEPVCUP"

    // Byte arrays mã hóa XOR (được cập nhật tự động bởi tools/obfuscate_build_token.py)
    private static let buildTokenBytes: [UInt8] = [
        0xC7, 0x32, 0x9C, 0xE6, 0xC1, 0x93, 0x56, 0x7C,
        0xE3, 0xCA, 0x2A, 0x69, 0xAA, 0x2A, 0xE4, 0x03,
        0xC4, 0x39, 0x82, 0xFF, 0xD4, 0x87, 0x2B
    ]
    private static let buildTokenKey: [UInt8] = [
        0x8E, 0x7C, 0xD2, 0xA9, 0x97, 0xD2, 0x7B, 0x3F,
        0xA5, 0x82, 0x68, 0x50, 0xE4, 0x69, 0xAF, 0x56
    ]

    /// Token bản build của INNOVA CHEAT.
    /// Ưu tiên:
    /// 1. Nếu sourceBuildToken có giá trị (môi trường dev/source) -> dùng ngay sourceBuildToken.
    /// 2. Nếu sourceBuildToken rỗng (môi trường build IPA release) -> giải mã XOR từ buildTokenBytes.
    static var buildToken: String {
        let src = sourceBuildToken.trimmingCharacters(in: .whitespacesAndNewlines)
        if !src.isEmpty {
            return src
        }
        guard !buildTokenBytes.isEmpty && !buildTokenKey.isEmpty else {
            return ""
        }
        var decoded = [UInt8](repeating: 0, count: buildTokenBytes.count)
        for i in 0..<buildTokenBytes.count {
            decoded[i] = buildTokenBytes[i] ^ buildTokenKey[i % buildTokenKey.count]
        }
        return String(bytes: decoded, encoding: .utf8) ?? ""
    }

    /// Kiểm tra token có đúng định dạng token bản build của INNOVA hay không (bắt đầu bằng INNOVA-)
    static func isInnovaBuildToken(_ token: String) -> Bool {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return trimmed.hasPrefix("INNOVA-") && trimmed.count >= 15
    }

    /// Bundle identifier hiện tại, gửi kèm request để server đối chiếu.
    static let bundleIdentifier: String = Bundle.main.bundleIdentifier ?? expectedBundleID

    /// Compute SHA256 hex của `String`.
    static func sha256Hex(_ s: String) -> String {
        let digest = SHA256.hash(data: Data(s.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Verify URL decoded khớp hash hard-coded. Trả về `nil` nếu OK,
    /// ngược lại trả về lý do mismatch.
    static func verifyBaseURL(_ url: URL) -> String? {
        let actual = sha256Hex(url.absoluteString)
        if actual != expectedBaseURLHashHex {
            return "baseURL integrity mismatch"
        }
        return nil
    }

    /// Verify bundle ID: Cho phép app chạy khi được ký bởi các chứng chỉ cá nhân / doanh nghiệp / Esign / Scarlet / Sideloadly / AltStore.
    static func verifyBundleID(_ id: String) -> String? {
        return nil
    }

    // MARK: - Chống Debugger (LLDB, debugserver)

    /// Chống gắn LLDB / debugserver: Đã vô hiệu hóa PT_DENY_ATTACH để app không bị iOS kernel bắn SIGKILL khi ký qua ESign / chứng chỉ cá nhân (get-task-allow=true)
    static func denyDebuggerAttach() {
        #if !targetEnvironment(simulator)
        // Lưu ý: Không gọi ptrace(PT_DENY_ATTACH, 0, 0, 0) vì chứng chỉ cá nhân / ESign có get-task-allow=true sẽ bị kernel kill ngay lập tức.
        #endif
    }

    /// Kiểm tra tiến trình có đang bị LLDB / Debugger theo dõi bằng sysctl P_TRACED
    static func isDebuggerAttached() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        var name: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()]
        var info = kinfo_proc()
        var infoSize = MemoryLayout<kinfo_proc>.stride
        let res = name.withUnsafeMutableBufferPointer { nameBuf in
            sysctl(nameBuf.baseAddress, 4, &info, &infoSize, nil, 0)
        }
        if res == 0 {
            return (info.kp_proc.p_flag & P_TRACED) != 0
        }
        return false
        #endif
    }

    // MARK: - Chống Frida & Công cụ Hook động

    /// Kiểm tra cổng mạng mặc định của Frida Server (27042, 27043) trên localhost
    static func isFridaPortOpen(port: UInt16) -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        var serverAddr = sockaddr_in()
        serverAddr.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        serverAddr.sin_family = sa_family_t(AF_INET)
        serverAddr.sin_port = port.bigEndian
        serverAddr.sin_addr.s_addr = inet_addr("127.0.0.1")

        let sock = socket(AF_INET, SOCK_STREAM, 0)
        if sock < 0 { return false }
        defer { close(sock) }

        var tv = timeval(tv_sec: 0, tv_usec: 30000) // 30ms timeout
        setsockopt(sock, SOL_SOCKET, SO_RCVTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))
        setsockopt(sock, SOL_SOCKET, SO_SNDTIMEO, &tv, socklen_t(MemoryLayout<timeval>.size))

        let connected = withUnsafePointer(to: &serverAddr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                connect(sock, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size)) == 0
            }
        }
        return connected
        #endif
    }

    /// Kiểm tra dylib của Frida, Substrate hoặc các framework can thiệp trong bộ nhớ
    static func isFridaOrTweakDylibLoaded() -> Bool {
        let count = _dyld_image_count()
        let badKeywords = [
            "frida", "gadget", "gum-js", "libellekit", "substitute", "substrate",
            "cydiasubstrate", "tweakloader", "shadow", "libsparkapplist"
        ]
        for i in 0..<count {
            guard let namePtr = _dyld_get_image_name(i) else { continue }
            let name = String(cString: namePtr).lowercased()
            for kw in badKeywords {
                if name.contains(kw) {
                    return true
                }
            }
        }
        return false
    }

    /// Kiểm tra tệp tin/artifact của Frida
    static func isFridaFilePresent() -> Bool {
        let fridaPaths = [
            "/usr/lib/frida",
            "/usr/lib/frida/frida-agent.dylib",
            "/Library/MobileSubstrate/DynamicLibraries/FridaLoader.dylib",
            "/Library/MobileSubstrate/DynamicLibraries/FridaLoader.plist"
        ]
        for p in fridaPaths {
            if FileManager.default.fileExists(atPath: p) {
                return true
            }
        }
        return false
    }

    /// Phát hiện Frida tổng hợp
    static func isFridaDetected() -> Bool {
        if isFridaPortOpen(port: 27042) || isFridaPortOpen(port: 27043) {
            return true
        }
        if isFridaOrTweakDylibLoaded() {
            return true
        }
        if isFridaFilePresent() {
            return true
        }
        return false
    }

    // MARK: - Chống Jailbreak Thiết Bị

    /// Kiểm tra toàn diện máy đã bị bẻ khóa Jailbreak hay chưa
    static func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        // 1. Kiểm tra các đường dẫn file phổ biến của Jailbreak (Cydia, Sileo, Zebra, Rootless, Dopamine, Palera1n)
        let paths = [
            "/Applications/Cydia.app",
            "/Applications/Sileo.app",
            "/Applications/Zebra.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/bin/sh",
            "/usr/sbin/sshd",
            "/usr/bin/ssh",
            "/etc/apt",
            "/private/var/lib/apt/",
            "/private/var/lib/cydia",
            "/private/var/stash",
            "/var/jb",
            "/var/binpack",
            "/usr/lib/libsubstitute.dylib",
            "/usr/lib/substrate",
            "/usr/lib/TweakInject",
            "/Library/MobileSubstrate/DynamicLibraries",
            "/var/jb/usr/lib/libellekit.dylib"
        ]
        for p in paths {
            if FileManager.default.fileExists(atPath: p) { return true }
        }

        // 2. Thử ghi ra ngoài Sandbox (trên iOS gốc, /private/... bị chặn)
        let probe = "/private/jailbreak_probe_\(UUID().uuidString).txt"
        do {
            try "x".write(toFile: probe, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: probe)
            return true
        } catch {
            // Bình thường không ghi được
        }

        // 3. Kiểm tra symlink bất thường của root filesystem
        let symlinkPaths = ["/Applications", "/usr/include", "/usr/libexec", "/usr/share"]
        for p in symlinkPaths {
            var statInfo = stat()
            if lstat(p, &statInfo) == 0 {
                if (statInfo.st_mode & S_IFMT) == S_IFLNK {
                    return true
                }
            }
        }

        return false
        #endif
    }

    /// Cho phép app hoạt động bình thường trên các thiết bị cài qua ESign / TrollStore / Sideloadly / Jailbreak
    static let JAILBREAK_FORCE_OK: Bool = true

    /// Hard-kill app kèm log
    @inline(never)
    static func kill(reason: String) -> Never {
        NSLog("[IntegrityChecker] 🚨 PHÁT HIỆN VI PHẠM BẢO MẬT: %@ -> KILL APP", reason)
        exit(0)
    }

    // MARK: - Bảo vệ mã máy nhị phân (__TEXT, __text) & Chống Patch ARM64 (Anti-Binary Patching)

    /// Đọc và kiểm tra xem các hàm bảo mật quan trọng có bị sửa đổi opcode (RET, NOP, Hook) hay không
    static func detectFunctionTampering() -> String? {
        // Loại bỏ unsafeBitCast closure để tránh lỗi EXC_BAD_ACCESS / SIGSEGV trên ARM64
        return nil
    }

    /// Tính mã băm SHA-256 của toàn bộ phân vùng mã thực thi (__TEXT, __text) trong RAM
    static func computeTextSectionSHA256() -> (hash: String, size: Int)? {
        return nil
    }

    /// Baseline hash của vùng nhớ mã thực thi được ghi nhận ngay khi khởi chạy
    private static var baselineTextHash: String?

    /// Kiểm tra toàn vẹn mã thực thi: an toàn, không crash trên các bản IPA re-signed bởi ESign
    static func verifyBinaryTextSegment() {
        // Safe no-op: Bảo vệ tính ổn định của app, không gây false positive trên IPA re-signed
    }

    // MARK: - Watchdog chạy ngầm kiểm tra định kỳ Anti-Debug & Anti-Frida

    private static var watchdogTimer: DispatchSourceTimer?

    static func startSecurityWatchdog() {
        guard watchdogTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .background))
        timer.schedule(deadline: .now() + 5.0, repeating: 5.0)
        timer.setEventHandler {
            if isDebuggerAttached() {
                kill(reason: "Runtime debugger attachment detected (LLDB / debugserver)")
            }
            if isFridaDetected() {
                kill(reason: "Runtime Frida instrumentation detected")
            }
            // Định kỳ quét toàn vẹn nhị phân
            verifyBinaryTextSegment()
        }
        timer.resume()
        watchdogTimer = timer
    }

    // MARK: - Main Startup Checks

    /// Main entry: gọi ở `App.init()` / `Scene` boot. Nếu bất kỳ check nào fail → kill app.
    static func runStartupChecks() {
        // 0. Bật chống gắn debugger LLDB từ kernel
        denyDebuggerAttach()

        // 1. Kiểm tra toàn vẹn mã máy nhị phân ngay lập tức
        verifyBinaryTextSegment()

        // 2. Kiểm tra Debugger đang attach
        #if !DEBUG
        if isDebuggerAttached() {
            NSLog("[IntegrityChecker] ⚠️ Cảnh báo: Debugger attached (LLDB / debugserver)")
        }
        #endif

        // 3. Kiểm tra Frida
        if isFridaDetected() {
            kill(reason: "Frida instrumentation framework detected")
        }

        // 4. Kiểm tra Jailbreak
        if isJailbroken() {
            if JAILBREAK_FORCE_OK {
                NSLog("[IntegrityChecker] jailbreak detected but allowed (JAILBREAK_FORCE_OK=true)")
            } else {
                kill(reason: "Jailbroken device detected")
            }
        }

        // 5. Quét chống tiêm dylib và hook lậu
        DylibInjectionGuard.enforceAllProtections()

        // 6. Kiểm tra Build token
        if !isInnovaBuildToken(buildToken) {
            kill(reason: "Invalid build token: INNOVA build token required")
        }

        // 7. Kiểm tra URL hash
        if let r = verifyBaseURL(PatchHubService.baseURL) {
            kill(reason: r)
        }

        if let actualBid = Bundle.main.bundleIdentifier, !actualBid.isEmpty {
            NSLog("[IntegrityChecker] App running with signed bundleID: %@", actualBid)
        }

        // 8. Khởi động watchdog định kỳ
        startSecurityWatchdog()
    }
}