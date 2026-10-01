import Foundation

/// Wrapper tương thích với code cũ trong GamePatchesView. Lưu trữ thật sự
/// được delegate sang `LicenseStore` (cùng UserDefaults keys).
enum LicenseKeyManager {

    static var savedKey: String? { LicenseStore.shared.savedKey }

    static var isSavedKeyValidNow: Bool {
        guard let exp = LicenseStore.shared.expiresAt else { return false }
        return exp > Date()
    }

    /// Khi `true` → RootView phủ overlay full-screen, không cho tương tác.
    static var isBuildBlocked: Bool { LicenseStore.shared.buildBlocked }

    static func verifySavedKey() async throws -> RemoteKeyStatus {
        guard let key = LicenseStore.shared.savedKey, !key.isEmpty else {
            throw LicenseKeyError.missingKey
        }
        let serial = DeviceIdentity.serial()
        return try await PatchHubService.verifyKey(key: key, deviceSerial: serial)
    }

    /// Được gọi khi user bấm "Logout key" / xoá key.
    static func clearSavedKey() {
        LicenseStore.shared.clear()
    }
}
