import SwiftUI
import UIKit

/// Overlay phủ toàn màn hình khi server đóng tokenbuild (`build_revoked` / `build_unknown`).
/// Hiển thị thông báo cập nhật phiên bản mới và cung cấp nút mở trang web tải bản mới.
/// Block toàn bộ tương tác — không có nút quay lại, không cho phép sử dụng bản build cũ đã bị thu hồi.
struct BuildBlockedOverlay: View {
    @State private var pulse: Bool = false
    @State private var didCopy: Bool = false

    private let updateURLString = "https://serveripa.proxyvip.click/innova"

    var body: some View {
        ZStack {
            // Nền tối công nghệ Cyberpunk phủ trọn vẹn màn hình
            Color.black.opacity(0.97)
                .ignoresSafeArea()

            // Vầng sáng neon ambient phía sau
            RadialGradient(
                colors: [
                    Color(red: 0.0, green: 0.85, blue: 1.0).opacity(0.18),
                    Color(red: 0.8, green: 0.0, blue: 0.95).opacity(0.12),
                    Color.clear
                ],
                center: .center,
                startRadius: 20,
                endRadius: 280
            )
            .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    Spacer().frame(height: 30)

                    // Biểu tượng cập nhật lớn với vòng sáng neon Cyberpunk
                    ZStack {
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Color.red.opacity(0.3), Color.clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 60
                                )
                            )
                            .frame(width: 120, height: 120)

                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [AppTheme.neonCyan, AppTheme.neonMagenta],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2
                            )
                            .frame(width: 88, height: 88)
                            .shadow(color: AppTheme.neonCyan.opacity(0.6), radius: 12)

                        Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.system(size: 46, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [Color(red: 0.0, green: 0.94, blue: 1.0), Color.white],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .scaleEffect(pulse ? 1.06 : 0.95)
                            .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                    }

                    // Khối tiêu đề theo đúng yêu cầu:
                    // 1. ĐÃ UPDATE PHIÊN BẢN MỚI
                    // 2. VUI LÒNG XÓA BẢN HIỆN TẠI
                    // 3. TRUY CẬP TRANG WEB BÊN DƯỚI ĐỂ CÀI BẢN MỚI
                    VStack(spacing: 14) {
                        Text("ĐÃ UPDATE PHIÊN BẢN MỚI")
                            .font(.system(size: 22, weight: .black, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(1.2)
                            .multilineTextAlignment(.center)
                            .shadow(color: AppTheme.neonCyan.opacity(0.5), radius: 8)

                        // Badge cảnh báo xóa bản hiện tại
                        HStack(spacing: 8) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 13, weight: .bold))
                            Text("VUI LÒNG XÓA BẢN HIỆN TẠI")
                                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                .tracking(0.8)
                        }
                        .foregroundColor(Color(red: 1.0, green: 0.3, blue: 0.3))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.14))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.red.opacity(0.45), lineWidth: 1))

                        Text("TRUY CẬP TRANG WEB BÊN DƯỚI ĐỂ CÀI BẢN MỚI")
                            .font(.system(size: 13.5, weight: .bold, design: .rounded))
                            .foregroundColor(Color.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                            .lineSpacing(4)
                    }

                    // Card hiển thị đường dẫn Web & Nút Sao chép
                    VStack(spacing: 10) {
                        HStack(spacing: 10) {
                            Image(systemName: "link.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(AppTheme.neonCyan)

                            Text(updateURLString)
                                .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Spacer()

                            Button {
                                UIPasteboard.general.string = updateURLString
                                didCopy = true
                                let gen = UINotificationFeedbackGenerator()
                                gen.notificationOccurred(.success)
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                    didCopy = false
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: didCopy ? "checkmark" : "doc.on.doc.fill")
                                    Text(didCopy ? "ĐÃ CHÉP" : "SAO CHÉP")
                                }
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(didCopy ? .green : AppTheme.neonCyan)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color.white.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                )
                        )
                    }
                    .padding(.horizontal, 24)

                    // Nút bấm lớn truy cập web mở trang tải bản mới
                    Button(action: openUpdateWebsite) {
                        HStack(spacing: 10) {
                            Image(systemName: "safari.fill")
                                .font(.system(size: 18, weight: .bold))

                            Text("TRUY CẬP TRANG WEB CÀI BẢN MỚI")
                                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                .tracking(1.0)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.85, blue: 1.0),
                                    Color(red: 0.6, green: 0.1, blue: 0.95)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .shadow(color: AppTheme.neonCyan.opacity(0.4), radius: 12, y: 4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.horizontal, 24)

                    // Nút thoát ứng dụng
                    Button {
                        exit(0)
                    } label: {
                        Text("THOÁT ỨNG DỤNG")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(Color.white.opacity(0.5))
                            .padding(.vertical, 8)
                    }

                    // Chú thích chân trang
                    Text("Bản build này đã ngừng hỗ trợ và thu hồi token trên máy chủ để đảm bảo tính năng hoạt động chuẩn xác.")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.35))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.top, 4)

                    Spacer().frame(height: 20)
                }
                .padding(.vertical, 20)
            }
        }
        .onAppear { pulse = true }
        .allowsHitTesting(true)
    }

    private func openUpdateWebsite() {
        guard let url = URL(string: updateURLString) else { return }
        UIApplication.shared.open(url)
    }
}
