import SwiftUI

/// Toast banner trượt từ trái sang ở phía trên bên trái.
/// - iOS được hỗ trợ: banner xanh (neon lime), icon checkmark, text "SẴN SÀNG HỖ TRỢ iOS X".
/// - iOS không được hỗ trợ: banner đỏ (neon magenta), icon xmark, text "KHÔNG HỖ TRỢ iOS X".
/// Tự ẩn sau `autoDismissAfter` giây. Có nút đóng để user đóng thủ công.
struct SupportStatusToast: View {

    @ObservedObject var model: SupportStatusToastModel
    @Environment(\.appLanguage) private var language

    /// Thời gian tự ẩn (giây). Đặt 0 nếu muốn user phải đóng thủ công.
    var autoDismissAfter: Double = 6.0

    var body: some View {
        VStack {
            HStack {
                banner
                    .padding(.leading, 16)
                    .padding(.top, 8)
                Spacer(minLength: 0)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(model.isVisible)
        .onAppear {
            // Đảm bảo luôn có auto-dismiss khi view tồn tại trong hierarchy.
            model.scheduleAutoDismiss(after: autoDismissAfter)
        }
        // Bắt buộc thiết lập lại countdown mỗi khi payload thay đổi (present
        // từ RootView hay announceSupportStatus). `.onAppear` chỉ chạy 1 lần
        // và `present()` đã `cancel()` task trước đó nên nếu chỉ dựa vào
        // `.onAppear`, toast sẽ KHÔNG tự ẩn sau khi gọi `present()`.
        .onChange(of: model.payload) { newPayload in
            guard newPayload != nil else { return }
            model.scheduleAutoDismiss(after: autoDismissAfter)
        }
    }

    @ViewBuilder
    private var banner: some View {
        if let payload = model.payload {
            HStack(spacing: 10) {
                Image(systemName: payload.isSupported ? "checkmark.shield.fill" : "xmark.shield.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(payload.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta)
                    .shadow(color: (payload.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta).opacity(0.6), radius: 6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(payload.title(language: language))
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(payload.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta)
                        .lineLimit(1)
                    Text(payload.subtitle(language: language))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.75))
                        .lineLimit(2)
                }

                Button {
                    model.dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 0.5))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.78))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [
                                        (payload.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta).opacity(0.85),
                                        (payload.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta).opacity(0.25)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
            .shadow(
                color: (payload.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta).opacity(0.35),
                radius: 12,
                x: 0,
                y: 4
            )
            .frame(maxWidth: 320, alignment: .leading)
            .transition(
                .asymmetric(
                    insertion: .move(edge: .leading).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                )
            )
        }
    }
}

/// Payload chứa thông tin hiển thị toast.
struct SupportStatusPayload: Equatable {
    let iosMajor: Int
    let iosMinor: Int
    let iosPatch: Int
    let isSupported: Bool

    var iosLabel: String { "\(iosMajor).\(iosMinor).\(iosPatch)" }

    func title(language: AppLanguage) -> String {
        if isSupported {
            return language.text("support_toast.supported_title", iosLabel)
        } else {
            return language.text("support_toast.unsupported_title", iosLabel)
        }
    }

    func subtitle(language: AppLanguage) -> String {
        if isSupported {
            return language.text("support_toast.supported_subtitle")
        } else {
            return language.text("support_toast.unsupported_subtitle")
        }
    }
}

/// ObservableObject quản lý vòng đời toast: payload, animation in/out, auto-dismiss.
final class SupportStatusToastModel: ObservableObject {

    @Published private(set) var payload: SupportStatusPayload?
    @Published private(set) var isVisible: Bool = false

    private var dismissTask: DispatchWorkItem?

    /// Hiển thị toast với payload mới. Nếu toast đã hiển thị, thay thế ngay lập tức.
    func present(_ payload: SupportStatusPayload) {
        dismissTask?.cancel()
        withAnimation(.spring(response: 0.45, dampingFraction: 0.78)) {
            self.payload = payload
            self.isVisible = true
        }
    }

    /// Lên lịch tự ẩn sau `seconds` giây.
    func scheduleAutoDismiss(after seconds: Double) {
        dismissTask?.cancel()
        guard seconds > 0 else { return }
        let task = DispatchWorkItem { [weak self] in
            self?.dismiss()
        }
        dismissTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: task)
    }

    /// Ẩn toast với animation trượt ngược.
    func dismiss() {
        dismissTask?.cancel()
        dismissTask = nil
        withAnimation(.easeInOut(duration: 0.32)) {
            self.isVisible = false
        }
        // Clear payload sau khi animation kết thúc để không re-trigger transition khi present.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            if !self.isVisible { self.payload = nil }
        }
    }
}