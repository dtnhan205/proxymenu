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

                    Image(systemName: "key.fill")
                        .font(.system(size: 34, weight: .semibold))
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
                        .shadow(color: Color(red: 0.0, green: 0.94, blue: 1.0).opacity(0.8), radius: 10)
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
        guard let key = store.savedKey, !key.isEmpty else {
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

        do {
            let serial = DeviceIdentity.serial()
            let status = try await PatchHubService.verifyKey(key: key, deviceSerial: serial)
            await MainActor.run {
                // Verify OK → build token hợp lệ. Clear block flag nếu có.
                store.setBuildBlocked(false)
                // Cập nhật lại key và status mới nhất từ server vào cache
                store.save(key: key, status: status)
                autoVerifySuccess = true
                if isVideoFinished {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        gateDecision = .unlocked
                    }
                }
            }
        } catch let error as LicenseKeyError {
            Task.detached(priority: .userInitiated) {
                DevicePatchService.restoreAllAppliedPatches()
            }
            switch error {
            case .buildRevoked, .buildUnknown, .buildMissing:
                await MainActor.run {
                    store.setBuildBlocked(true)
                }
            default:
                await MainActor.run {
                    store.clear()
                }
            }
            await MainActor.run {
                autoVerifySuccess = false
                if isVideoFinished {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        gateDecision = .needsKey
                    }
                }
            }
        } catch {
            // Lỗi mạng hoặc server không phản hồi kịp thời:
            // Kiểm tra nếu key đã lưu cục bộ còn hạn sử dụng
            let isLocallyValid = (store.expiresAt == nil || store.expiresAt! > Date())
            await MainActor.run {
                if isLocallyValid {
                    autoVerifySuccess = true
                    if isVideoFinished {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            gateDecision = .unlocked
                        }
                    }
                } else {
                    autoVerifySuccess = false
                    if isVideoFinished {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            gateDecision = .needsKey
                        }
                    }
                }
            }
        }
    }
}
