import SwiftUI
import UIKit

/// Cửa sổ nhập key INNOVA — giao diện Cyberpunk VIP hiện đại, bảo mật cao.
/// - 60 giây không thao tác → tự động thoát ứng dụng để bảo vệ phiên bảo mật.
/// - Hỗ trợ nút Dán (Paste) key từ bộ nhớ tạm nhanh chóng.
/// - Hiển thị mã máy (HWID) kèm nút sao chép để tiện gửi admin kích hoạt.
/// - Phân biệt chính xác Key INNOVA và chặn các loại key khác.
/// - Hiển thị thanh đếm ngược thời gian thực, rung phản hồi xúc giác (haptic).
struct LicenseGateView: View {

    /// Callback khi key hợp lệ — view cha đổi sang root app chính.
    var onUnlock: () -> Void

    @State private var keyInput: String = ""
    @State private var isBusy: Bool = false
    @State private var errorMessage: String?
    @State private var isError: Bool = false
    @State private var remainingSeconds: Int = 60
    @State private var didTriggerTimeout: Bool = false
    @State private var isCopiedHWID: Bool = false
    @State private var timer: Timer?

    private let totalTimeoutSeconds: Int = 60

    var body: some View {
        ZStack {
            TechBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    Spacer().frame(height: 12)
                    emblemView
                    titleView
                    inputCard
                    activateButton
                    timeoutBar
                    footer
                    Spacer().frame(height: 24)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .preferredColorScheme(.dark)
        .onAppear(perform: handleAppear)
        .onDisappear(perform: handleDisappear)
        .onChange(of: keyInput) { _ in
            errorMessage = nil
            isError = false
        }
    }

    // MARK: - Header & Emblem

    private var emblemView: some View {
        ZStack {
            // Ambient neon radial glow
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            AppTheme.neonCyan.opacity(0.35),
                            AppTheme.neonMagenta.opacity(0.12),
                            .clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 60
                    )
                )
                .frame(width: 120, height: 120)

            // Diamond cyber outer frame
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            AppTheme.neonCyan,
                            AppTheme.neonMagenta,
                            AppTheme.neonCyan
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.8
                )
                .frame(width: 86, height: 86)
                .rotationEffect(.degrees(45))
                .shadow(color: AppTheme.neonCyan.opacity(0.65), radius: 12)

            // Dark inner plate
            Circle()
                .fill(Color.black.opacity(0.75))
                .frame(width: 74, height: 74)
                .overlay(
                    Circle()
                        .strokeBorder(AppTheme.neonCyan.opacity(0.35), lineWidth: 1)
                )

            // Shield / Bolt VIP icon
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            AppTheme.neonIce,
                            AppTheme.neonCyan,
                            AppTheme.neonMagenta
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: AppTheme.neonCyan.opacity(0.85), radius: 8)
        }
        .padding(.top, 4)
    }

    private var titleView: some View {
        VStack(spacing: 8) {
            Text("INNOVA CHEAT VIP")
                .font(.system(size: 24, weight: .black, design: .rounded))
                .tracking(3.5)
                .foregroundStyle(
                    LinearGradient(
                        colors: [
                            Color.white,
                            AppTheme.neonIce,
                            AppTheme.neonCyan
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .shadow(color: AppTheme.neonCyan.opacity(0.65), radius: 12)

            HStack(spacing: 8) {
                PulsingDot(color: AppTheme.neonLime, size: 5)

                Text("KERNEL SYSTEM // ONLINE")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(1.8)
                    .foregroundColor(AppTheme.neonLime)

                Text("•")
                    .foregroundColor(Color.white.opacity(0.3))

                Text("CLIENT v2.5")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(AppTheme.neonIce.opacity(0.85))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4.5)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .overlay(Capsule().strokeBorder(AppTheme.neonLime.opacity(0.35), lineWidth: 0.8))
            )
        }
    }

    // MARK: - Input Card

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Card Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "key.horizontal.fill")
                        .foregroundColor(AppTheme.neonCyan)
                    Text("KHÓA BẢN QUYỀN")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .tracking(1.4)
                        .foregroundColor(.white)
                }

                Spacer()

                Text("INNOVA ONLY")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(AppTheme.neonMagenta)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(AppTheme.neonMagenta.opacity(0.12))
                            .overlay(Capsule().strokeBorder(AppTheme.neonMagenta.opacity(0.55), lineWidth: 0.8))
                    )
            }

            // Input Field Box
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(keyInput.isEmpty ? Color.white.opacity(0.4) : AppTheme.neonCyan)
                    .frame(width: 20)

                TextField("INNOVA-1D-XXXX-XXXX", text: $keyInput)
                    .textInputAutocapitalization(.characters)
                    .autocorrectionDisabled(true)
                    .font(.system(size: 15, weight: .bold, design: .monospaced))
                    .tracking(1.2)
                    .foregroundColor(.white)
                    .submitLabel(.go)
                    .onSubmit { activate() }

                if !keyInput.isEmpty {
                    Button(action: {
                        keyInput = ""
                        errorMessage = nil
                        isError = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Color.white.opacity(0.45))
                            .font(.system(size: 15))
                    }
                }

                // Nút Dán (Paste)
                Button(action: pasteFromClipboard) {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text("DÁN")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                            .tracking(1)
                    }
                    .foregroundColor(AppTheme.neonCyan)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(AppTheme.neonCyan.opacity(0.14))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .strokeBorder(AppTheme.neonCyan.opacity(0.55), lineWidth: 0.8)
                            )
                    )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.55))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AppTheme.neonCyan.opacity(keyInput.isEmpty ? 0.35 : 0.75),
                                AppTheme.neonMagenta.opacity(keyInput.isEmpty ? 0.2 : 0.6)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )

            // HWID Chip View
            hwidChipView

            // Error / Status Message
            if let errorMessage {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: isError ? "exclamationmark.octagon.fill" : "checkmark.seal.fill")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(isError ? AppTheme.neonMagenta : AppTheme.neonLime)
                        .padding(.top, 1)

                    Text(errorMessage)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(isError ? Color(red: 1.0, green: 0.45, blue: 0.65) : AppTheme.neonLime)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill((isError ? AppTheme.neonMagenta : AppTheme.neonLime).opacity(0.12))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder((isError ? AppTheme.neonMagenta : AppTheme.neonLime).opacity(0.45), lineWidth: 0.8)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            AppTheme.neonCyan.opacity(0.4),
                            AppTheme.neonMagenta.opacity(0.2),
                            AppTheme.neonCyan.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .overlay(CyberCornerBrackets(color: AppTheme.neonCyan.opacity(0.55), length: 12, lineWidth: 1.5))
        .shadow(color: AppTheme.neonCyan.opacity(0.15), radius: 16)
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
    }

    // MARK: - HWID Chip

    private var hwidChipView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 11))
                        .foregroundColor(AppTheme.neonIce)
                    Text("MÃ MÁY (HWID):")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(Color.white.opacity(0.75))
                }

                Text(shortHWID)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(AppTheme.neonCyan)

                Spacer()

                Button(action: copyHWID) {
                    HStack(spacing: 3) {
                        Image(systemName: isCopiedHWID ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            .font(.system(size: 10, weight: .bold))
                        Text(isCopiedHWID ? "ĐÃ CHÉP" : "CHÉP")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    }
                    .foregroundColor(isCopiedHWID ? AppTheme.neonLime : Color.white.opacity(0.85))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3.5)
                    .background(
                        Capsule()
                            .fill(isCopiedHWID ? AppTheme.neonLime.opacity(0.2) : Color.white.opacity(0.08))
                            .overlay(
                                Capsule().strokeBorder(
                                    isCopiedHWID ? AppTheme.neonLime.opacity(0.6) : Color.white.opacity(0.2),
                                    lineWidth: 0.8
                                )
                            )
                    )
                }
            }

            Text("Thiết bị: \(DeviceIdentity.displayInfo())")
                .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.45))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
                )
        )
    }

    private var shortHWID: String {
        let s = DeviceIdentity.serial()
        guard s.count > 12 else { return s }
        return "\(s.prefix(6))•••\(s.suffix(6))"
    }

    // MARK: - Action Button

    private var activateButton: some View {
        let isSavedKey = (LicenseStore.loadCachedKey() != nil && LicenseStore.loadCachedKey() == keyInput.trimmingCharacters(in: .whitespacesAndNewlines))
        let canSubmit = !isBusy && !keyInput.trimmingCharacters(in: .whitespaces).isEmpty

        return Button(action: activate) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: canSubmit
                                ? [
                                    AppTheme.neonCyan,
                                    Color(red: 0.40, green: 0.15, blue: 0.95),
                                    AppTheme.neonMagenta
                                ]
                                : [Color.white.opacity(0.12), Color.white.opacity(0.06)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(
                                canSubmit ? AppTheme.neonCyan.opacity(0.6) : Color.white.opacity(0.15),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: canSubmit ? AppTheme.neonCyan.opacity(0.45) : .clear,
                        radius: 14,
                        x: 0,
                        y: 0
                    )

                HStack(spacing: 10) {
                    if isBusy {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                        Text("ĐANG XÁC THỰC VỚI SERVER...")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .tracking(1.5)
                    } else {
                        Image(systemName: isSavedKey ? "arrow.right.circle.fill" : "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                        Text(isSavedKey ? "VÀO TRANG CHỦ INNOVA" : "KÍCH HOẠT HỆ THỐNG")
                            .font(.system(size: 15, weight: .heavy, design: .rounded))
                            .tracking(2)
                    }
                }
                .foregroundColor(canSubmit ? .white : Color.white.opacity(0.4))
                .padding(.vertical, 16)
            }
        }
        .disabled(!canSubmit)
        .animation(.easeInOut(duration: 0.2), value: canSubmit)
    }

    // MARK: - Timeout HUD Bar

    private var timeoutBar: some View {
        VStack(spacing: 6) {
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 11))
                        .foregroundColor(countdownColor)
                    Text("PHIÊN BẢO MẬT TỰ ĐÓNG SAU")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(1)
                        .foregroundColor(Color.white.opacity(0.65))
                }
                Spacer()
                Text("\(remainingSeconds)s")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(countdownColor)
                    .shadow(color: countdownColor.opacity(0.6), radius: 4)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [countdownColor, countdownColor.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * progressRatio))
                        .shadow(color: countdownColor.opacity(0.5), radius: 4)
                }
            }
            .frame(height: 5)

            Text("Ứng dụng tự động thoát nếu không nhập key để đảm bảo an toàn")
                .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.4))
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 4)
    }

    private var countdownColor: Color {
        if remainingSeconds <= 10 {
            return AppTheme.neonMagenta
        } else if remainingSeconds <= 25 {
            return AppTheme.neonAmber
        } else {
            return AppTheme.neonCyan
        }
    }

    private var progressRatio: CGFloat {
        CGFloat(remainingSeconds) / CGFloat(totalTimeoutSeconds)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 8) {
                featurePill(icon: "lock.shield", text: "1 KEY / 1 HWID")
                featurePill(icon: "shield.lefthalf.filled", text: "KERNEL V2.5")
                featurePill(icon: "bolt.badge.checkmark", text: "AUTO BYPASS")
            }

            Button(action: openTelegramSupport) {
                HStack(spacing: 6) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 11))
                    Text("CẦN MUA KEY HOẶC HỖ TRỢ? LIÊN HỆ TELEGRAM")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(0.8)
                }
                .foregroundColor(AppTheme.neonIce.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(
                    Capsule()
                        .fill(Color.white.opacity(0.05))
                        .overlay(Capsule().strokeBorder(AppTheme.neonCyan.opacity(0.25), lineWidth: 0.8))
                )
            }

            Text("// Ứng dụng chỉ chấp nhận License Key INNOVA chính thức")
                .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.3))
        }
    }

    private func featurePill(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(AppTheme.neonCyan)
            Text(text)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundColor(Color.white.opacity(0.65))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.white.opacity(0.04))
                .overlay(RoundedRectangle(cornerRadius: 6, style: .continuous).strokeBorder(Color.white.opacity(0.1), lineWidth: 0.6))
        )
    }

    // MARK: - Lifecycle

    private func handleAppear() {
        if keyInput.isEmpty {
            if let cached = LicenseStore.loadCachedKey(), !cached.isEmpty {
                keyInput = cached
            }
        }
        if remainingSeconds == totalTimeoutSeconds {
            startTimer()
        }
    }

    private func handleDisappear() {
        stopTimer()
    }

    private func startTimer() {
        stopTimer()
        remainingSeconds = totalTimeoutSeconds
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            DispatchQueue.main.async {
                guard !didTriggerTimeout else { return }
                remainingSeconds -= 1
                if remainingSeconds <= 0 {
                    didTriggerTimeout = true
                    stopTimer()
                    exitApp(reason: "Hết thời gian nhập key — ứng dụng đã đóng")
                }
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        guard let clip = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines), !clip.isEmpty else {
            showError("Bộ nhớ tạm đang rỗng!", isError: true)
            return
        }
        keyInput = clip
        errorMessage = nil
        isError = false
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred()
    }

    private func copyHWID() {
        let serial = DeviceIdentity.serial()
        UIPasteboard.general.string = serial
        withAnimation(.easeInOut(duration: 0.2)) {
            isCopiedHWID = true
        }
        let gen = UIImpactFeedbackGenerator(style: .medium)
        gen.prepare()
        gen.impactOccurred()
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isCopiedHWID = false
                }
            }
        }
    }

    private func openTelegramSupport() {
        if let telegramURL = URL(string: "https://t.me/innova_support"), UIApplication.shared.canOpenURL(telegramURL) {
            UIApplication.shared.open(telegramURL)
        } else {
            UIPasteboard.general.string = "@innova_support"
            let gen = UIImpactFeedbackGenerator(style: .medium)
            gen.prepare()
            gen.impactOccurred()
            showError("Đã sao chép Telegram: @innova_support", isError: false)
        }
    }

    private func activate() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            showError("Vui lòng nhập license key", isError: true)
            return
        }
        guard !isBusy else { return }

        isBusy = true
        errorMessage = nil

        Task {
            do {
                let serial = DeviceIdentity.serial()
                let status = try await PatchHubService.activate(key: trimmed, deviceSerial: serial)
                await MainActor.run {
                    LicenseStore.shared.setBuildBlocked(false)
                    LicenseStore.shared.save(key: trimmed, status: status)
                    self.isBusy = false
                    self.didTriggerTimeout = true
                    self.stopTimer()
                    self.errorMessage = "✓ Xác thực thành công — Chào mừng bạn vào INNOVA!"
                    self.isError = false
                    let gen = UINotificationFeedbackGenerator()
                    gen.prepare()
                    gen.notificationOccurred(.success)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        self.onUnlock()
                    }
                }
            } catch let err as LicenseKeyError {
                await MainActor.run {
                    if !Self.isTransientKeyError(err) {
                        Task.detached(priority: .userInitiated) {
                            DevicePatchService.restoreAllAppliedPatches()
                        }
                    }
                    switch err {
                    case .buildRevoked, .buildUnknown, .buildMissing, .buildWrongPlatform:
                        LicenseStore.shared.setBuildBlocked(true)
                    default:
                        break
                    }
                    self.isBusy = false
                    self.showError(err.errorDescription ?? "Key không hợp lệ", isError: true)
                }
            } catch {
                await MainActor.run {
                    self.isBusy = false
                    self.showError("Lỗi kết nối máy chủ: \(error.localizedDescription)", isError: true)
                }
            }
        }
    }

    private func showError(_ message: String, isError: Bool) {
        self.errorMessage = message
        self.isError = isError
        if isError {
            let gen = UIImpactFeedbackGenerator(style: .heavy)
            gen.prepare()
            gen.impactOccurred(intensity: 0.85)
        }
    }

    private func exitApp(reason: String) {
        NSLog("[LicenseGate] exit: \(reason)")
        exit(0)
    }

    private static func isTransientKeyError(_ error: LicenseKeyError) -> Bool {
        switch error {
        case .internalError, .missingKey, .invalidResponse:
            return true
        case .keyNotFound, .revoked, .expired, .notActivated,
             .deviceLimitReached, .deviceNotBound,
             .buildMissing, .buildRevoked, .buildUnknown, .buildWrongPlatform,
             .innovaKeyRequired, .proxyKeyNotAllowed:
            return false
        }
    }
}

// MARK: - Cyber Corner Brackets

private struct CyberCornerBrackets: View {
    var color: Color = AppTheme.neonCyan.opacity(0.6)
    var length: CGFloat = 12
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            Path { path in
                let w = geo.size.width
                let h = geo.size.height

                // Top-Left
                path.move(to: CGPoint(x: 0, y: length))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: length, y: 0))

                // Top-Right
                path.move(to: CGPoint(x: w - length, y: 0))
                path.addLine(to: CGPoint(x: w, y: 0))
                path.addLine(to: CGPoint(x: w, y: length))

                // Bottom-Left
                path.move(to: CGPoint(x: 0, y: h - length))
                path.addLine(to: CGPoint(x: 0, y: h))
                path.addLine(to: CGPoint(x: length, y: h))

                // Bottom-Right
                path.move(to: CGPoint(x: w - length, y: h))
                path.addLine(to: CGPoint(x: w, y: h))
                path.addLine(to: CGPoint(x: w, y: h - length))
            }
            .stroke(color, lineWidth: lineWidth)
        }
    }
}
