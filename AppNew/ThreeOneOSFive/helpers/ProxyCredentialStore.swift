import Foundation
import Security

// MARK: - ProxyCredentialStore
//
// Mật khẩu proxy chỉ nằm trong Keychain, không nằm trong JSON cấu hình,
// không nằm trong UserDefaults và không hardcode trong source.
//
// Mỗi bản ghi gắn với `ProxyConfiguration.id` qua `kSecAttrAccount`.
// `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` để không đồng bộ lên iCloud
// và không rời khỏi thiết bị.

enum ProxyCredentialStore {

    private static let service = "com.innova.cheat.proxy.credential"

    private static func baseQuery(for id: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString
        ]
    }

    /// Lưu (hoặc cập nhật) mật khẩu cho một cấu hình.
    @discardableResult
    static func save(password: String, for id: UUID) -> Bool {
        guard !password.isEmpty else { return delete(for: id) }

        guard let data = password.data(using: .utf8) else { return false }

        let query = baseQuery(for: id)
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }

        if updateStatus == errSecItemNotFound {
            var newItem = query
            attributes.forEach { newItem[$0.key] = $0.value }
            return SecItemAdd(newItem as CFDictionary, nil) == errSecSuccess
        }

        return false
    }

    /// Đọc mật khẩu đã lưu, `nil` nếu chưa có.
    static func load(for id: UUID) -> String? {
        var query = baseQuery(for: id)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let password = String(data: data, encoding: .utf8),
              !password.isEmpty else {
            return nil
        }
        return password
    }

    static func hasCredential(for id: UUID) -> Bool {
        load(for: id) != nil
    }

    /// Xoá mật khẩu của một cấu hình. Trả `true` cả khi không tồn tại.
    @discardableResult
    static func delete(for id: UUID) -> Bool {
        let status = SecItemDelete(baseQuery(for: id) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}