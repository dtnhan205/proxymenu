import SwiftUI

/// Footer cyberpunk sát dưới: hiện nửa đầu key, nửa sau thành `****`, cùng
/// thời gian còn lại đếm ngược từ `LicenseStore.expiresAt`. Toàn bộ đếm
/// trong RAM bằng `Timer` 1s — không gọi server mỗi giây, chỉ lấy 1 lần
/// từ response khi vào app.
struct KeyCountdownFooter: View {
    @ObservedObject private var store = LicenseStore.shared
    @State private var now: Date = Date()

    private let tick = Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            if let key = store.savedKey, !key.isEmpty, let exp = store.expiresAt {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 10) {
                        PulsingDot(color: countdownColor(exp: exp), size: 6)

                        Text(maskedKey(key))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(1.0)
                            .foregroundStyle(AppTheme.neonCyan)
                            .shadow(color: AppTheme.neonCyan.opacity(0.5), radius: 4)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)

                        Spacer(minLength: 6)

                        Text(countdownString(exp: exp))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .tracking(0.8)
                            .foregroundStyle(countdownColor(exp: exp))
                            .shadow(color: countdownColor(exp: exp).opacity(0.55), radius: 4)
                            .monospacedDigit()
                    }
                    if let summary = activationSummaryText(exp: exp) {
                        Text(summary)
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(countdownColor(exp: exp).opacity(0.65))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black.opacity(0.45))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    countdownColor(exp: exp).opacity(0.6),
                                    countdownColor(exp: exp).opacity(0.15),
                                    countdownColor(exp: exp).opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: countdownColor(exp: exp).opacity(0.25), radius: 8)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onChange(of: remainingSeconds(exp: exp)) { newValue in
                    if newValue <= 0 {
                        exitApp(reason: "License key đã hết hạn — ứng dụng đã đóng")
                    }
                }
            }
        }
        .onReceive(tick) { _ in
            now = Date()
        }
    }

    private func exitApp(reason: String) {
        NSLog("[KeyCountdownFooter] exit: \(reason)")
        exit(0)
    }

    // MARK: - Helpers

    /// Hiện nửa đầu key, nửa sau thay bằng `****`. Bỏ qua các ký tự không phải
    /// chữ/số để tránh hiển thị lộ phần dash.
    private func maskedKey(_ key: String) -> String {
        let chars = Array(key)
        guard chars.count > 1 else { return key }
        let mid = chars.count / 2
        let visible = chars.prefix(mid)
        let hiddenWidth = chars.count - mid
        return String(visible) + String(repeating: "*", count: hiddenWidth)
    }

    private func remainingSeconds(exp: Date) -> Int {
        let delta = Int(exp.timeIntervalSince(now))
        return max(0, delta)
    }

    private func countdownColor(exp: Date) -> Color {
        let secs = remainingSeconds(exp: exp)
        if secs <= 0 { return AppTheme.neonMagenta }
        if secs < 86_400 { return AppTheme.neonAmber }
        return AppTheme.neonCyan
    }

    private func countdownString(exp: Date) -> String {
        let secs = remainingSeconds(exp: exp)
        if secs <= 0 { return "HẾT HẠN" }
        let days = secs / 86_400
        let hours = (secs % 86_400) / 3600
        let mins = (secs % 3600) / 60
        let s = secs % 60
        if days > 0 {
            return String(format: "%dd %02d:%02d:%02d", days, hours, mins, s)
        }
        return String(format: "%02d:%02d:%02d", hours, mins, s)
    }

    /// Dòng phụ thông tin kích hoạt. Giúp user hiểu key còn bao lâu kể từ
    /// lúc activate đầu (server lazy-expiration), khi giá trị countdown hiện
    /// nhỏ hơn tổng `durationDays` thì key đã dùng được một khoảng.
    /// Ví dụ với key 7 ngày: `Duration: 7D · Since: 6D ago`.
    /// Ví dụ với key 1 giờ: `Duration: 1H · Since: 5m ago`.
    private func activationSummaryText(exp: Date) -> String? {
        // Ưu tiên `durationHours` (cho key ngắn < 1 ngày). Nếu absent hoặc ≥24
        // thì fallback `durationDays` cho key dài hạn.
        let useHours: Int? = {
            if let h = store.durationHours, h > 0, h < 24 { return h }
            return nil
        }()
        let useDays: Int? = {
            if useHours != nil { return nil }
            if let d = store.durationDays, d > 0 { return d }
            return nil
        }()
        guard useHours != nil || useDays != nil else { return nil }
        let durationLabel: String
        if let h = useHours {
            durationLabel = "\(h)H"
        } else if let d = useDays {
            durationLabel = "\(d)D"
        } else {
            return nil
        }
        guard let act = store.activatedAt else {
            return "Duration: \(durationLabel)"
        }
        let elapsed = max(0, Int(now.timeIntervalSince(act)))
        let sinceLabel: String
        if elapsed < 3_600 {
            let m = max(1, elapsed / 60)
            sinceLabel = "\(m)m ago"
        } else if elapsed < 86_400 {
            let h = elapsed / 3_600
            let m = (elapsed % 3_600) / 60
            sinceLabel = m == 0 ? "\(h)h ago" : "\(h)h\(m)m ago"
        } else {
            let d = elapsed / 86_400
            let h = (elapsed % 86_400) / 3_600
            sinceLabel = h == 0 ? "\(d)d ago" : "\(d)d\(h)h ago"
        }
        return "Duration: \(durationLabel) · Active: \(sinceLabel)"
    }
}
