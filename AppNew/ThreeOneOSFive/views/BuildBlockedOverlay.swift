import SwiftUI

/// Overlay phủ toàn màn hình khi server trả `build_revoked` / `build_unknown`.
/// Block toàn bộ tương tác — không có nút đóng, không thể bấm ra ngoài.
/// Persist qua UserDefaults nên thoát ra vào lại vẫn thấy cho tới khi admin
/// add token mới trên server.
///
/// Khi admin ACTIVE lại token trên `/admin/builds` → user paste key + bấm
/// "Activate" ngay tại đây → `PatchHubService.activate` → server trả OK →
/// `setBuildBlocked(false)` → RootView tự ẩn overlay → gate hiện ra.
struct BuildBlockedOverlay: View {
    @State private var pulse = false
    @State private var keyInput: String = ""
    @State private var isBusy = false
    @State private var inlineError: String?

    var body: some View {
        ZStack {
            Color.black.opacity(0.92)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 64, weight: .bold))
                        .foregroundStyle(.yellow)
                        .scaleEffect(pulse ? 1.08 : 0.96)
                        .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: pulse)
                        .padding(.top, 24)

                    Text(LocalizedStringKey("build.blocked_title"))
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)

                    Text(LocalizedStringKey("build.blocked_body"))
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text(LocalizedStringKey("build.blocked_hint"))
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    // Vùng nhập key — cho phép user activate lại sau khi
                    // admin đã bật lại token trên server, không cần reinstall.
                    VStack(spacing: 10) {
                        TextField("INNOVA-1D-XXXX-XXXX", text: $keyInput)
                            .textInputAutocapitalization(.characters)
                            .autocorrectionDisabled(true)
                            .font(.system(size: 15, weight: .medium, design: .monospaced))
                            .tracking(1.2)
                            .foregroundColor(.white)
                            .padding(.vertical, 12)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.white.opacity(0.06))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                                    )
                            )

                        Button(action: retryActivation) {
                            HStack(spacing: 8) {
                                if isBusy {
                                    ProgressView()
                                        .progressViewStyle(.circular)
                                        .tint(.white)
                                }
                                Text(isBusy ? "Đang xác thực…" : "Kích hoạt lại")
                                    .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                    .tracking(1.5)
                                    .foregroundColor(.white)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                LinearGradient(
                                    colors: [Color(red: 0.0, green: 0.7, blue: 1.0), Color(red: 0.6, green: 0.1, blue: 0.95)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .opacity(isBusy || keyInput.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                        }
                        .disabled(isBusy || keyInput.trimmingCharacters(in: .whitespaces).isEmpty)

                        if let err = inlineError {
                            Text(err)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.red.opacity(0.85))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 14)
                }
                .padding(.bottom, 40)
            }
        }
        .onAppear { pulse = true }
        .allowsHitTesting(true)
    }

    private func retryActivation() {
        let trimmed = keyInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isBusy else { return }
        inlineError = nil
        isBusy = true
        Task {
            do {
                let serial = DeviceIdentity.serial()
                let status = try await PatchHubService.activate(key: trimmed, deviceSerial: serial)
                await MainActor.run {
                    LicenseStore.shared.setBuildBlocked(false)
                    LicenseStore.shared.save(key: trimmed, status: status)
                    Task {
                        try? await FreeFirePatchService.downloadAndPreparePayload()
                    }
                    isBusy = false
                    keyInput = ""
                }
            } catch let err as LicenseKeyError {
                await MainActor.run {
                    isBusy = false
                    switch err {
                    case .buildRevoked, .buildUnknown, .buildMissing, .buildWrongPlatform:
                        inlineError = "Token vẫn chưa được kích hoạt trên máy chủ. Vui lòng liên hệ admin."
                    default:
                        inlineError = err.errorDescription ?? "Key không hợp lệ"
                    }
                }
            } catch {
                await MainActor.run {
                    isBusy = false
                    inlineError = "Lỗi mạng: \(error.localizedDescription)"
                }
            }
        }
    }
}
