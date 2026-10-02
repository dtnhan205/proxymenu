import SwiftUI

/// Cửa sổ nhập key — là root view cho tới khi xác thực thành công.
/// - 1 phút không nhập / không bấm gì → thoát app.
/// - Sai key / hết hạn / bị khoá → thông báo + không cho vào.
/// - Đúng key → `onUnlock` chạy, view cha chuyển sang `ContentView`.
struct LicenseGateView: View {

    /// Callback khi key hợp lệ — view cha đổi sang root app chính.
    var onUnlock: () -> Void

    @State private var keyInput: String = ""
    @State private var isBusy: Bool = false
    @State private var errorMessage: String?
    @State private var isError: Bool = false
    @State private var remainingSeconds: Int = 60
    @State private var didTriggerTimeout: Bool = false

    private let totalTimeoutSeconds: Int = 60

    var body: some View {
        content
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

    // MARK: - Layout

    private var content: some View {
        VStack(spacing: 28) {
            Spacer().frame(height: 12)
            header
            inputCard
            activateButton
            statusLine
            timeoutBar
            Spacer()
            footer
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 36)
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.94, blue: 1.0),
                                Color(red: 1.0, green: 0.0, blue: 0.83)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                    .frame(width: 96, height: 96)
                Image(systemName: "key.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.94, blue: 1.0),
                                Color(red: 1.0, green: 0.0, blue: 0.83)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(red: 0.0, green: 0.94, blue: 1.0).opacity(0.7), radius: 8)
            }

            Text("KEY AUTH")
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .tracking(4)
                .foregroundColor(Color(red: 0.0, green: 0.94, blue: 1.0))
                .shadow(color: Color(red: 0.0, green: 0.94, blue: 1.0).opacity(0.55), radius: 10)

            Text("Nhập license key INNOVA để mở khoá ứng dụng")
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(Color(white: 0.6))
                .multilineTextAlignment(.center)
        }
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("INNOVA.KEY")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .tracking(2)
                .foregroundColor(Color(white: 0.55))

            TextField("INNOVA-1D-XXXX-XXXX", text: $keyInput)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled(true)
                .font(.system(size: 16, weight: .medium, design: .monospaced))
                .tracking(1.5)
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.05))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.0, green: 0.94, blue: 1.0).opacity(0.7),
                                            Color(red: 1.0, green: 0.0, blue: 0.83).opacity(0.7)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                )
                .submitLabel(.go)
                .onSubmit { activate() }

            if let errorMessage {
                Text(errorMessage)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundColor(
                        isError
                            ? Color(red: 1.0, green: 0.24, blue: 0.55)
                            : Color(red: 0.24, green: 1.0, blue: 0.65)
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: errorMessage)
    }

    private var activateButton: some View {
        let isSavedKey = (LicenseStore.loadCachedKey() != nil && LicenseStore.loadCachedKey() == keyInput.trimmingCharacters(in: .whitespacesAndNewlines))
        return Button(action: activate) {
            HStack(spacing: 10) {
                if isBusy {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                }
                Text(isBusy ? "ĐANG XÁC THỰC…" : (isSavedKey ? "⚡ VÀO TRANG CHỦ" : "⚡ KÍCH HOẠT"))
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .tracking(2)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.0, green: 0.94, blue: 1.0).opacity(0.95),
                                Color(red: 1.0, green: 0.0, blue: 0.83).opacity(0.95)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .shadow(color: Color(red: 0.0, green: 0.94, blue: 1.0).opacity(0.5), radius: 14, x: 0, y: 0)
            )
        }
        .disabled(isBusy || keyInput.trimmingCharacters(in: .whitespaces).isEmpty)
        .opacity((isBusy || keyInput.trimmingCharacters(in: .whitespaces).isEmpty) ? 0.55 : 1.0)
    }

    private var statusLine: some View {
        Text("Thiết bị: \(DeviceIdentity.displayInfo())")
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundColor(Color(white: 0.4))
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private var timeoutBar: some View {
        VStack(spacing: 6) {
            HStack {
                Text("Tự đóng sau")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(Color(white: 0.55))
                Spacer()
                Text("\(remainingSeconds)s")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(
                        remainingSeconds <= 10
                            ? Color(red: 1.0, green: 0.24, blue: 0.55)
                            : Color(red: 0.96, green: 1.0, blue: 0.24)
                    )
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.0, green: 0.94, blue: 1.0),
                                    Color(red: 1.0, green: 0.0, blue: 0.83)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * progressRatio)
                }
            }
            .frame(height: 4)
        }
        .padding(.horizontal, 4)
    }

    private var footer: some View {
        Text("// Mỗi key chỉ dùng được 1 thiết bị cố định\n// Ứng dụng chỉ chấp nhận Key INNOVA\n// Liên hệ admin để được hỗ trợ key")
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundColor(Color(white: 0.35))
            .multilineTextAlignment(.center)
    }

    // MARK: - State

    private var progressRatio: CGFloat {
        CGFloat(remainingSeconds) / CGFloat(totalTimeoutSeconds)
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

    @State private var timer: Timer?

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
                    self.errorMessage = "✓ Xác thực thành công"
                    self.isError = false
                    self.onUnlock()
                }
            } catch let err as LicenseKeyError {
                await MainActor.run {
                    // Key invalid khi user nhập key mới (key cũ còn cache) →
                    // revert mọi patch đang apply trước khi thử khóa lại.
                    // Bám sát logic RootView: bất kỳ LicenseKeyError nào
                    // (trừ internalError / missingKey / invalidResponse là
                    // lỗi mạng) đều nghĩa là key cũ không còn dùng được.
                    // Chạy detached để không block main thread khi revert.
                    if !Self.isTransientKeyError(err) {
                        Task.detached(priority: .userInitiated) {
                            DevicePatchService.restoreAllAppliedPatches()
                        }
                    }
                    // Build bị revoke/unknown → bật overlay (RootView sẽ phủ).
                    // Không cho phép nhập lại key khác để bypass; user buộc
                    // phải cập nhật app.
                    switch err {
                    case .buildRevoked, .buildUnknown, .buildMissing:
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
                    self.showError("Lỗi mạng: \(error.localizedDescription)", isError: true)
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

    /// Phân biệt lỗi "key thật sự không hợp lệ" (cần revert patch) với
    /// lỗi tạm thời (mất mạng / server lỗi / key rỗng). Lỗi tạm thời
    /// KHÔNG revert — chưa chắc key invalid, chỉ là request thất bại.
    /// Nếu revert nhầm khi mạng chập chờn, user sẽ mất quyền dùng patch
    /// cho đến khi nhập lại key dù key vẫn còn hạn.
    private static func isTransientKeyError(_ error: LicenseKeyError) -> Bool {
        switch error {
        case .internalError, .missingKey, .invalidResponse:
            return true
        case .keyNotFound, .revoked, .expired, .notActivated,
             .deviceLimitReached, .deviceNotBound,
             .buildMissing, .buildRevoked, .buildUnknown,
             .innovaKeyRequired, .proxyKeyNotAllowed:
            return false
        }
    }
}
