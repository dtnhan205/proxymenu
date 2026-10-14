import SwiftUI
import UIKit

/// Cửa sổ hiển thị trạng thái và hướng dẫn Ghép Đôi iOS 27 (RemotePairing)
/// Tương thích hoàn toàn với cơ chế ghép đôi không dây (Developer Mode) của iOS 27+.
struct RemotePairingSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var pairing = RemotePairingAdvertiser.shared
    @ObservedObject private var vpnManager = LocalDevVPNManager.shared
    @AppStorage(AppLanguage.storageKey) private var languageCode: String = AppLanguage.vietnamese.rawValue

    @State private var isPulsing: Bool = false

    private var isEnglish: Bool {
        languageCode == AppLanguage.english.rawValue
    }

    var body: some View {
        ZStack {
            // Nền tối Cyberpunk sang trọng
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()

            // Hiệu ứng ánh sáng nền
            VStack {
                Circle()
                    .fill(AppTheme.neonCyan.opacity(0.12))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(y: -120)
                Spacer()
            }

            VStack(spacing: 0) {
                // Header Bar
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Card Trạng thái phát sóng Bonjour
                        broadcastingCard

                        // Card Mã PIN (nếu có yêu cầu từ hệ thống)
                        if !pairing.pinCode.isEmpty {
                            pinCodeCard
                        }

                        // Card Các bước thực hiện chi tiết
                        pairingStepsCard

                        // Card Thông số kỹ thuật
                        techDetailsCard

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }

                // Bottom Action Buttons
                bottomActionBar
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.07, green: 0.07, blue: 0.10).opacity(0.95))
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1),
                        alignment: .top
                    )
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            isPulsing = true
            if !pairing.isAdvertising {
                pairing.startAdvertising()
            }
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(pairing.isAdvertising ? AppTheme.neonLime : AppTheme.neonAmber)
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPulsing ? 1.2 : 0.8)
                        .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)

                    Text(isEnglish ? "iOS 27 PAIRING CONDUIT" : "GHÉP ĐÔI iOS 27")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.neonCyan)
                }

                Text(isEnglish ? "Developer Mode Wireless Pairing" : "Ghép đôi Chế độ Nhà phát triển")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Broadcasting Card
    private var broadcastingCard: some View {
        VStack(spacing: 12) {
            radarAnimationView
            broadcastingInfoSection
            broadcastingPillsSection
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.10, green: 0.10, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    (pairing.isPaired ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.45),
                    lineWidth: 1
                )
        )
    }

    private var radarAnimationView: some View {
        ZStack {
            radarRingsView

            Circle()
                .fill(
                    LinearGradient(
                        colors: [AppTheme.neonCyan, AppTheme.neonBlue],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .shadow(color: AppTheme.neonCyan.opacity(0.6), radius: 10)

            Image(systemName: pairing.isPaired ? "checkmark.seal.fill" : "antenna.radiowaves.left.and.right")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
        }
        .padding(.top, 10)
    }

    private var radarRingsView: some View {
        ZStack {
            Circle()
                .strokeBorder(AppTheme.neonCyan.opacity(0.25), lineWidth: 1.5)
                .frame(width: 64, height: 64)

            Circle()
                .strokeBorder(AppTheme.neonCyan.opacity(0.18), lineWidth: 1.5)
                .frame(width: 92, height: 92)

            Circle()
                .strokeBorder(AppTheme.neonCyan.opacity(0.11), lineWidth: 1.5)
                .frame(width: 120, height: 120)
        }
        .scaleEffect(isPulsing ? 1.08 : 0.95)
        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
    }

    private var broadcastingInfoSection: some View {
        VStack(spacing: 4) {
            Text(pairing.advertisedName)
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)

            Text(pairing.statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(pairing.isPaired ? AppTheme.neonLime : AppTheme.neonAmber)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
    }

    private var broadcastingPillsSection: some View {
        HStack(spacing: 12) {
            statusPill(
                icon: "network",
                label: "PORT",
                value: "\(pairing.listeningPort)"
            )
            statusPill(
                icon: "dot.radiowaves.left.and.right",
                label: "BONJOUR",
                value: "_remotepairing"
            )
            statusPill(
                icon: "lock.shield.fill",
                label: "STATUS",
                value: pairing.isPaired ? "PAIRED" : "READY"
            )
        }
        .padding(.top, 4)
    }

    // MARK: - PIN Code Card
    private var pinCodeCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "key.fill")
                    .foregroundColor(AppTheme.neonAmber)
                Text(isEnglish ? "VERIFICATION PIN" : "MÃ PIN XÁC THỰC GHÉP ĐÔI")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(AppTheme.neonAmber)
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(Array(pairing.pinCode), id: \.self) { char in
                    Text(String(char))
                        .font(.system(size: 26, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.neonCyan)
                        .frame(width: 42, height: 50)
                        .background(Color.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(AppTheme.neonCyan.opacity(0.6), lineWidth: 1.5)
                        )
                }
            }
            .padding(.vertical, 4)

            Text(isEnglish ? "Enter this PIN on device if prompted in Settings" : "Nhập mã PIN này trên máy nếu mục Ghép đôi yêu cầu xác nhận.")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .background(Color(red: 0.12, green: 0.10, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.neonAmber.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Pairing Steps Card
    private var pairingStepsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "list.number")
                    .foregroundColor(AppTheme.neonCyan)
                Text(isEnglish ? "PAIRING INSTRUCTIONS (4 STEPS)" : "HƯỚNG DẪN GHÉP ĐÔI (4 BƯỚC)")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(AppTheme.neonCyan)
                Spacer()
            }

            stepRow(
                number: 1,
                title: isEnglish ? "Tap 'OPEN IPHONE SETTINGS' below" : "Bấm nút 'MỞ CÀI ĐẶT IPHONE' ở bên dưới",
                desc: isEnglish ? "Opens iOS Settings directly" : "Chuyển nhanh sang màn hình Cài đặt của máy"
            )

            stepRow(
                number: 2,
                title: isEnglish ? "Go to Privacy & Security > Developer Mode" : "Vào Quyền riêng tư & Bảo mật > Chế độ nhà phát triển",
                desc: isEnglish ? "Ensure Developer Mode toggle is ON" : "Đảm bảo công tắc Chế độ nhà phát triển đã BẬT"
            )

            stepRow(
                number: 3,
                title: isEnglish ? "Look under 'Other Devices' & tap '\(pairing.advertisedName)'" : "Trong mục 'Các thiết bị khác', chọn '\(pairing.advertisedName)'",
                desc: isEnglish ? "Wait for the spinner and pairing request" : "Chờ biểu tượng xoay kết nối và mã xác nhận hiện ra"
            )

            stepRow(
                number: 4,
                title: isEnglish ? "Confirm Pairing & Return to App" : "Xác nhận ghép đôi & Quay lại ứng dụng",
                desc: isEnglish ? "Device moves to 'Paired Devices' and system tunnel is ready" : "Thiết bị sẽ chuyển vào 'Thiết bị đã ghép đôi' và sẵn sàng nạp mod!"
            )
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.08, blue: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Tech Details Card
    private var techDetailsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(isEnglish ? "CONDUIT DIAGNOSTICS" : "THÔNG SỐ CẦU NỐI")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(pairing.hasExistingPairing ? "FILE PAIRING: TỒN TẠI" : "FILE PAIRING: CHƯA CÓ")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonAmber)
            }

            VStack(alignment: .leading, spacing: 3) {
                techRow(label: "Bonjour Type", value: "_remotepairing-pairable-host._tcp.")
                techRow(label: "Hardware Model", value: "Mac17,7 (Apple Silicon Host)")
                techRow(label: "Loopback Tunnel", value: "\(vpnManager.lastConnectedHost)")
                techRow(label: "Keep-Alive Audio", value: "Active (AVAudioEngine background)")
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 8) {
            Button {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 15, weight: .bold))
                    Text(isEnglish ? "OPEN IPHONE SETTINGS" : "MỞ CÀI ĐẶT IPHONE")
                        .font(.system(size: 13.5, weight: .heavy, design: .monospaced))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .frame(height: 46)
                .background(
                    LinearGradient(
                        colors: [AppTheme.neonCyan, Color(red: 0.0, green: 0.8, blue: 0.9)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: AppTheme.neonCyan.opacity(0.55), radius: 8, y: 2)
            }
            .buttonStyle(.plain)

            HStack(spacing: 10) {
                Button {
                    pairing.startAdvertising()
                } label: {
                    Text(isEnglish ? "Restart Broadcast" : "Phát lại Bonjour")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(AppTheme.neonCyan)
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    pairing.stopAdvertising()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text(isEnglish ? "Stop & Close" : "Đóng cửa sổ")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helper Views
    private func statusPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(AppTheme.neonCyan)
                Text(value)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func stepRow(number: Int, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundColor(.black)
                .frame(width: 20, height: 20)
                .background(AppTheme.neonCyan)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
    }

    private func techRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}
