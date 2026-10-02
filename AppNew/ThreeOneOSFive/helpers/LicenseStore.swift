import Foundation

/// Lưu key + thông tin phiên đăng nhập vào UserDefaults. Chỉ lưu local — việc
/// xác thực thật sự vẫn phải qua server mỗi lần mở app.
final class LicenseStore: ObservableObject {

    static let shared = LicenseStore()

    @Published private(set) var savedKey: String?
    @Published private(set) var expiresAt: Date?
    @Published private(set) var activatedAt: Date?
    @Published private(set) var durationDays: Int?
    /// Tổng thời lượng key tính theo GIỜ, làm tròn LÊN. key 1h → 1; key 30 phút
    /// → 1; key 7d → 168. Footer / summary dùng để render "X giờ" cho key ngắn.
    @Published private(set) var durationHours: Int?
    /// Khi `true` → overlay "Đã có phiên bản mới..." phủ full-screen và
    /// block toàn bộ tương tác. Persist qua UserDefaults nên thoát ra vào
    /// lại vẫn thấy. Chỉ xoá khi verify/activate thành công trở lại.
    @Published private(set) var buildBlocked: Bool = false

    private let keyDefaultsKey = "license.savedKey"
    private let expiresKey = "license.expiresAt"
    private let activatedKey = "license.activatedAt"
    private let durationKey = "license.durationDays"
    private let durationHoursKey = "license.durationHours"
    private let buildBlockedKey = "license.buildBlocked"

    private static var cacheFileURL: URL? {
        let fm = FileManager.default
        if let libraryDir = fm.urls(for: .libraryDirectory, in: .userDomainMask).first {
            let appSupport = libraryDir.appendingPathComponent("Application Support", isDirectory: true)
            if !fm.fileExists(atPath: appSupport.path) {
                try? fm.createDirectory(at: appSupport, withIntermediateDirectories: true)
            }
            return appSupport.appendingPathComponent(".license_key.cache")
        }
        return nil
    }

    private static func encryptDataForDevice(_ data: Data) -> Data {
        let keyString = DeviceIdentity.serial() + "_INNOVA_CACHE_GUARD_V1"
        guard let keyBytes = keyString.data(using: .utf8), !keyBytes.isEmpty else { return data }
        var out = [UInt8](data)
        for i in 0..<out.count {
            out[i] ^= keyBytes[i % keyBytes.count]
        }
        return Data(out)
    }

    private static func decryptDataForDevice(_ data: Data) -> Data {
        encryptDataForDevice(data)
    }

    /// Kiểm tra định dạng key có phải là Key INNOVA hay không (bắt đầu bằng INNOVA-)
    static func isInnovaKey(_ raw: String) -> Bool {
        let upper = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return upper.hasPrefix("INNOVA-")
    }

    /// Đọc key đã lưu từ UserDefaults hoặc file cache cục bộ trong app IPA (Chỉ chấp nhận Key INNOVA)
    static func loadCachedKey() -> String? {
        // 1. Đọc từ UserDefaults
        if let key = UserDefaults.standard.string(forKey: "license.savedKey")?
            .trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            if isInnovaKey(key) {
                return key
            } else {
                removeCachedKey()
                return nil
            }
        }
        // 2. Đọc từ file cache cục bộ (được mã hóa gắn liền với phần cứng thiết bị)
        if let fileURL = cacheFileURL,
           let data = try? Data(contentsOf: fileURL), !data.isEmpty {
            let decrypted = decryptDataForDevice(data)
            if let key = String(data: decrypted, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !key.isEmpty {
                if isInnovaKey(key) {
                    UserDefaults.standard.set(key, forKey: "license.savedKey")
                    return key
                } else {
                    removeCachedKey()
                    return nil
                }
            }
            // Fallback phòng khi cache là dạng plaintext cũ từ bản trước
            if let plainKey = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !plainKey.isEmpty {
                if isInnovaKey(plainKey) {
                    persistCachedKey(plainKey)
                    return plainKey
                } else {
                    removeCachedKey()
                    return nil
                }
            }
        }
        return nil
    }

    /// Lưu key bền vững vào cả UserDefaults và file cache cục bộ (mã hóa theo hardware)
    static func persistCachedKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "license.savedKey")
        if let fileURL = cacheFileURL, let raw = key.data(using: .utf8) {
            let encrypted = encryptDataForDevice(raw)
            try? encrypted.write(to: fileURL, options: .atomic)
        }
    }

    /// Xóa toàn bộ key khỏi UserDefaults và file cache
    static func removeCachedKey() {
        UserDefaults.standard.removeObject(forKey: "license.savedKey")
        if let fileURL = cacheFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
    }

    private init() {
        self.buildBlocked = UserDefaults.standard.bool(forKey: buildBlockedKey)

        // Khôi phục key từ cache của app để mỗi lần vào app có thể tự động xác thực
        self.savedKey = Self.loadCachedKey()

        if let stored = UserDefaults.standard.object(forKey: expiresKey) as? Double {
            self.expiresAt = Date(timeIntervalSince1970: stored)
        } else {
            self.expiresAt = nil
        }
        if let stored = UserDefaults.standard.object(forKey: activatedKey) as? Double {
            self.activatedAt = Date(timeIntervalSince1970: stored)
        } else {
            self.activatedAt = nil
        }
        // Đọc duration từ cache để init() biết key ngắn hạn để render summary
        // "X giờ" chính xác ngay từ trước khi verifyKey chạy.
        let d = UserDefaults.standard
        if let stored = d.object(forKey: durationKey) as? Int {
            self.durationDays = stored
        }
        if let stored = d.object(forKey: durationHoursKey) as? Int {
            self.durationHours = stored
        }
    }

    var isSaved: Bool { (savedKey?.isEmpty == false) }

    /// Đọc các trường thời gian từ UserDefaults vào RAM mà KHÔNG gọi server.
    /// Dùng sau khi verifyKey OK để footer vẫn đếm ngược đúng thời gian thực
    /// còn lại của key (server không cần trả expiresAt trong verify).
    func restoreSession() {
        let d = UserDefaults.standard
        if let stored = d.object(forKey: expiresKey) as? Double {
            self.expiresAt = Date(timeIntervalSince1970: stored)
        }
        if let stored = d.object(forKey: activatedKey) as? Double {
            self.activatedAt = Date(timeIntervalSince1970: stored)
        }
        if let stored = d.object(forKey: durationKey) as? Int {
            self.durationDays = stored
        }
        if let stored = d.object(forKey: durationHoursKey) as? Int {
            self.durationHours = stored
        }
    }

    func save(key: String, status: RemoteKeyStatus) {
        Self.persistCachedKey(key)
        let d = UserDefaults.standard
        var resolvedExpiresAt: Date?
        if let s = status.expiresAt, let date = Self.parseISO8601(s) {
            resolvedExpiresAt = date
        }
        var resolvedActivatedAt: Date?
        if let s = status.activatedAt, let date = Self.parseISO8601(s) {
            resolvedActivatedAt = date
        }
        // Resolve tổng duration về GIÂY. Ưu tiên durationMinutes > durationHours >
        // durationDays — cho phép server trả bất kỳ đơn vị nào tuỳ key length.
        // Server giờ trả `Double?` (làm tròn về integer cho key >= 1 ngày, giữ
        // float cho key lẻ — vd 36h → 1.5 ngày). Dùng Double arithmetic để
        // không mất precision trước khi convert về Int giây.
        let resolvedDurationSeconds: Int? = {
            if let m = status.durationMinutes, m > 0 { return Int(m * 60) }
            if let h = status.durationHours, h > 0 { return Int(h * 3_600) }
            if let d = status.durationDays, d > 0 { return Int(d * 86_400) }
            return nil
        }()
        // Tính expiresAt khi server không trả: dùng activatedAt + durationSeconds
        // cho re-bind (giữ đúng thời gian còn lại thực), hoặc Date() + duration
        // cho first-time bind / legacy server.
        if resolvedExpiresAt == nil, let dur = resolvedDurationSeconds, dur > 0 {
            if status.firstActivation == false, let base = resolvedActivatedAt {
                resolvedExpiresAt = base.addingTimeInterval(TimeInterval(dur))
            } else {
                resolvedExpiresAt = Date().addingTimeInterval(TimeInterval(dur))
            }
        }
        // Cache "ngày / giờ" cho Footer cũ render tương thích. durationDays giờ
        // là ceil(seconds / 86_400) — key 1h hiển thị durationDays = 1 nhưng
        // activationSummaryText sẽ tự chọn "X giờ" vì durationHours = 1.
        var cachedDurationDays: Int?
        var cachedDurationHours: Int?
        if let secs = resolvedDurationSeconds {
            cachedDurationDays = max(1, Int((Double(secs) / 86_400).rounded(.up)))
            cachedDurationHours = max(1, Int((Double(secs) / 3_600).rounded(.up)))
        }
        NSLog("[LicenseStore] save key=\(key) expiresAtString=\(status.expiresAt ?? "<nil>") activatedAtString=\(status.activatedAt ?? "<nil>") durationDays=\(status.durationDays ?? -1) durationHours=\(status.durationHours ?? -1) durationMinutes=\(status.durationMinutes ?? -1) resolvedDurationSeconds=\(resolvedDurationSeconds ?? -1) resolvedExpiresAt=\(resolvedExpiresAt?.description ?? "<nil>") now=\(Date().description)")
        if let exp = resolvedExpiresAt {
            let secs = Int(exp.timeIntervalSinceNow)
            NSLog("[LicenseStore] countdown remaining=\(secs)s (\(secs/3600)h\( (secs%3600)/60 )m\(secs%60)s) expLocal=\(exp.description)")
        }
        // Ưu tiên server response làm mốc duy nhất. Local cache chỉ dùng ở
        // `init()` để hiển thị countdown trong lúc chờ auth — không được override
        // response mới từ server, vì server nắm quyền quyết định thời hạn thực.
        let finalExpiresAt: Date? = resolvedExpiresAt
        if let date = finalExpiresAt {
            d.set(date.timeIntervalSince1970, forKey: expiresKey)
            self.expiresAt = date
        }
        if let date = resolvedActivatedAt {
            d.set(date.timeIntervalSince1970, forKey: activatedKey)
            self.activatedAt = date
        }
        if let days = cachedDurationDays {
            d.set(days, forKey: durationKey)
            self.durationDays = days
        }
        if let hours = cachedDurationHours {
            d.set(hours, forKey: durationHoursKey)
            self.durationHours = hours
        }
        self.savedKey = key
    }

    /// Persist cờ build-blocked lên UserDefaults. Khi server trả
    /// `build_revoked` / `build_unknown` → gọi hàm này với `true` → overlay
    /// sẽ phủ full-screen ngay khi RootView render.
    func setBuildBlocked(_ blocked: Bool) {
        UserDefaults.standard.set(blocked, forKey: buildBlockedKey)
        self.buildBlocked = blocked
    }

    func clear() {
        Self.removeCachedKey()
        let d = UserDefaults.standard
        d.removeObject(forKey: expiresKey)
        d.removeObject(forKey: activatedKey)
        d.removeObject(forKey: durationKey)
        d.removeObject(forKey: durationHoursKey)
        self.savedKey = nil
        self.expiresAt = nil
        self.activatedAt = nil
        self.durationDays = nil
        self.durationHours = nil
    }

    /// Parse ISO8601 — chấp nhận cả `Z` và `+07:00`; thử cả có/không fractional
    /// seconds. Trả về UTC an toàn để cộng `durationDays` không lệch.
    private static func parseISO8601(_ s: String) -> Date? {
        let withInternet = ISO8601DateFormatter()
        withInternet.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withInternet.date(from: s) { return date }
        let standard = ISO8601DateFormatter()
        standard.formatOptions = [.withInternetDateTime]
        if let date = standard.date(from: s) { return date }
        return nil
    }
}
