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
    @State private var gateDecision: GateDecision = .checking
    @State private var didAnnounceSupport: Bool = false

    enum GateDecision {
        case checking
        case unlocked
        case needsKey
    }

    var body: some View {
        ZStack {
            switch gateDecision {
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
                    withAnimation(.easeInOut(duration: 0.3)) {
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
            case .checking:
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
                withAnimation(.easeInOut(duration: 0.25)) {
                    gateDecision = .needsKey
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
                withAnimation(.easeInOut(duration: 0.3)) {
                    gateDecision = .unlocked
                }
            }
        } catch let error as LicenseKeyError {
            // Key không còn hợp lệ (hết hạn / bị revoke / sai thiết bị /
            // build bị admin revoke). Trước khi chuyển về gate, REVERT MỌI
            // patch đang active trên disk về file gốc để:
            //   - Tắt hoàn toàn chức năng patch (đúng yêu cầu "tự động tắt").
            //   - Không để app rơi vào trạng thái nửa vời: file đã patch vẫn
            //     nằm trên thiết bị nhưng key đã mất → rò rỉ nội dung.
            //   - User gia hạn key → toggle sẽ tự apply lại từ cùng project.
            // Chạy detached để không block main actor (nhiều project + file I/O).
            Task.detached(priority: .userInitiated) {
                DevicePatchService.restoreAllAppliedPatches()
            }

            // Build bị revoke / unknown → bật overlay và KHÔNG clear key.
            // User vẫn thấy overlay kể cả khi restart app.
            switch error {
            case .buildRevoked, .buildUnknown, .buildMissing:
                await MainActor.run {
                    store.setBuildBlocked(true)
                    withAnimation(.easeInOut(duration: 0.25)) {
                        gateDecision = .needsKey
                    }
                }
                return
            default:
                break
            }
            // Verify fail (key hết hạn, bị thu hồi, sai thiết bị...) — xoá key local trong cache, đẩy về gate để nhập key mới.
            await MainActor.run {
                store.clear()
                withAnimation(.easeInOut(duration: 0.25)) {
                    gateDecision = .needsKey
                }
            }
        } catch {
            // Verify fail (lỗi kết nối hoặc lỗi server) — KHÔNG revert patch
            // (chưa chắc key invalid, chỉ là mất mạng). Vẫn xoá key local và
            // đẩy về gate để user nhập lại — re-evaluate lần sau sẽ verify lại.
            await MainActor.run {
                store.clear()
                withAnimation(.easeInOut(duration: 0.25)) {
                    gateDecision = .needsKey
                }
            }
        }
    }
}
