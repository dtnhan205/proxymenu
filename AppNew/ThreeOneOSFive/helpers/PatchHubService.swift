import CryptoKit
import Foundation

struct RemotePatchSummary: Decodable, Identifiable, Equatable {
    let id: String
    let name: String
    let description: String
    let version: String
    let fileName: String
    let sizeBytes: Int64
    let sha256: String
    let createdAt: String
    let gameId: String?
}

struct RemoteGameSummary: Decodable, Identifiable, Equatable, Hashable {
    let id: String
    let name: String
    let bundleID: String
    let bannerColor: String
    let iconPath: String?
    let createdAt: String

    var iconURL: URL? {
        guard let iconPath else { return nil }
        return PatchHubService.baseURL.appendingPathComponent(String(iconPath.dropFirst()))
    }
}

/// Server response for POST /api/activate and POST /api/keys/verify.

struct RemoteGameSessionToken: Decodable, Equatable {
    let ok: Bool
    let reason: String?
    let token: String?
    let key: String?
    let hwid: String?
    let timestamp: Int?
    let signature: String?
    let tokenSeed: Int?
    let expiresAt: String?
}

struct RemoteInnovaPayloadResponse: Decodable, Equatable {
    let ok: Bool
    let sha256: String?
    let payloadBase64: String?
    let payloadSize: Int?
    let tokenBase64: String?
    let configRaw: String?
    let timestamp: Int?
    let reason: String?
    let message: String?
}

struct RemoteInnovaTokenResponse: Decodable, Equatable {
    let ok: Bool
    let tokenBase64: String?
    let exp: Int?
    let timestamp: Int?
    let reason: String?
    let message: String?
}

struct RemoteKeyStatus: Decodable, Equatable {
    let ok: Bool
    let reason: String?
    let expiresAt: String?
    let activatedAt: String?
    /// Tổng thời lượng key tính theo NGÀY. Server hiện trả về integer
    /// (làm tròn từ `durationMs`). `Double?` chứ không phải `Int?` để
    /// forward-compatible nếu admin muốn trả float (vd key 36 giờ → 1.5).
    /// Caller chỉ dùng để so sánh `> 0` và cache giá trị dạng Int.
    let durationDays: Double?
    /// Optional: tổng thời lượng key tính theo GIỜ. Server nên trả cho key
    /// ngắn hạn (1h, 2h, 6h, 12h). Khi present, client ưu tiên dùng thay cho
    /// `durationDays` để countdown hiển thị chính xác "X giờ Y phút".
    let durationHours: Double?
    /// Optional: tổng thời lượng key tính theo PHÚT. Dùng cho key rất ngắn
    /// (< 1h) — server có thể trả `durationMinutes: 30` chẳng hạn.
    let durationMinutes: Double?
    let remainingSlots: Int?
    let firstActivation: Bool?
    let alreadyBound: Bool?
    let maxDevices: Int?
}

/// User-friendly failure reasons for key verification / activation. Maps to
/// Vietnamese messages surfaced to the user from the toggle flow.
enum LicenseKeyError: Error, LocalizedError {
    case invalidResponse
    case keyNotFound
    case revoked
    case expired
    case notActivated
    case deviceLimitReached(maxDevices: Int?)
    case deviceNotBound
    case internalError
    case missingKey
    case buildMissing
    case buildRevoked
    case buildUnknown
    case buildWrongPlatform
    case innovaKeyRequired
    case proxyKeyNotAllowed(type: String)
    case hwidBanned

    /// DEBUG: lưu chi tiết lỗi mới nhất để hiển thị trên UI khi gặp
    /// invalidResponse. Tạm thời — sẽ xoá sau khi debug xong.
    static var lastDebugDetail: String = ""

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            // DEBUG MODE: append chi tiết lỗi để user chụp ảnh gửi.
            if !Self.lastDebugDetail.isEmpty {
                return "Phản hồi từ máy chủ không hợp lệ\n\n[DEBUG]\n\(Self.lastDebugDetail)"
            }
            return "Phản hồi từ máy chủ không hợp lệ"
        case .keyNotFound: return "Key không tồn tại. Vui lòng kiểm tra lại"
        case .revoked: return "Key đã bị khoá. Vui lòng liên hệ admin"
        case .hwidBanned: return "Thiết bị này đã bị CẤM VĨNH VIỄN do vi phạm bảo mật / can thiệp bẻ khóa!"
        case .expired: return "Key đã hết hạn. Vui lòng gia hạn"
        case .notActivated: return "Key chưa được kích hoạt"
        case .deviceLimitReached(let n): return n == nil
            ? "Key đã đạt giới hạn thiết bị"
            : "Key đã đạt giới hạn \(n!) thiết bị"
        case .deviceNotBound: return "Thiết bị chưa được bind với key. Vui lòng nhập lại key"
        case .internalError: return "Lỗi máy chủ. Vui lòng thử lại sau"
        case .missingKey: return "Chưa nhập key"
        case .buildMissing, .buildRevoked, .buildUnknown, .buildWrongPlatform:
            return "ĐÃ UPDATE PHIÊN BẢN MỚI\nVUI LÒNG XÓA BẢN HIỆN TẠI\nTRUY CẬP TRANG WEB BÊN DƯỚI ĐỂ CÀI BẢN MỚI"
        case .innovaKeyRequired:
            return "Ứng dụng chỉ chấp nhận Key INNOVA!\n(Định dạng: INNOVA-1D-XXXX-XXXX)"
        case .proxyKeyNotAllowed(let type):
            return "Key bạn nhập là Key \(type)!\nỨng dụng này chỉ chấp nhận Key INNOVA."
        }
    }
}

struct RemoteDnsAntibanInfo: Decodable, Equatable {
    let available: Bool
    let fileName: String?
    let sizeBytes: Int64?
    let uploadedAt: String?

    var formattedSize: String {
        guard let sizeBytes, sizeBytes > 0 else { return "—" }
        return ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

struct RemoteTutorialVideoInfo: Decodable, Equatable {
    let available: Bool
    let type: String?
    let videoUrl: String?
    let title: String?
    let fileName: String?
    let sizeBytes: Int64?
    let mimeType: String?
    let uploadedAt: String?
    let updatedAt: String?

    var displayTitle: String {
        if let title, !title.isEmpty { return title }
        return "Video Hướng Dẫn Sử Dụng"
    }

    func displayTitle(language: AppLanguage) -> String {
        if let title, !title.isEmpty { return title }
        return language.text("home.tutorial.modal_title")
    }

    var formattedSize: String? {
        guard let sizeBytes, sizeBytes > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }

    /// URL đầy đủ để phát video MP4 (hỗ trợ cả link ngoài CDN/Drive và route local từ server)
    var resolvedURL: URL? {
        guard available else { return nil }
        if let raw = videoUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            if raw.hasPrefix("http://") || raw.hasPrefix("https://") {
                return URL(string: raw)
            }
            let clean = raw.hasPrefix("/") ? String(raw.dropFirst()) : raw
            return PatchHubService.baseURL.appendingPathComponent(clean)
        }
        return PatchHubService.defaultTutorialVideoURL
    }
}

enum ClientFeedbackStatus: String {
    case safe = "safe"
    case banned3d = "banned_3d"
    case banned7d = "banned_7d"
    case bannedPerm = "banned_perm"

    var displayText: String {
        switch self {
        case .safe: return "An Toàn"
        case .banned3d: return "Bị Ban 3 Ngày"
        case .banned7d: return "Bị Ban 7 Ngày"
        case .bannedPerm: return "Bị Ban Vĩnh Viễn"
        }
    }

    func displayText(language: AppLanguage) -> String {
        switch self {
        case .safe: return language.text("home.feedback.still_safe")
        case .banned3d: return language.text("home.feedback.banned_3d")
        case .banned7d: return language.text("home.feedback.banned_7d")
        case .bannedPerm: return language.text("home.feedback.banned_perm")
        }
    }
}

struct ClientFeedbackResponse: Decodable, Equatable {
    let ok: Bool
    let message: String?
    let reportId: String?
}

enum ClientFeedbackLimitManager {
    private static let storageKey = "client_feedback_submission_records"
    static let maxDailySubmissions = 2

    struct SubmissionRecord: Codable {
        let timestamp: TimeInterval
        let key: String
        let deviceId: String
    }

    private static func loadRecords() -> [SubmissionRecord] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let records = try? JSONDecoder().decode([SubmissionRecord].self, from: data) else {
            return []
        }
        return records
    }

    private static func saveRecords(_ records: [SubmissionRecord]) {
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    /// Lọc các lượt gửi trong ngày hôm nay (theo Calendar hiện tại) của máy và key này
    private static func todayRecords(
        key: String? = nil,
        deviceId: String? = nil
    ) -> [SubmissionRecord] {
        let currentKey = (key ?? LicenseStore.shared.savedKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let currentDevice = (deviceId ?? DeviceIdentity.serial()).trimmingCharacters(in: .whitespacesAndNewlines)
        let calendar = Calendar.current
        let all = loadRecords()

        return all.filter { record in
            let date = Date(timeIntervalSince1970: record.timestamp)
            guard calendar.isDateInToday(date) else { return false }

            let matchDevice = !currentDevice.isEmpty && record.deviceId == currentDevice
            let matchKey = !currentKey.isEmpty && record.key == currentKey
            return matchDevice || matchKey
        }
    }

    /// Số lần đã gửi trong ngày hôm nay
    static func todaySubmissionCount(
        key: String? = nil,
        deviceId: String? = nil
    ) -> Int {
        return todayRecords(key: key, deviceId: deviceId).count
    }

    /// Số lần còn lại có thể gửi trong ngày hôm nay (tối đa 2 lần/ngày)
    static func remainingSubmissionsToday(
        key: String? = nil,
        deviceId: String? = nil
    ) -> Int {
        let count = todaySubmissionCount(key: key, deviceId: deviceId)
        return max(0, maxDailySubmissions - count)
    }

    /// Kiểm tra xem còn được phép gửi phản hồi hay không (< 2 lần/ngày)
    static func canSubmit(
        key: String? = nil,
        deviceId: String? = nil
    ) -> Bool {
        return todaySubmissionCount(key: key, deviceId: deviceId) < maxDailySubmissions
    }

    /// Ghi nhận 1 lượt gửi thành công
    static func recordSubmission(
        key: String? = nil,
        deviceId: String? = nil
    ) {
        var records = loadRecords()
        let sevenDaysAgo = Date().addingTimeInterval(-7 * 86400).timeIntervalSince1970
        records.removeAll { $0.timestamp < sevenDaysAgo }

        let currentKey = (key ?? LicenseStore.shared.savedKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let currentDevice = (deviceId ?? DeviceIdentity.serial()).trimmingCharacters(in: .whitespacesAndNewlines)

        let newRecord = SubmissionRecord(
            timestamp: Date().timeIntervalSince1970,
            key: currentKey,
            deviceId: currentDevice
        )
        records.append(newRecord)
        saveRecords(records)
    }
}

struct RemoteAnnouncementInfo: Decodable, Equatable, Identifiable {
    let id: String
    let title: String
    let content: String
    let type: String?
    let link: String?
    let isPopup: Bool?
    let enabled: Bool?
    let createdAt: String?
}

enum AnnouncementSnoozeManager {
    private static let snoozeUntilKey = "announcement_snooze_until_timestamp"
    private static let lastSnoozedIdKey = "announcement_last_snoozed_id"
    private static var lastBackgroundTime: Date? = nil

    /// Cờ in-memory: Đã hiển thị hoặc đã đóng popup trong phiên mở app hiện tại.
    /// Khởi tạo lại là false khi app cold-start (thoát app vào lại).
    private(set) static var hasShownInSession: Bool = false

    /// Kiểm tra xem người dùng có đang trong thời gian hoãn 2 giờ hay không.
    static func isSnoozed() -> Bool {
        let until = UserDefaults.standard.double(forKey: snoozeUntilKey)
        guard until > 0 else { return false }
        let now = Date().timeIntervalSince1970
        return now < until
    }

    /// Hoãn hiển thị thông báo trong 2 giờ (khi bấm nút "Đóng 2 Giờ").
    static func snoozeTwoHours(for id: String? = nil) {
        let twoHoursLater = Date().addingTimeInterval(2 * 3600).timeIntervalSince1970
        UserDefaults.standard.set(twoHoursLater, forKey: snoozeUntilKey)
        if let id {
            UserDefaults.standard.set(id, forKey: lastSnoozedIdKey)
        }
        hasShownInSession = true
    }

    /// Đánh dấu là đã hiển thị hoặc người dùng bấm Đóng trong phiên mở app này,
    /// ngăn việc popup liên tục hiện mỗi khi quay lại trang Home.
    static func markDismissedOrShown() {
        hasShownInSession = true
    }

    /// Ghi nhận thời điểm app chuyển sang trạng thái background.
    static func recordBackground() {
        lastBackgroundTime = Date()
    }

    /// Khi app quay lại từ background, nếu đã ra ngoài trên 5 phút thì xem như phiên mới.
    static func checkForegroundResume() {
        if let bgTime = lastBackgroundTime, Date().timeIntervalSince(bgTime) >= 300 {
            hasShownInSession = false
        }
        lastBackgroundTime = nil
    }

    /// Kiểm tra xem popup có được phép hiển thị hay không:
    /// - Không hiện nếu đang trong thời gian hoãn 2 giờ (isSnoozed).
    /// - Tự động xóa mốc hoãn khi đã qua 2 giờ để cho phép hiện lại.
    /// - Chỉ hiển thị 1 lần trong phiên mở app hiện tại (tránh việc cứ ra trang Home là hiện).
    static func shouldShowAnnouncement() -> Bool {
        let until = UserDefaults.standard.double(forKey: snoozeUntilKey)
        let now = Date().timeIntervalSince1970

        if until > 0 {
            if now < until {
                // Vẫn đang trong thời gian hoãn 2 giờ
                return false
            } else {
                // Đã hết 2 giờ hoãn -> xóa cờ snooze và cho phép hiển thị lại
                UserDefaults.standard.removeObject(forKey: snoozeUntilKey)
                hasShownInSession = false
            }
        }

        // Trong cùng một phiên chạy app, chỉ hiển thị 1 lần khi vào app
        if hasShownInSession {
            return false
        }

        return true
    }
}

enum PatchHubError: Error, LocalizedError {
    case invalidResponse
    case checksumMismatch
    case fileUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidResponse: return "Phản hồi từ máy chủ không hợp lệ"
        case .checksumMismatch: return "Tệp tải về bị lỗi kiểm tra toàn vẹn"
        case .fileUnavailable: return "Máy chủ chưa có tệp DNS Antiban"
        }
    }
}

enum PatchHubService {
    // MARK: - Obfuscated constants
    // baseURL được mã hóa XOR với key để tránh lộ server khi `strings` trên IPA.
    // KHÔNG phải crypto thật — chỉ là rào cản static analysis. Key XOR đặt ngay
    // trong source cố ý; mục tiêu là KHÔNG xuất hiện plaintext URL trong binary.
    private static let baseURLBytes: [UInt8] = [
        0xCF, 0x2F, 0x4A, 0xE1, 0xBF, 0x75, 0x3D, 0xA7,
        0xA0, 0x62, 0x2E, 0x92, 0xFE, 0x44, 0x18, 0xB8,
        0x4B, 0xDB, 0x18, 0xC6, 0x72, 0xFA, 0x3E, 0x9F,
        0x33, 0x7C, 0xB1, 0x50, 0x02, 0xA8, 0xD1, 0xE3
    ]
    private static let baseURLKey: [UInt8] = [
        0xA7, 0x5B, 0x3E, 0x91, 0xCC, 0x4F, 0x12, 0x88,
        0xD3, 0x07, 0x5C, 0xE4, 0x9B, 0x36, 0x71, 0xC8,
        0x2A, 0xF5, 0x68, 0xB4, 0x1D, 0x82, 0x47, 0xE9,
        0x5A, 0x0C, 0x9F, 0x33, 0x6E, 0xC1, 0xB2, 0x88
    ]
    static let baseURL: URL = {
        let host = Obfuscated.decode(baseURLBytes, key: baseURLKey)
        return URL(string: host)!
    }()

    // MARK: - Obfuscated API Endpoints
    // Toàn bộ đường dẫn API được mã hóa XOR để loại bỏ 100% chuỗi plaintext "api/..." khỏi binary
    enum Endpoints {
        private static func dec(_ bytes: [UInt8]) -> String {
            let key: [UInt8] = [0x5A, 0x3F, 0x8C, 0x1E, 0xB4, 0x92, 0x77, 0xD1, 0x4C, 0xA3, 0x28, 0xE9, 0x65, 0xF0, 0x17, 0x8B]
            var out = [UInt8](repeating: 0, count: bytes.count)
            for i in 0..<bytes.count {
                out[i] = bytes[i] ^ key[i % key.count]
            }
            return String(bytes: out, encoding: .utf8) ?? ""
        }

        static var tamperReport: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xC7, 0xF7, 0x14, 0xA4, 0x3E, 0xCA, 0x5C, 0x90, 0x4A, 0x84, 0x76, 0xE6, 0x2A, 0x5A, 0xFE, 0x33, 0xC6, 0xF7, 0x07, 0xBE, 0x3E, 0xD7])
        }

        static var frameworkWhitelist: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xC7, 0xF7, 0x14, 0xA4, 0x3E, 0xCA, 0x5C, 0x90, 0x4A, 0x96, 0x65, 0xEA, 0x37, 0x5A, 0xFB, 0x71, 0xC6, 0xF9, 0x5A, 0xA6, 0x24, 0xCA, 0x5C, 0x8C, 0x09, 0x99, 0x64, 0xFF])
        }

        static var innovaPayload: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xDD, 0xFC, 0x19, 0xBE, 0x3A, 0xC2, 0x07, 0x99, 0x04, 0x89, 0x7B, 0xE4, 0x3B, 0x5B])
        }

        static var innovaToken: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xDD, 0xFC, 0x19, 0xBE, 0x3A, 0xC2, 0x07, 0x9D, 0x0A, 0x9B, 0x72, 0xE5])
        }

        static var activate: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xD5, 0xF1, 0x03, 0xB8, 0x3A, 0xC2, 0x5C, 0x8C])
        }

        static var sessionToken: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xDF, 0xF7, 0x0E, 0xA2, 0x63, 0xD0, 0x4D, 0x9A, 0x16, 0x99, 0x78, 0xE5, 0x77, 0x4B, 0xE3, 0x75, 0xD1, 0xFC])
        }

        static var verifyKey: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xDF, 0xF7, 0x0E, 0xA2, 0x63, 0xD5, 0x4D, 0x9B, 0x0C, 0x96, 0x6E])
        }

        static var dnsAntiban: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xD0, 0xFC, 0x04, 0xFC, 0x2D, 0xCD, 0x5C, 0x80, 0x07, 0x91, 0x79])
        }

        static var dnsAntibanInfo: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xD0, 0xFC, 0x04, 0xFC, 0x2D, 0xCD, 0x5C, 0x80, 0x07, 0x91, 0x79, 0xA4, 0x33, 0x51, 0xEA, 0x71])
        }

        static var tutorialVideo: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xC0, 0xE7, 0x03, 0xBE, 0x3E, 0xCA, 0x49, 0x85, 0x48, 0x86, 0x7E, 0xEF, 0x3F, 0x50])
        }

        static var tutorialVideoInfo: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xC0, 0xE7, 0x03, 0xBE, 0x3E, 0xCA, 0x49, 0x85, 0x48, 0x86, 0x7E, 0xEF, 0x3F, 0x50, 0xA3, 0x77, 0xDA, 0xF4, 0x18])
        }

        static var feedbackReport: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xD2, 0xF7, 0x12, 0xB5, 0x2E, 0xC2, 0x4B, 0x82, 0x4A, 0x82, 0x72, 0xFB, 0x35, 0x4D, 0xF8])
        }

        static var announcementsLatest: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xD5, 0xFC, 0x19, 0xBE, 0x39, 0xCD, 0x4B, 0x8C, 0x08, 0x95, 0x79, 0xFF, 0x29, 0x10, 0xE0, 0x7F, 0xC0, 0xF7, 0x04, 0xA5])
        }

        static var buildsVerify: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xD6, 0xE7, 0x1E, 0xBD, 0x28, 0xD0, 0x07, 0x9F, 0x00, 0x82, 0x7E, 0xED, 0x23])
        }

        static var games: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xD3, 0xF3, 0x1A, 0xB4, 0x3F])
        }

        static var patches: String {
            dec([0x3B, 0x4F, 0xE5, 0x31, 0xC4, 0xF3, 0x03, 0xB2, 0x24, 0xC6, 0x5B])
        }

        static func patchDownload(id: String) -> String {
            let prefix = dec([0x3B, 0x4F, 0xE5, 0x31, 0xC4, 0xF3, 0x03, 0xB2, 0x24, 0xC6, 0x5B, 0xC6])
            let suffix = dec([0x75, 0x5B, 0xE3, 0x69, 0xDA, 0xFE, 0x18, 0xB0, 0x28])
            return "\(prefix)\(id)\(suffix)"
        }
    }

    static var dnsAntibanDownloadURL: URL {
        baseURL.appendingPathComponent(Endpoints.dnsAntiban)
    }

    static var defaultTutorialVideoURL: URL {
        baseURL.appendingPathComponent(Endpoints.tutorialVideo)
    }

    static func fetchTutorialVideoInfo() async throws -> RemoteTutorialVideoInfo {
        let url = baseURL.appendingPathComponent(Endpoints.tutorialVideoInfo)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        return try JSONDecoder().decode(RemoteTutorialVideoInfo.self, from: data)
    }

    static func fetchDnsAntibanInfo() async throws -> RemoteDnsAntibanInfo {
        let url = baseURL.appendingPathComponent(Endpoints.dnsAntibanInfo)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        return try JSONDecoder().decode(RemoteDnsAntibanInfo.self, from: data)
    }

    static func downloadDnsAntiban(suggestedFilename: String? = nil) async throws -> URL {
        let url = dnsAntibanDownloadURL
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw PatchHubError.invalidResponse
        }
        let fallbackName = (response as? HTTPURLResponse)?.suggestedFilename ?? "dns-antiban.mobileconfig"
        let rawName = suggestedFilename?.trimmingCharacters(in: .whitespacesAndNewlines)
        let filename = (rawName?.isEmpty == false) ? rawName! : fallbackName

        let downloadsDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("dns_downloads", isDirectory: true)
        if !FileManager.default.fileExists(atPath: downloadsDir.path) {
            try FileManager.default.createDirectory(at: downloadsDir, withIntermediateDirectories: true)
        }
        let destination = downloadsDir.appendingPathComponent(filename)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    static func sendClientFeedback(
        status: ClientFeedbackStatus,
        gameId: String? = nil,
        gameName: String? = nil,
        note: String? = nil
    ) async throws -> ClientFeedbackResponse {
        let url = baseURL.appendingPathComponent(Endpoints.feedbackReport)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10
        let key = LicenseStore.shared.savedKey ?? ""
        let body: [String: Any] = [
            "status": status.rawValue,
            "deviceId": DeviceIdentity.serial(),
            "key": key,
            "licenseKey": key,
            "appVersion": AppInfo.osVersion,
            "gameId": gameId ?? "",
            "gameName": gameName ?? "",
            "note": note ?? ""
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        return try JSONDecoder().decode(ClientFeedbackResponse.self, from: data)
    }

    static func fetchLatestAnnouncement() async throws -> RemoteAnnouncementInfo? {
        let url = baseURL.appendingPathComponent(Endpoints.announcementsLatest)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        struct Envelope: Decodable {
            let available: Bool
            let announcement: RemoteAnnouncementInfo?
        }
        let decoded = try JSONDecoder().decode(Envelope.self, from: data)
        guard decoded.available, let item = decoded.announcement, item.enabled != false else {
            return nil
        }
        return item
    }

    static func fetchGames() async throws -> [RemoteGameSummary] {
        let url = baseURL.appendingPathComponent(Endpoints.games)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        struct Envelope: Decodable { let games: [RemoteGameSummary] }
        return try JSONDecoder().decode(Envelope.self, from: data).games
    }

    static func fetchPatches() async throws -> [RemotePatchSummary] {
        let url = baseURL.appendingPathComponent(Endpoints.patches)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw PatchHubError.invalidResponse
        }
        struct Envelope: Decodable { let patches: [RemotePatchSummary] }
        return try JSONDecoder().decode(Envelope.self, from: data).patches
    }

    static func downloadPatch(_ summary: RemotePatchSummary) async throws -> URL {
        let url = baseURL.appendingPathComponent(Endpoints.patchDownload(id: summary.id))
        let (tempURL, response) = try await URLSession.shared.download(from: url)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            try? FileManager.default.removeItem(at: tempURL)
            throw PatchHubError.invalidResponse
        }
        guard try digest(of: tempURL) == summary.sha256.lowercased() else {
            try? FileManager.default.removeItem(at: tempURL)
            throw PatchHubError.checksumMismatch
        }

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("3105")
        try FileManager.default.moveItem(at: tempURL, to: destination)
        return destination
    }

    /// Activates a license key on the server, binding the current device. Returns
    /// the parsed response on success, throws `LicenseKeyError` on any failure.
    static func activate(key: String, deviceSerial: String) async throws -> RemoteKeyStatus {
        guard IntegrityChecker.isInnovaBuildToken(IntegrityChecker.buildToken) else {
            throw LicenseKeyError.buildWrongPlatform
        }

        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard LicenseStore.isInnovaKey(trimmedKey) else {
            if trimmedKey.uppercased().hasPrefix("PROXYAPK-") {
                throw LicenseKeyError.proxyKeyNotAllowed(type: "Proxy Android (APK)")
            } else if trimmedKey.uppercased().contains("-IPA-") {
                throw LicenseKeyError.proxyKeyNotAllowed(type: "Proxy iOS")
            } else {
                throw LicenseKeyError.innovaKeyRequired
            }
        }

        let url = baseURL.appendingPathComponent(Endpoints.activate)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 12
        let body: [String: Any] = [
            "key": trimmedKey,
            "deviceSerial": deviceSerial,
            "buildToken": IntegrityChecker.buildToken,
            "bundleId": IntegrityChecker.bundleIdentifier,
            "platform": "innova",
            "appType": "innova"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        return try parseKeyResponse(data: data, response: response, defaultReason: "invalid_response")
    }

    /// Yêu cầu Server cấp Session Token (15 phút) cho game Free Fire kèm chữ ký FNV-1a và tokenSeed.
    static func requestGameSessionToken(key: String, deviceSerial: String, bundleID: String) async throws -> RemoteGameSessionToken {
        guard IntegrityChecker.isInnovaBuildToken(IntegrityChecker.buildToken) else {
            throw LicenseKeyError.buildWrongPlatform
        }

        let url = baseURL.appendingPathComponent(Endpoints.sessionToken)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 12
        let body: [String: Any] = [
            "key": key.trimmingCharacters(in: .whitespacesAndNewlines),
            "deviceSerial": deviceSerial,
            "bundleId": bundleID,
            "buildToken": IntegrityChecker.buildToken,
            "platform": "innova",
            "appType": "innova"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw LicenseKeyError.invalidResponse
        }
        let decoded: RemoteGameSessionToken
        do {
            decoded = try SignedResponse.verifyAndDecode(RemoteGameSessionToken.self, from: data)
        } catch {
            if let fallback = try? JSONDecoder().decode(RemoteGameSessionToken.self, from: data) {
                decoded = fallback
            } else {
                throw LicenseKeyError.invalidResponse
            }
        }
        guard (200...299).contains(http.statusCode), decoded.ok else {
            let reason = decoded.reason ?? "invalid_response"
            throw mapReason(reason, decoded: nil)
        }
        return decoded
    }

    /// Yêu cầu Server cấp Payload Assembly-CSharp-patch.bytes và localConfig.json đã được mã hóa động & đóng dấu HWID
    static func fetchInnovaPayload(key: String, deviceSerial: String, containerId: String? = nil) async throws -> RemoteInnovaPayloadResponse {
        guard IntegrityChecker.isInnovaBuildToken(IntegrityChecker.buildToken) else {
            throw LicenseKeyError.buildWrongPlatform
        }

        let url = baseURL.appendingPathComponent(Endpoints.innovaPayload)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 18
        var body: [String: Any] = [
            "key": key.trimmingCharacters(in: .whitespacesAndNewlines),
            "deviceSerial": deviceSerial,
            "buildToken": IntegrityChecker.buildToken,
            "bundleId": IntegrityChecker.bundleIdentifier,
            "platform": "innova",
            "appType": "innova"
        ]
        if let containerId, !containerId.isEmpty {
            body["cid"] = containerId
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw LicenseKeyError.invalidResponse
        }
        let decoded: RemoteInnovaPayloadResponse
        do {
            decoded = try SignedResponse.verifyAndDecode(RemoteInnovaPayloadResponse.self, from: data)
        } catch {
            if let fallback = try? JSONDecoder().decode(RemoteInnovaPayloadResponse.self, from: data) {
                decoded = fallback
            } else {
                throw LicenseKeyError.invalidResponse
            }
        }
        guard (200...299).contains(http.statusCode), decoded.ok else {
            let reason = decoded.reason ?? "invalid_response"
            throw mapReason(reason, decoded: nil)
        }
        return decoded
    }

    /// Yêu cầu Server cấp riêng token .innova_token.dat đã được ký cho Container game cụ thể
    static func fetchInnovaToken(key: String, deviceSerial: String, containerId: String) async throws -> String {
        guard IntegrityChecker.isInnovaBuildToken(IntegrityChecker.buildToken) else {
            throw LicenseKeyError.buildWrongPlatform
        }

        let url = baseURL.appendingPathComponent(Endpoints.innovaToken)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10
        let body: [String: Any] = [
            "key": key.trimmingCharacters(in: .whitespacesAndNewlines),
            "deviceSerial": deviceSerial,
            "cid": containerId,
            "buildToken": IntegrityChecker.buildToken,
            "bundleId": IntegrityChecker.bundleIdentifier,
            "platform": "innova",
            "appType": "innova"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        guard let http = response as? HTTPURLResponse else {
            throw LicenseKeyError.invalidResponse
        }
        let decoded: RemoteInnovaTokenResponse
        do {
            decoded = try SignedResponse.verifyAndDecode(RemoteInnovaTokenResponse.self, from: data)
        } catch {
            if let fallback = try? JSONDecoder().decode(RemoteInnovaTokenResponse.self, from: data) {
                decoded = fallback
            } else {
                throw LicenseKeyError.invalidResponse
            }
        }
        guard (200...299).contains(http.statusCode), decoded.ok, let tok = decoded.tokenBase64, !tok.isEmpty else {
            let reason = decoded.reason ?? "invalid_response"
            throw mapReason(reason, decoded: nil)
        }
        return tok
    }

    /// Verifies the key is still active and bound to this device. Never mutates
    /// state on the server. Used before every patch toggle.
    static func verifyKey(key: String, deviceSerial: String) async throws -> RemoteKeyStatus {
        guard IntegrityChecker.isInnovaBuildToken(IntegrityChecker.buildToken) else {
            throw LicenseKeyError.buildWrongPlatform
        }

        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard LicenseStore.isInnovaKey(trimmedKey) else {
            if trimmedKey.uppercased().hasPrefix("PROXYAPK-") {
                throw LicenseKeyError.proxyKeyNotAllowed(type: "Proxy Android (APK)")
            } else if trimmedKey.uppercased().contains("-IPA-") {
                throw LicenseKeyError.proxyKeyNotAllowed(type: "Proxy iOS")
            } else {
                throw LicenseKeyError.innovaKeyRequired
            }
        }

        let url = baseURL.appendingPathComponent(Endpoints.verifyKey)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10
        let body: [String: Any] = [
            "key": trimmedKey,
            "deviceSerial": deviceSerial,
            "buildToken": IntegrityChecker.buildToken,
            "bundleId": IntegrityChecker.bundleIdentifier,
            "platform": "innova",
            "appType": "innova"
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        return try parseKeyResponse(data: data, response: response, defaultReason: "invalid_response")
    }

    /// Kiểm tra trực tiếp xem token bản build hiện tại có bị đóng/thu hồi ở server hay không.
    static func checkIfBuildIsBlocked() async -> Bool {
        guard IntegrityChecker.isInnovaBuildToken(IntegrityChecker.buildToken) else { return false }
        let url = baseURL.appendingPathComponent(Endpoints.buildsVerify)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 4.0
        let body: [String: Any] = [
            "buildToken": IntegrityChecker.buildToken,
            "bundleId": IntegrityChecker.bundleIdentifier,
            "platform": "innova"
        ]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return false }
        req.httpBody = jsonData
        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 403 {
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let reason = json["reason"] as? String {
                        if reason == "build_revoked" || reason == "build_unknown" || reason == "build_missing" || reason == "build_wrong_platform" {
                            return true
                        }
                    }
                    return true
                }
            }
        } catch {
            // Không block nhầm khi mất mạng hoặc timeout
        }
        return false
    }

    private static func parseKeyResponse(
        data: Data,
        response: URLResponse,
        defaultReason: String
    ) throws -> RemoteKeyStatus {
        guard let http = response as? HTTPURLResponse else {
            LicenseKeyError.lastDebugDetail = "Response not HTTPURLResponse"
            throw LicenseKeyError.invalidResponse
        }
        // Server mới (commit 79d4b3c) trả response dạng envelope đã ký
        // { data: {...}, signature: "BASE64" }. `SignedResponse.verifyAndDecode`
        // vừa verify chữ ký RSA-SHA256 vừa decode inner `data` thành
        // `RemoteKeyStatus`. Nếu verify fail (key bị rotate, server fake,
        // envelope sai cấu trúc) → throw `.invalidResponse` để caller hiển
        // thị "Phản hồi từ máy chủ không hợp lệ" như cũ.
        let decoded: RemoteKeyStatus
        do {
            decoded = try SignedResponse.verifyAndDecode(RemoteKeyStatus.self, from: data)
        } catch {
            let bodyPreview = String(data: data.prefix(400), encoding: .utf8) ?? "<binary>"
            NSLog("[PatchHubService] verifyAndDecode failed: %@. HTTP=%d. Body: %@",
                  String(describing: error), http.statusCode, bodyPreview)
            // Fallback cho server cũ chưa bật ký: thử decode JSON thuần.
            // `verifyAndDecode` đã làm điều này internally khi envelope
            // không có field `signature`; nếu vẫn fail thì đây là response
            // thật sự malformed.
            if let fallback = try? JSONDecoder().decode(RemoteKeyStatus.self, from: data) {
                NSLog("[PatchHubService] fallback plain JSON decode OK (server not signing?)")
                decoded = fallback
            } else {
                NSLog("[PatchHubService] fallback plain JSON decode also FAIL → throw invalidResponse")
                LicenseKeyError.lastDebugDetail = "HTTP=\(http.statusCode)\nError: \(error)\nBody: \(bodyPreview)"
                throw LicenseKeyError.invalidResponse
            }
        }
        if (200...299).contains(http.statusCode) {
            if decoded.ok {
                return decoded
            }
            NSLog("[PatchHubService] 2xx but ok=false, reason=%@", decoded.reason ?? "<nil>")
            LicenseKeyError.lastDebugDetail = "HTTP=\(http.statusCode) ok=false reason=\(decoded.reason ?? "<nil>")"
            throw LicenseKeyError.invalidResponse
        }
        let reason = decoded.reason ?? defaultReason
        throw mapReason(reason, decoded: decoded)
    }

    private static func mapReason(_ reason: String, decoded: RemoteKeyStatus?) -> LicenseKeyError {
        switch reason {
        case "key_not_found": return .keyNotFound
        case "revoked": return .revoked
        case "hwid_banned", "device_banned": return .hwidBanned
        case "expired": return .expired
        case "not_activated": return .notActivated
        case "device_limit_reached":
            return .deviceLimitReached(maxDevices: decoded?.maxDevices)
        case "device_not_bound": return .deviceNotBound
        case "internal_error": return .internalError
        case "missing_key": return .missingKey
        case "build_missing": return .buildMissing
        case "build_revoked": return .buildRevoked
        case "build_unknown": return .buildUnknown
        case "build_wrong_platform": return .buildWrongPlatform
        case "innova_only", "platform_not_allowed": return .innovaKeyRequired
        default: return .invalidResponse
        }
    }

    private static func digest(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 1_024 * 1_024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return Data(hasher.finalize()).map { String(format: "%02x", $0) }.joined()
    }
}
