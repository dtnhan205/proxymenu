import Foundation
import CryptoKit

/// Tầng bảo vệ chống tamper local. Mục đích: nếu attacker chỉnh sửa
/// binary (đổi bytes array obfuscated, hook `Obfuscated.decode`, đổi
/// URL endpoint, …) thì app tự kill ngay khi khởi động / trước khi gọi
/// API.
///
/// KHÔNG phải crypto thật — chỉ là rào cản static analysis. Attacker
/// runtime hook bypass được, NHƯNG sẽ cần Frida/cycript, không phải
/// "đổi 1 dòng string".
///
/// Kết hợp với server-side `clientIntegrity` check (PatchHubService + server
/// `/api/activate` field `clientIntegrity`) để có 2 lớp: local + remote.
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

    /// Build token plaintext của INNOVA CHEAT. Đổi dòng này khi build IPA mới — admin cũng
    /// add token tương ứng trên `/admin/builds?platform=innova`.
    ///
    /// Khi token này bị admin revoke (hoặc không tồn tại trên server / sai nền tảng) →
    /// mọi thiết bị đang dùng token sẽ bị phủ overlay "Đã có phiên bản mới" full-screen.
    static let buildToken: String = "INNOVA-T7S3465GYWVE3HS2Q45NVGEN"

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

    /// Verify bundle ID khớp expected. Trả về `nil` nếu OK.
    static func verifyBundleID(_ id: String) -> String? {
        if id != expectedBundleID {
            return "bundleID mismatch"
        }
        return nil
    }

    /// Jailbreak heuristic: kiểm tra các đường dẫn tiêu biểu và khả năng
    /// ghi ngoài sandbox. Đây heuristic only — bypass được bằng jailbreak
    /// tweak ẩn, nhưng sẽ chặn 90% cracker casual.
    static func isJailbroken() -> Bool {
        #if targetEnvironment(simulator)
        return false
        #else
        let paths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt",
            "/private/var/lib/apt/"
        ]
        for p in paths {
            if FileManager.default.fileExists(atPath: p) { return true }
        }
        // Thử ghi ra ngoài sandbox. Trên iOS bình thường, /private/.../tmp
        // bị chặn. Trên jailbreak thì ghi được.
        let probe = "/private/jailbreak_probe_\(UUID().uuidString).txt"
        do {
            try "x".write(toFile: probe, atomically: true, encoding: .utf8)
            try? FileManager.default.removeItem(atPath: probe)
            return true
        } catch {
            return false
        }
        #endif
    }

    /// Hard-kill app kèm log. Dùng `__PKIX` exit (SwiftUI crash) hoặc
    /// `exit(0)` nếu muốn silent. Ở đây dùng `exit(0)` cho UX sạch.
    /// Lý do: bảo vệ IP, không cần hiện dialog.
    @inline(never)
    static func kill(reason: String) -> Never {
        NSLog("[IntegrityChecker] KILL: \(reason)")
        // Hard exit. Không chạy code sau.
        exit(0)
    }

    /// Main entry: gọi ở `App.init()` / `Scene` boot. Nếu bất kỳ check
    /// nào fail → kill app.
    ///
    /// iPhone 8 Plus / iOS 15.x user hầu hết phải jailbreak để cài được app
    /// patch. Vì vậy jailbreak check được TẮT hoàn toàn (không kill) — chỉ
    /// log NSLog để admin biết thiết bị có jailbreak. Các check tamper khác
    /// (baseURL integrity, bundle ID) vẫn hoạt động bình thường.
    ///
    /// Nếu trong tương lai muốn bật lại jailbreak check, sửa `JAILBREAK_FORCE_OK`
    /// từ `true` → `false`.
    static let JAILBREAK_FORCE_OK: Bool = true

    static func runStartupChecks() {
        if !isInnovaBuildToken(buildToken) {
            kill(reason: "Invalid build token: INNOVA build token required")
        }
        if let r = verifyBaseURL(PatchHubService.baseURL) {
            kill(reason: r)
        }
        if let r = verifyBundleID(Bundle.main.bundleIdentifier ?? "") {
            kill(reason: r)
        }
        if isJailbroken() {
            if JAILBREAK_FORCE_OK {
                // Cho phép chạy tiếp, chỉ ghi log để admin tracking.
                NSLog("[IntegrityChecker] jailbreak detected but allowed (JAILBREAK_FORCE_OK=true)")
            } else {
                kill(reason: "jailbroken device")
            }
        }
    }
}