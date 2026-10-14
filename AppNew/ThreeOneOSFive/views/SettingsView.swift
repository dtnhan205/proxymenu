import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue
    @ObservedObject private var vpnManager = LocalDevVPNManager.shared
    @ObservedObject private var pairingAdvertiser = RemotePairingAdvertiser.shared
    @State private var showPairingPromptAlert = false
    @State private var showPairingSheet = false
    @State private var showVPNAlert = false
    @State private var vpnAlertTitle = ""
    @State private var vpnAlertMessage = ""
    @State private var showShareLogSheet = false

    var body: some View {
        ZStack {
            // Nền ảnh được paint ở App.swift (Image("Background") trong ZStack
            // gốc của WindowGroup) → đã phủ kín mọi màn hình, không cần
            // TechBackground() riêng cho Settings.

            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        profileCard
                        ios27PairingCard
                        languageCard
                        deviceCard
                        compatibilityCard

                        Text(language.text("settings.supported_versions_footer"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, AppTheme.pageInset)
                    .padding(.vertical, 16)
                }
                .scrollContentBackgroundCompat()
                .scrollDismissesKeyboardCompat()
                .appBackground()
                .navigationTitle(language.text("settings.title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(AppTheme.techBackgroundTop.opacity(0.85), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(language.text("common.done")) { dismiss() }
                            .fontWeight(.semibold)
                            .foregroundStyle(AppTheme.neonCyan)
                            .shadow(color: AppTheme.neonCyan.opacity(0.55), radius: 6)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .preferredColorScheme(.dark)
        .alert(vpnAlertTitle, isPresented: $showVPNAlert) {
            Button("Mở Cài Đặt iPhone") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(language.text("common.ok"), role: .cancel) {}
        } message: {
            Text(vpnAlertMessage)
        }
        .alert("Ghép đôi iOS 27", isPresented: $showPairingPromptAlert) {
            Button("Huỷ", role: .cancel) {}
            Button("Bắt đầu") {
                pairingAdvertiser.startAdvertising()
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
        } message: {
            Text("Trên iPhone: Cài đặt -> Quyền riêng tư & Bảo mật -> Chế độ nhà phát triển -> mục 'Ghép với INNOVA CHEAT'. Hoặc bạn có thể bấm 'Tạo File Trực Tiếp' trong cửa sổ ghép đôi để hoàn tất ngay trên máy.")
        }
        .sheet(isPresented: $showPairingSheet) {
            RemotePairingSheetView()
        }
        .sheet(isPresented: $showShareLogSheet) {
            ShareSheet(activityItems: [AppLog.shared.exportLogURL()])
        }
    }

    // MARK: - Cards

    private var profileCard: some View {
        HStack(spacing: 14) {
            AppLogo(size: 56)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    PulsingDot(color: AppTheme.neonCyan, size: 6)
                    NeonReadout(text: "TheNhanCheat", tint: AppTheme.neonCyan)
                }
                Text(bundleDisplayName)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.primary)
                Text(language.text("common.version", appVersion))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Image(systemName: "qrcode")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.neonMagenta)
                .frame(width: 40, height: 40)
                .background(AppTheme.neonMagenta.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AppTheme.neonMagenta.opacity(0.55), lineWidth: 1)
                )
                .shadow(color: AppTheme.neonMagenta.opacity(0.45), radius: 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard(glow: AppTheme.neonCyan, opacity: 0.18)
    }

    // MARK: - iOS 27 Pairing & Tunnel Card (Gọn gàng & Trực quan)
    private var ios27PairingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Icon + Tiêu đề + Trạng thái tổng thể
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.neonLime)
                NeonReadout(text: "Ghép Đôi & Tunnel (iOS 27)", tint: AppTheme.neonLime)

                Spacer()

                overallStatusPill
            }

            // Grid trạng thái 2 cột: [Ghép Đôi] và [LocalDevVPN]
            HStack(spacing: 10) {
                // Ô 1: Trạng thái ghép đôi (Pairing)
                statusBox(
                    icon: pairingAdvertiser.hasExistingPairing ? "checkmark.seal.fill" : "link.badge.plus",
                    iconColor: pairingAdvertiser.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonAmber,
                    title: "GHÉP ĐÔI",
                    subtitle: pairingAdvertiser.hasExistingPairing ? "Đã có Pairing File" : (pairingAdvertiser.isAdvertising ? "Đang phát sóng..." : "Chưa ghép đôi"),
                    isPositive: pairingAdvertiser.hasExistingPairing
                )

                // Ô 2: Trạng thái LocalDevVPN
                statusBox(
                    icon: vpnManager.isConnected ? "network" : "network.slash",
                    iconColor: vpnManager.isConnected ? AppTheme.neonLime : AppTheme.neonMagenta,
                    title: "LOCALDEV VPN",
                    subtitle: vpnManager.isConnected ? "10.7.0.1 (Đã bật)" : "Chưa kết nối VPN",
                    isPositive: vpnManager.isConnected
                )
            }

            // Nút bấm chính mở Trung Tâm Ghép Đôi / Test Inject
            Button {
                handlePairingTap()
            } label: {
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.black.opacity(0.2))
                            .frame(width: 36, height: 36)

                        Image(systemName: pairingAdvertiser.hasExistingPairing ? "slider.horizontal.3" : "bolt.fill")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.black)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(pairingAdvertiser.hasExistingPairing
                            ? "TRUNG TÂM GHÉP ĐÔI & TEST MOD"
                            : "KÍCH HOẠT GHÉP ĐÔI iOS 27")
                            .font(.footnote.weight(.bold))
                            .foregroundStyle(.black)

                        Text(pairingAdvertiser.hasExistingPairing
                            ? "Xem nhật ký live, test inject hoặc sửa lỗi kết nối"
                            : "Bấm để phát sóng mã PIN hoặc tạo file trực tiếp")
                            .font(.caption2)
                            .foregroundStyle(Color.black.opacity(0.8))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color.black.opacity(0.6))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    LinearGradient(
                        colors: pairingAdvertiser.hasExistingPairing
                            ? [AppTheme.neonLime, AppTheme.neonCyan]
                            : [AppTheme.neonCyan, AppTheme.neonLime],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                )
                .shadow(
                    color: (pairingAdvertiser.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.4),
                    radius: 8,
                    y: 2
                )
            }
            .buttonStyle(.plain)

            // Hàng 3 nút phím tắt tiện ích nhanh
            HStack(spacing: 8) {
                // Phím tắt 1: Mở LocalDevVPN
                quickShortcutButton(
                    icon: "network",
                    label: "Mở VPN",
                    tint: vpnManager.isConnected ? AppTheme.neonLime : AppTheme.neonCyan
                ) {
                    if let url = URL(string: "localdevvpn://"), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else if let store = URL(string: "https://apps.apple.com/app/id6738344641") {
                        UIApplication.shared.open(store)
                    }
                }

                // Phím tắt 2: Mở Apple Books (Sách)
                quickShortcutButton(
                    icon: "book.closed.fill",
                    label: "Mở Sách",
                    tint: Color.orange
                ) {
                    if let url = URL(string: "ibooks://"), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else if let storeURL = URL(string: "https://apps.apple.com/app/apple-books/id364709193") {
                        UIApplication.shared.open(storeURL)
                    }
                }

                // Phím tắt 3: Mở Cài Đặt iPhone
                quickShortcutButton(
                    icon: "gearshape.fill",
                    label: "Cài Đặt",
                    tint: .secondary
                ) {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
            }

            // Nút Xuất file log.txt để chia sẻ hoặc gửi phân tích
            Button {
                AppLog.shared.flush()
                showShareLogSheet = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up.circle.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(AppTheme.neonLime)
                    Text("Xuất file log.txt (Gửi phân tích)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.45))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AppTheme.neonLime.opacity(0.3), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard(
            glow: (pairingAdvertiser.hasExistingPairing && vpnManager.isConnected) ? AppTheme.neonLime : AppTheme.neonCyan,
            opacity: 0.15
        )
    }

    private var overallStatusPill: some View {
        HStack(spacing: 5) {
            PulsingDot(
                color: (pairingAdvertiser.hasExistingPairing && vpnManager.isConnected)
                    ? AppTheme.neonLime
                    : (pairingAdvertiser.hasExistingPairing ? AppTheme.neonCyan : AppTheme.neonAmber),
                size: 6
            )
            Text((pairingAdvertiser.hasExistingPairing && vpnManager.isConnected)
                ? "SẴN SÀNG"
                : (pairingAdvertiser.hasExistingPairing ? "ĐÃ GHÉP ĐÔI" : "CHƯA SẴN SÀNG"))
                .font(.caption2.weight(.bold))
                .foregroundStyle((pairingAdvertiser.hasExistingPairing && vpnManager.isConnected)
                    ? AppTheme.neonLime
                    : (pairingAdvertiser.hasExistingPairing ? AppTheme.neonCyan : AppTheme.neonAmber))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            ((pairingAdvertiser.hasExistingPairing && vpnManager.isConnected)
                ? AppTheme.neonLime
                : (pairingAdvertiser.hasExistingPairing ? AppTheme.neonCyan : AppTheme.neonAmber)).opacity(0.12),
            in: Capsule()
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    ((pairingAdvertiser.hasExistingPairing && vpnManager.isConnected)
                        ? AppTheme.neonLime
                        : (pairingAdvertiser.hasExistingPairing ? AppTheme.neonCyan : AppTheme.neonAmber)).opacity(0.4),
                    lineWidth: 1
                )
        )
    }

    private func statusBox(
        icon: String,
        iconColor: Color,
        title: String,
        subtitle: String,
        isPositive: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(iconColor)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white.opacity(0.65))

                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isPositive ? AppTheme.neonLime : Color.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(iconColor.opacity(0.25), lineWidth: 1)
        )
    }

    private func quickShortcutButton(
        icon: String,
        label: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(tint)

                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func handlePairingTap() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        showPairingSheet = true
    }

    private var languageCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.neonCyan)
                NeonReadout(text: language.text("settings.language"), tint: AppTheme.neonCyan)
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(AppLanguage.selectableCases) { option in
                    let isActive = option.rawValue == languageCode
                    Button {
                        languageCode = option.rawValue
                    } label: {
                        HStack(spacing: 6) {
                            Text(option.flag)
                                .font(.body)
                            Text(option.shortName)
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(isActive ? .black : Color.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            isActive
                                ? AppTheme.neonCyan
                                : AppTheme.neonCyan.opacity(0.10),
                            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(
                                    AppTheme.neonCyan.opacity(isActive ? 0.9 : 0.35),
                                    lineWidth: 1
                                )
                        )
                        .shadow(
                            color: AppTheme.neonCyan.opacity(isActive ? 0.55 : 0),
                            radius: isActive ? 10 : 0
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard(glow: AppTheme.neonCyan, opacity: 0.12)
    }

    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                PulsingDot(color: AppTheme.neonLime, size: 6)
                NeonReadout(text: language.text("common.device"), tint: AppTheme.neonLime)
            }

            VStack(spacing: 0) {
                deviceInfoRow(
                    icon: "iphone",
                    iconColor: AppTheme.neonCyan,
                    label: language.text("dashboard.hardware_model"),
                    value: AppInfo.displayMachineName
                )
                divider
                deviceInfoRow(
                    icon: "apple.logo",
                    iconColor: AppTheme.neonMagenta,
                    label: language.text("settings.ios_version"),
                    value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))"
                )
                divider
                deviceInfoRow(
                    icon: appState.isSupported ? "checkmark.shield.fill" : "exclamationmark.triangle.fill",
                    iconColor: appState.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta,
                    label: language.text("settings.current_version"),
                    value: language.text(appState.isSupported ? "settings.supported" : "settings.unsupported"),
                    valueColor: appState.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard(glow: AppTheme.neonLime, opacity: 0.12)
    }

    private var compatibilityCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.neonMagenta)
                NeonReadout(text: language.text("settings.verified_versions"), tint: AppTheme.neonMagenta)
            }

            VStack(alignment: .leading, spacing: 10) {
                compatibilityRow(label: "iOS 16", value: ExploitSupportPolicy.verifiedIOS16Range)
                compatibilityRow(label: "iOS 17", value: ExploitSupportPolicy.verifiedIOS17Range)
                compatibilityRow(label: "iOS 18", value: ExploitSupportPolicy.verifiedIOS18Range)
                compatibilityRow(label: "iOS 26", value: ExploitSupportPolicy.verifiedIOS26Range)
                compatibilityRow(label: "iOS 27", value: ExploitSupportPolicy.verifiedIOS27Range)

                VStack(alignment: .leading, spacing: 4) {
                    Text("iOS 18.7.2–18.7.10 (Pair / LocalDevVPN)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.neonAmber)
                    Text("22H110, 22H120, 22H130, 22H140, 22H150, 22H160, 22H170, 22H180, 22H190")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("iOS 27.0, 27.0.1 & 27.x (LocalDevVPN)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.neonCyan)
                    ForEach(ExploitSupportPolicy.verifiedIOS27Builds, id: \.build) { version in
                        Text(versionLabel(version))
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard(glow: AppTheme.neonMagenta, opacity: 0.12)
    }

    // MARK: - Shared bits

    private var divider: some View {
        Rectangle()
            .fill(AppTheme.neonCyan.opacity(0.10))
            .frame(height: 1)
            .padding(.vertical, 2)
    }

    private func deviceInfoRow(
        icon: String,
        iconColor: Color,
        label: String,
        value: String,
        valueColor: Color = .primary
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(iconColor)
                .frame(width: 22)
                .shadow(color: iconColor.opacity(0.6), radius: 4)
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 6)
    }

    private func compatibilityRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.neonCyan)
                .frame(width: 56, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .multilineTextAlignment(.leading)
        }
    }

    private var bundleDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "INNOVA CHEAT"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }

    private func versionLabel(
        _ version: (beta: Int, publicBeta: Int?, build: String)
    ) -> String {
        if version.beta == 0 {
            return "Release / Final · \(version.build)"
        }
        if let publicBeta = version.publicBeta {
            return language.text(
                "settings.developer_public_beta_build",
                Int64(version.beta),
                Int64(publicBeta),
                version.build
            )
        }
        return language.text(
            "settings.developer_beta_build",
            Int64(version.beta),
            version.build
        )
    }
}