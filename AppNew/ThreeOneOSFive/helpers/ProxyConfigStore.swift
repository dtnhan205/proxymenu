import Combine
import Foundation

// MARK: - ProxyConfigStore
//
// Lưu danh sách cấu hình proxy xuống Application Support dưới dạng JSON.
// CHỈ lưu dữ liệu không bí mật (host, port, protocol, username).
// Mật khẩu do `ProxyCredentialStore` giữ trong Keychain.

final class ProxyConfigStore: ObservableObject {

    static let shared = ProxyConfigStore()

    @Published private(set) var configurations: [ProxyConfiguration] = []
    @Published private(set) var selectedID: UUID?

    /// Bản sao mật khẩu trong RAM cho phiên hiện tại.
    ///
    /// Keychain có thể trả `errSecMissingEntitlement` (-34018) trên build không
    /// ký hoặc thiếu keychain-access-group. Khi đó mật khẩu vẫn dùng được trong
    /// phiên hiện tại nhưng KHÔNG được ghi xuống đĩa.
    private var memoryPasswords: [UUID: String] = [:]

    private let fileManager = FileManager.default
    private let selectedIDKey = "proxy.client.selectedID"
    private let ioQueue = DispatchQueue(label: "com.innova.cheat.proxy.configstore", qos: .utility)

    private var fileURL: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        let dir = base.appendingPathComponent("ProxyClient", isDirectory: true)
        if !fileManager.fileExists(atPath: dir.path) {
            try? fileManager.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("configurations.json")
    }

    private init() {
        load()
        restoreSelection()
    }

    // MARK: - Đọc / ghi

    private func load() {
        guard let data = try? Data(contentsOf: fileURL), !data.isEmpty else {
            configurations = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        do {
            configurations = try decoder.decode([ProxyConfiguration].self, from: data)
        } catch {
            // File hỏng: không xoá dữ liệu ngay, chỉ ghi log và bắt đầu rỗng.
            NSLog("[ProxyConfigStore] Không đọc được cấu hình: \(error.localizedDescription)")
            configurations = []
        }
    }

    private func persist() {
        let snapshot = configurations
        let url = fileURL
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        ioQueue.async {
            do {
                let data = try encoder.encode(snapshot)
                try data.write(to: url, options: .atomic)
            } catch {
                NSLog("[ProxyConfigStore] Không ghi được cấu hình: \(error.localizedDescription)")
            }
        }
    }

    private func restoreSelection() {
        if let raw = UserDefaults.standard.string(forKey: selectedIDKey),
           let id = UUID(uuidString: raw),
           configurations.contains(where: { $0.id == id }) {
            selectedID = id
        } else {
            selectedID = configurations.first?.id
        }
    }

    // MARK: - Truy vấn

    func config(for id: UUID?) -> ProxyConfiguration? {
        guard let id else { return nil }
        return configurations.first { $0.id == id }
    }

    var selectedConfiguration: ProxyConfiguration? {
        config(for: selectedID)
    }

    func password(for id: UUID) -> String? {
        if let cached = memoryPasswords[id], !cached.isEmpty {
            return cached
        }
        return ProxyCredentialStore.load(for: id)
    }

    // MARK: - Thao tác

    @discardableResult
    func add(
        name: String = "",
        host: String = "",
        port: Int = 8080,
        proto: ProxyProtocol = .http
    ) -> ProxyConfiguration {
        var config = ProxyConfiguration(name: name, host: host, port: port, proto: proto)
        config.normalize()
        configurations.append(config)
        selectedID = config.id
        persistSelection()
        persist()
        return config
    }

    /// Cập nhật cấu hình và (tuỳ chọn) mật khẩu. Được gọi tự động mỗi khi
    /// người dùng sửa field trong form → "tự động lưu sau khi nhập".
    func update(_ config: ProxyConfiguration, password: String?) {
        var normalized = config
        normalized.normalize()

        if let index = configurations.firstIndex(where: { $0.id == normalized.id }) {
            configurations[index] = normalized
        } else {
            configurations.append(normalized)
        }

        if let password {
            if password.isEmpty {
                memoryPasswords.removeValue(forKey: normalized.id)
                ProxyCredentialStore.delete(for: normalized.id)
            } else {
                memoryPasswords[normalized.id] = password
                ProxyCredentialStore.save(password: password, for: normalized.id)
            }
        }

        if selectedID == nil { selectedID = normalized.id }
        persist()
    }

    func delete(_ id: UUID) {
        configurations.removeAll { $0.id == id }
        memoryPasswords.removeValue(forKey: id)
        ProxyCredentialStore.delete(for: id)
        if selectedID == id {
            selectedID = configurations.first?.id
            persistSelection()
        }
        persist()
    }

    func select(_ id: UUID?) {
        selectedID = id
        persistSelection()
    }

    private func persistSelection() {
        if let selectedID {
            UserDefaults.standard.set(selectedID.uuidString, forKey: selectedIDKey)
        } else {
            UserDefaults.standard.removeObject(forKey: selectedIDKey)
        }
    }
}