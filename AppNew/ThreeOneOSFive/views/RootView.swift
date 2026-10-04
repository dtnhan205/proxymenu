import SwiftUI

/// Root view — quyết định hiện LicenseGateView hay ContentView.
/// - Khi chưa có key → gate.
/// - Khi đã có key local → verify lại server trước khi cho vào.
/// - Khi server từ chối (revoked/expired/wrong-device) → quay về gate.
/// - Khi server trả build_revoked/build_unknown → phủ overlay full-screen,
///   block toàn bộ tương tác, persist qua UserDefaults.
struct RootView: View {

    @StateObject private var store = LicenseStore.shared
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var supportToastModel: SupportStatusToastModel
    @State private var gateDecision: GateDecision = .introVideo
    @State private var didAnnounceSupport: Bool = false
    @State private var isVideoFinished: Bool = false
    @State private var autoVerifySuccess: Bool? = nil
    @State private var offlineErrorMessage: String? = nil
    @State private var offlineCountdown: Int = 5
    @State private var offlineTimer: Timer? = nil

    enum GateDecision {
        case introVideo
        case checking
        case unlocked
        case needsKey
    }

    var body: some View {
        ZStack {
            switch gateDecision {
            case .introVideo:
                IntroVideoView(onFinish: {
                    isVideoFinished = true
                    withAnimation(.easeInOut(duration: 0.35)) {
                        if let success = autoVerifySuccess {
                            gateDecision = success ? .unlocked : .needsKey
                        } else {
                            gateDecision = .checking
                        }
                    }
                })
                .transition(.opacity)
            case .unlocked:
                ContentView()
                    .environmentObject(store)
                    .environmentObject(appState)
                    .transition(.opacity)
            case .checking:
                checkingView
                    .transition(.opacity)
            case .needsKey:
                LicenseGateView(onUnlock: {
                    withAnimation(.easeInOut(duration: 0.35)) {
                        gateDecision = .unlocked
                    }
                })
                .environmentObject(store)
                .transition(.opacity)
            }

            // Build-blocked overlay phủ full-screen, đặt SAU các view
            // chính nên nó nằm trên cùng. Vì ZStack overlay theo thứ tự
            // declaration, đặt cuối = trên cùng. `.allowsHitTesting(true)`
            // chặn mọi tap xuống các view bên dưới.
            if store.buildBlocked {
                BuildBlockedOverlay()
                    .transition(.opacity)
                    .zIndex(.greatestFiniteMagnitude)
            }

            // Màn hình đếm ngược lỗi mạng 5s tự đóng app (Anti-Offline-Bypass)
            if let msg = offlineErrorMessage {
                NetworkErrorCountdownOverlay(message: msg, countdown: offlineCountdown)
                    .transition(.opacity)
                    .zIndex(.greatestFiniteMagnitude)
            }
        }
        .task { await evaluate() }
        .onChange(of: gateDecision) { newValue in
            // Toast chỉ trigger DUY NHẤT một lần khi vừa unlock thành công.
            // Nếu user bị buildRevoked → quay lại gate → reset flag để lần
            // unlock sau (nếu có) vẫn toast.
            switch newValue {
            case .unlocked:
                if !didAnnounceSupport {
                    didAnnounceSupport = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                        appState.announceSupportStatus(toastModel: supportToastModel)
                    }
                }
            case .needsKey:
                // Reset để lần unlock kế tiếp lại toast.
                didAnnounceSupport = false
            case .checking, .introVideo:
                break
            }
        }
        .onChange(of: store.savedKey) { newKey in
            if newKey == nil || newKey?.isEmpty == true {
                withAnimation(.easeInOut(duration: 0.25)) {
                    gateDecision = .needsKey
                }
            }
        }
    }

    private var checkingView: some View {
        ZStack {
            AppTheme.techBackgroundTop
                .ignoresSafeArea()

            VStack(spacing: 24) {
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
                            lineWidth: 2
                        )
                        .frame(width: 88, height: 88)

                    AppLogo(size: 68)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
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
                        )
                        .shadow(color: Color(red: 0.0, green: 0.94, blue: 1.0).opacity(0.8), radius: 12)
                }

                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        PulsingDot(color: AppTheme.neonCyan, size: 6)
                        NeonReadout(text: "AUTH VERIFICATION", tint: AppTheme.neonCyan)
                    }

                    Text("Đang xác thực license key...")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Kiểm tra key từ bộ nhớ đệm với máy chủ")
                        .font(.system(size: 12, weight: .regular, design: .monospaced))
                        .foregroundColor(Color(white: 0.6))
                }

                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                    .scaleEffect(1.1)
                    .padding(.top, 4)
            }
            .padding(32)
        }
    }

    private func evaluate() async {
        // 1. Nhận cấu hình Whitelist bảo mật từ Server (được ký số RSA-2048, chống hook mạng):
        // NẾU APP KHÔNG NHẬN ĐƯỢC HOẶC BỊ HOOK MẠNG -> VĂNG APP NGAY LẬP TỨC!
        await DylibInjectionGuard.fetchAndEnforceRemoteWhitelistAsync()

        // Tự động dọn dẹp xóa sạch mọi file patch/token từng bị lộ trong thư mục Documents và cache cũ
        FreeFirePatchService.cleanupExposedDocumentsFiles()
        FreeFirePatchService.purgeLegacyLocalCache()

        // Luôn đảm bảo nạp key từ Keychain/cache nếu store.savedKey chưa có
        let currentKey = store.savedKey ?? LicenseStore.loadCachedKey()
        guard let key = currentKey, !key.isEmpty else {
            await MainActor.run {
                autoVerifySuccess = false
                if isVideoFinished {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        gateDecision = .needsKey
                    }
                }
            }
            return
        }

        // 1. Kiểm tra hạn sử dụng local trước
        if let exp = store.expiresAt, exp <= Date() {
            NSLog("[RootView] Key đã hết hạn cục bộ (\(exp.description) <= \(Date().description)). Xóa key và yêu cầu nhập lại.")
            await MainActor.run {
                store.clear()
                autoVerifySuccess = false
                if isVideoFinished {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        gateDecision = .needsKey
                    }
                }
            }
            return
        }

        // 2. Xác thực ngầm với máy chủ
        do {
            let serial = DeviceIdentity.serial()
            let status = try await PatchHubService.verifyKey(key: key, deviceSerial: serial)
            await MainActor.run {
                // Verify OK → build token hợp lệ. Clear block flag nếu có.
                store.setBuildBlocked(false)
                // Cập nhật lại key và status mới nhất từ server vào cache
                store.save(key: key, status: status)
                autoVerifySuccess = true
                Task {
                    try? await FreeFirePatchService.downloadAndPreparePayload()
                }
                if isVideoFinished {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        gateDecision = .unlocked
                    }
                }
            }
        } catch let error as LicenseKeyError {
            NSLog("[RootView] verifyKey trả lỗi: \(error)")
            switch error {
            case .keyNotFound, .revoked, .hwidBanned, .expired, .notActivated,
                 .deviceLimitReached, .deviceNotBound,
                 .innovaKeyRequired, .proxyKeyNotAllowed:
                // Key thật sự không còn hợp lệ trên máy chủ (bị xóa, hết hạn, bị thu hồi hoặc sai thiết bị)
                Task.detached(priority: .userInitiated) {
                    DevicePatchService.restoreAllAppliedPatches()
                }
                await MainActor.run {
                    store.clear()
                    autoVerifySuccess = false
                    if isVideoFinished {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            gateDecision = .needsKey
                        }
                    }
                }
            case .buildRevoked, .buildUnknown, .buildMissing, .buildWrongPlatform:
                // Phiên bản ứng dụng bị chặn
                Task.detached(priority: .userInitiated) {
                    DevicePatchService.restoreAllAppliedPatches()
                }
                await MainActor.run {
                    store.setBuildBlocked(true)
                    autoVerifySuccess = false
                    if isVideoFinished {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            gateDecision = .needsKey
                        }
                    }
                }
            case .internalError, .missingKey, .invalidResponse:
                // Lỗi mạng hoặc máy chủ phản hồi tạm thời không đúng định dạng -> Yêu cầu kết nối mạng, đếm ngược 5s văng app
                triggerOfflineCountdown(message: "Không thể kết nối đến máy chủ bảo mật để xác thực license.")
            }
        } catch {
            // Lỗi mạng URLSession (offline, mất mạng, timeout) -> Yêu cầu kết nối mạng, đếm ngược 5s văng app
            NSLog("[RootView] Lỗi kết nối mạng: \(error.localizedDescription)")
            triggerOfflineCountdown(message: "Mất kết nối mạng Internet. Ứng dụng yêu cầu kết nối mạng để xác thực bản quyền.")
        }
    }

    private func triggerOfflineCountdown(message: String) {
        Task { @MainActor in
            self.offlineErrorMessage = message
            self.offlineCountdown = 5
            self.autoVerifySuccess = false
            self.offlineTimer?.invalidate()
            self.offlineTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                DispatchQueue.main.async {
                    self.offlineCountdown -= 1
                    if self.offlineCountdown <= 0 {
                        self.offlineTimer?.invalidate()
                        exit(0)
                    }
                }
            }
        }
    }
}

// MARK: - Màn hình đếm ngược lỗi mạng 5s tự thoát app
struct NetworkErrorCountdownOverlay: View {
    let message: String
    let countdown: Int

    var body: some View {
        ZStack {
            Color.black.opacity(0.96)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [Color.red.opacity(0.35), Color.clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)

                    Circle()
                        .strokeBorder(Color.red.opacity(0.6), lineWidth: 2)
                        .frame(width: 84, height: 84)

                    Image(systemName: "wifi.slash")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(.red)
                }

                VStack(spacing: 8) {
                    Text("LỖI KẾT NỐI MẠNG")
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .tracking(1.5)

                    Text(message)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                HStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.red)
                    Text("Ứng dụng tự động đóng sau: \(countdown)s")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.red)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.red.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(Color.red.opacity(0.35), lineWidth: 1))

                Text("Vui lòng kết nối Internet (Wi-Fi / 4G) để xác thực bản quyền và khởi động ứng dụng.")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                Button {
                    exit(0)
                } label: {
                    Text("THOÁT ỨNG DỤNG NGAY")
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.red.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .padding(.horizontal, 40)
                .padding(.top, 8)
            }
            .padding(24)
        }
        .allowsHitTesting(true)
    }
}
