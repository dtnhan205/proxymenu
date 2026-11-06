import Foundation

// MARK: - ProxyModels
//
// Kiểu dữ liệu dùng chung cho Proxy Client.
//
// LƯU Ý PHẠM VI (đọc kỹ trước khi mở rộng):
// Proxy ở đây là proxy cấp ỨNG DỤNG (URLSession), không phải VPN toàn hệ thống.
// - HTTP/HTTPS: đi qua CONNECT, KHÔNG giải mã TLS, KHÔNG cần root CA.
// - SOCKS5: CFNetwork hỗ trợ qua connectionProxyDictionary (key không chính thức).
// Muốn toàn hệ thống phải có NEPacketTunnelProvider + entitlement
// `com.apple.developer.networking.networkextension` trên App ID thật.

/// Giao thức proxy được hỗ trợ.
enum ProxyProtocol: String, Codable, CaseIterable, Identifiable, Hashable {
    case http
    case https
    case socks5

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .http: return "HTTP"
        case .https: return "HTTPS"
        case .socks5: return "SOCKS5"
        }
    }

    /// Mô tả ngắn để hiển thị trong form.
    var detailText: String {
        switch self {
        case .http: return "Proxy HTTP, HTTPS đi qua CONNECT"
        case .https: return "Proxy HTTP áp dụng cho cả lưu lượng HTTPS"
        case .socks5: return "SOCKS5 ở tầng TCP"
        }
    }

    /// Giới hạn thực tế của CFNetwork, hiển thị công khai trong UI.
    var credentialNote: String? {
        switch self {
        case .socks5:
            return "CFNetwork không truyền username/password cho SOCKS5. Nếu proxy yêu cầu xác thực, SOCKS5 sẽ thất bại — dùng HTTP/HTTPS."
        case .http, .https:
            return nil
        }
    }
}

/// Một cấu hình proxy đã lưu.
///
/// `username` là định danh (không bí mật). Mật khẩu KHÔNG nằm trong struct này
/// và không được serialize xuống đĩa — xem `ProxyCredentialStore` (Keychain).
struct ProxyConfiguration: Codable, Identifiable, Hashable {
    let id: UUID
    var name: String
    var host: String
    var port: Int
    var proto: ProxyProtocol
    var username: String
    var requiresAuthentication: Bool
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "",
        host: String = "",
        port: Int = 8080,
        proto: ProxyProtocol = .http,
        username: String = "",
        requiresAuthentication: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.host = host
        self.port = port
        self.proto = proto
        self.username = username
        self.requiresAuthentication = requiresAuthentication
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// `host:port` để hiển thị và dựng URL.
    var endpoint: String { "\(host):\(port)" }

    /// Tên hiển thị: ưu tiên tên người dùng đặt, fallback về endpoint.
    var displayName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? endpoint : trimmed
    }

    /// Host hợp lệ: không rỗng, không chứa khoảng trắng.
    var normalizedHost: String {
        host.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Kiểm tra tối thiểu trước khi cho phép connect.
    var isValid: Bool {
        guard !normalizedHost.isEmpty,
              !normalizedHost.contains(" "),
              (1...65535).contains(port) else {
            return false
        }
        return true
    }

    /// Lý do không hợp lệ, dùng cho thông báo lỗi.
    var validationMessage: String? {
        if normalizedHost.isEmpty { return "Chưa nhập địa chỉ proxy." }
        if normalizedHost.contains(" ") { return "Địa chỉ proxy không được chứa khoảng trắng." }
        if !(1...65535).contains(port) { return "Port phải trong khoảng 1–65535." }
        return nil
    }

    /// Chuẩn hoá trước khi lưu.
    mutating func normalize() {
        host = normalizedHost
        name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        username = username.trimmingCharacters(in: .whitespacesAndNewlines)
        if !requiresAuthentication {
            username = ""
        }
        if port > 65535 { port = 65535 }
        updatedAt = Date()
    }
}

/// Trạng thái kết nối THỰC TẾ của proxy.
///
/// `.connected` chỉ được set sau khi một request thật đi xuyên proxy thành công.
enum ProxyConnectionState: Equatable {
    case disconnected
    case connecting
    case connected
    case failed(String)

    var isBusy: Bool {
        if case .connecting = self { return true }
        return false
    }

    var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    var title: String {
        switch self {
        case .disconnected: return "Chưa kết nối"
        case .connecting: return "Đang kết nối…"
        case .connected: return "Đã kết nối"
        case .failed: return "Kết nối thất bại"
        }
    }
}

/// Kết quả kiểm tra proxy (TCP latency + request thật + IP egress).
struct ProxyTestResult: Equatable {
    let success: Bool
    let tcpLatencyMs: Int?
    let egressIP: String?
    let message: String
}

/// Kiểu kết nối mạng đang hoạt động.
enum ProxyNetworkType: String {
    case wifi = "Wi-Fi"
    case cellular = "Mạng di động"
    case wired = "Ethernet"
    case other = "Khác"
    case offline = "Không có mạng"

    var iconName: String {
        switch self {
        case .wifi: return "wifi"
        case .cellular: return "antenna.radiowaves.left.and.right"
        case .wired: return "cable.connector"
        case .other: return "network"
        case .offline: return "wifi.slash"
        }
    }
}

// MARK: - Định dạng thời lượng

enum ProxyDuration {
    /// `01:23:45` hoặc `12:05` — dùng cho bộ đếm thời gian kết nối.
    static func hms(_ interval: TimeInterval) -> String {
        guard interval.isFinite, interval >= 0 else { return "00:00" }
        let total = Int(interval)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        }
        return String(format: "%02d:%02d", m, s)
    }
}