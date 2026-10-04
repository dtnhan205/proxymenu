import Foundation
import Security

/// Helper quản lý lưu trữ Key trong iOS Keychain (bền vững nhất, không mất khi kill app hay reinstall)
private enum KeychainHelper {
    private static let service = "com.innova.cheat.license"
    private static let account = "innova_active_key_v1"

    static func saveKey(_ key: String) {
        guard let data = key.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            attributes.forEach { newItem[$0.key] = $0.value }
            SecItemAdd(newItem as CFDictionary, nil)
        }
    }

    static func loadKey() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else {
            return nil
        }
        return key
    }

    static func deleteKey() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Quản lý License Key và trạng thái phiên bản quyền INNOVA.
/// Lưu trữ bền vững 4 tầng: Keychain + UserDefaults + Documents Cache + AppSupport Cache.
/// - Lần đầu nhập đúng: tự động lưu vĩnh viễn vào thiết bị.
/// - Lần sau mở app: tự động kiểm tra key ngầm với server và vào thẳng trang chủ.
/// - Chỉ khi key hết hạn hoặc bị khóa/thu hồi: mới bắt nhập tay lại.
final class LicenseStore: ObservableObject {

    static let shared = LicenseStore()

    @Published private(set) var savedKey: String?
    @Published private(set) var expiresAt: Date?
    @Published private(set) var activatedAt: Date?
    @Published private(set) var durationDays: Int?
    @Published private(set) var durationHours: Int?
    @Published private(set) var buildBlocked: Bool = false

    private let keyDefaultsKey = "license.savedKey"
    private let expiresKey = "license.expiresAt"
    private let activatedKey = "license.activatedAt"
    private let durationKey = "license.durationDays"
    private let durationHoursKey = "license.durationHours"
    private let buildBlockedKey = "license.buildBlocked"

    private static var privateStorageURL: URL? {
        let fm = FileManager.default
        if let cacheDir = fm.urls(for: .cachesDirectory, in: .userDomainMask).first {
            return cacheDir.appendingPathComponent(".innova_license.key")
        }
        return nil
    }

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

    /// Đọc key đã lưu từ Keychain, UserDefaults hoặc file cache cục bộ (Chỉ nhận Key INNOVA)
    static func loadCachedKey() -> String? {
        // 1. Ưu tiên Keychain (bền vững nhất qua mọi lần mở app và reboot)
        if let key = KeychainHelper.loadKey()?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            if isInnovaKey(key) {
                if UserDefaults.standard.string(forKey: "license.savedKey") != key {
                    UserDefaults.standard.set(key, forKey: "license.savedKey")
                    UserDefaults.standard.synchronize()
                }
                return key
            } else {
                removeCachedKey()
            }
        }

        // 2. Đọc từ UserDefaults
        if let key = UserDefaults.standard.string(forKey: "license.savedKey")?
            .trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty {
            if isInnovaKey(key) {
                KeychainHelper.saveKey(key)
                return key
            } else {
                removeCachedKey()
            }
        }

        // 3. Đọc từ Caches private cache
        if let cacheURL = privateStorageURL,
           let data = try? Data(contentsOf: cacheURL), !data.isEmpty {
            let decrypted = decryptDataForDevice(data)
            if let key = String(data: decrypted, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !key.isEmpty, isInnovaKey(key) {
                persistCachedKey(key)
                return key
            }
        }

        // 4. Đọc từ Application Support cache
        if let fileURL = cacheFileURL,
           let data = try? Data(contentsOf: fileURL), !data.isEmpty {
            let decrypted = decryptDataForDevice(data)
            if let key = String(data: decrypted, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !key.isEmpty, isInnovaKey(key) {
                persistCachedKey(key)
                return key
            }
            if let plainKey = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !plainKey.isEmpty, isInnovaKey(plainKey) {
                persistCachedKey(plainKey)
                return plainKey
            }
        }

        return nil
    }

    /// Lưu key bền vững vào cả Keychain, UserDefaults, Documents và file cache cục bộ
    static func persistCachedKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 1. Keychain
        KeychainHelper.saveKey(trimmed)

        // 2. UserDefaults
        UserDefaults.standard.set(trimmed, forKey: "license.savedKey")
        UserDefaults.standard.synchronize()

        // 3. Caches private file cache (không bao giờ lộ trong app Tệp)
        if let cacheURL = privateStorageURL, let raw = trimmed.data(using: .utf8) {
            let encrypted = encryptDataForDevice(raw)
            try? encrypted.write(to: cacheURL, options: .atomic)
        }

        // 4. Application Support file cache
        if let fileURL = cacheFileURL, let raw = trimmed.data(using: .utf8) {
            let encrypted = encryptDataForDevice(raw)
            try? encrypted.write(to: fileURL, options: .atomic)
        }
    }

    /// Xóa toàn bộ key khỏi Keychain, UserDefaults và file cache
    static func removeCachedKey() {
        KeychainHelper.deleteKey()
        UserDefaults.standard.removeObject(forKey: "license.savedKey")
        UserDefaults.standard.synchronize()
        if let fileURL = cacheFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        if let cacheURL = privateStorageURL {
            try? FileManager.default.removeItem(at: cacheURL)
        }
        if let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? FileManager.default.removeItem(at: docsDir.appendingPathComponent(".innova_license.key"))
        }
    }

    private init() {
        self.buildBlocked = UserDefaults.standard.bool(forKey: buildBlockedKey)

        // Khôi phục key từ bộ nhớ bền vững của thiết bị
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

        let resolvedDurationSeconds: Int? = {
            if let m = status.durationMinutes, m > 0 { return Int(m * 60) }
            if let h = status.durationHours, h > 0 { return Int(h * 3_600) }
            if let d = status.durationDays, d > 0 { return Int(d * 86_400) }
            return nil
        }()

        if resolvedExpiresAt == nil, let dur = resolvedDurationSeconds, dur > 0 {
            if status.firstActivation == false, let base = resolvedActivatedAt {
                resolvedExpiresAt = base.addingTimeInterval(TimeInterval(dur))
            } else {
                resolvedExpiresAt = Date().addingTimeInterval(TimeInterval(dur))
            }
        }

        var cachedDurationDays: Int?
        var cachedDurationHours: Int?
        if let secs = resolvedDurationSeconds {
            cachedDurationDays = max(1, Int((Double(secs) / 86_400).rounded(.up)))
            cachedDurationHours = max(1, Int((Double(secs) / 3_600).rounded(.up)))
        }

        NSLog("[LicenseStore] save key=\(key) expiresAtString=\(status.expiresAt ?? "<nil>") resolvedExpiresAt=\(resolvedExpiresAt?.description ?? "<nil>")")

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
        d.synchronize()
        self.savedKey = key
    }

    func setBuildBlocked(_ blocked: Bool) {
        UserDefaults.standard.set(blocked, forKey: buildBlockedKey)
        UserDefaults.standard.synchronize()
        self.buildBlocked = blocked
    }

    func clear() {
        Self.removeCachedKey()
        let d = UserDefaults.standard
        d.removeObject(forKey: expiresKey)
        d.removeObject(forKey: activatedKey)
        d.removeObject(forKey: durationKey)
        d.removeObject(forKey: durationHoursKey)
        d.synchronize()
        self.savedKey = nil
        self.expiresAt = nil
        self.activatedAt = nil
        self.durationDays = nil
        self.durationHours = nil
        FreeFirePatchService.uninject()
    }

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
