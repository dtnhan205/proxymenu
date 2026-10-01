import CryptoKit
import Foundation
import UIKit

/// Sinh một serial ổn định cho thiết bị để bind với license key.
/// Kết hợp identifierForVendor + một UUID ng�u nhiên lưu Keychain (reset khi
/// reinstall thì identifierForVendor đổi, UUID Keychain giữ ổn định trong
/// cùng Apple ID — đủ tốt cho mục đích bind license).
enum DeviceIdentity {

    private static let keychainService = "com.threeoneosfive.device.serial"
    private static let keychainAccount = "device-serial-v1"

    /// Serial ngẫu nhiên 32 hex ký tự, tạo 1 lần và lưu Keychain.
    static func serial() -> String {
        if let existing = readFromKeychain() {
            return existing
        }
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let raw: Data
        if status == errSecSuccess {
            raw = Data(bytes)
        } else {
            raw = UUID().uuidString.data(using: .utf8) ?? Data()
        }
        let digest = SHA256.hash(data: raw)
        let hex = digest.map { String(format: "%02x", $0) }.joined().prefix(32)
        let serial = String(hex)
        writeToKeychain(serial)
        return serial
    }

    /// Mã hoá identifierForVendor + model — chỉ dùng cho hiển thị / debug.
    static func displayInfo() -> String {
        let vendor = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        let model = UIDevice.current.model
        let sys = UIDevice.current.systemVersion
        return "\(model) · iOS \(sys) · \(vendor.prefix(8))…"
    }

    // MARK: - Keychain

    private static func readFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let str = String(data: data, encoding: .utf8),
              !str.isEmpty else {
            return nil
        }
        return str
    }

    private static func writeToKeychain(_ value: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: value.data(using: .utf8) ?? Data(),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }
        guard updateStatus == errSecItemNotFound else { return }
        var newItem = query
        attributes.forEach { newItem[$0.key] = $0.value }
        SecItemAdd(newItem as CFDictionary, nil)
    }
}
