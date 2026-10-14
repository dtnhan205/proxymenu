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

    var body: some View {
        ZStack {
            // Nền ảnh được paint ở App.swift (Image("Background") trong ZStack
            // gốc của WindowGroup) → đã phủ kín mọi màn hình, không cần
            // TechBackground() riêng cho Settings.

            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        profileCard
                        localDevVPNCard
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
            Button("Mở bảng Ghép đôi") {
                showPairingSheet = true
            }
        } message: {
            if pairingAdvertiser.hasExistingPairing {
                Text("✅ Thiết bị đã có sẵn File Pairing (Ghép đôi hoàn tất)!\n\nBạn có thể mở bảng Ghép đôi để kiểm tra thông số hoặc kết nối LocalDevVPN và nạp mod ngay.")
            } else {
                Text("Ghép đôi dịch vụ hệ thống cho iOS 27 & iOS 18.7.x.\n\nBạn có thể tạo File Pairing trực tiếp ngay trên máy (không cần Wi-Fi) hoặc nhập file .plist từ máy tính.")
            }
        }
        .sheet(isPresented: $showPairingSheet) {
            RemotePairingSheetView()
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

    private var localDevVPNCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.neonCyan)
                NeonReadout(text: vpnCardTitle, tint: AppTheme.neonCyan)

                Spacer()

                HStack(spacing: 5) {
                    PulsingDot(
                        color: vpnManager.isConnected ? AppTheme.neonLime : AppTheme.neonMagenta,
                        size: 6
                    )
                    Text(language.text(vpnManager.isConnected ? "settings.vpn_status_connected" : "settings.vpn_status_disconnected"))
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(vpnManager.isConnected ? AppTheme.neonLime : AppTheme.neonMagenta)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    (vpnManager.isConnected ? AppTheme.neonLime : AppTheme.neonMagenta).opacity(0.12),
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            (vpnManager.isConnected ? AppTheme.neonLime : AppTheme.neonMagenta).opacity(0.4),
                            lineWidth: 1
                        )
                )
            }

            Text(language.text("settings.vpn_help_guide"))
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            VStack(spacing: 0) {
                deviceInfoRow(
                    icon: "server.rack",
                    iconColor: AppTheme.neonCyan,
                    label: "Endpoint Tunnel",
                    value: vpnManager.lastConnectedHost
                )
                divider
                deviceInfoRow(
                    icon: "shield.checkered",
                    iconColor: vpnManager.isConnected ? AppTheme.neonLime : AppTheme.neonMagenta,
                    label: language.text("settings.exploit_status"),
                    value: vpnManager.statusMessage,
                    valueColor: vpnManager.isConnected ? AppTheme.neonLime : AppTheme.neonMagenta
                )
            }

            HStack(spacing: 10) {
                Button {
                    handleConnectLocalDevVPN()
                } label: {
                    HStack(spacing: 8) {
                        if vpnManager.isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.85)
                            Text(language.text("settings.vpn_connecting"))
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.black)
                        } else {
                            Image(systemName: vpnManager.isConnected ? "arrow.clockwise.circle.fill" : "cable.connector")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.black)
                            Text(vpnConnectButtonText)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: vpnManager.isConnected
                                ? [AppTheme.neonLime, AppTheme.neonCyan]
                                : [AppTheme.neonCyan, AppTheme.neonLime],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(
                        color: (vpnManager.isConnected ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.55),
                        radius: 8,
                        y: 2
                    )
                }
                .buttonStyle(.plain)
                .disabled(vpnManager.isConnecting)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(AppTheme.neonCyan)
                        .frame(width: 44, height: 44)
                        .background(
                            AppTheme.neonCyan.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(AppTheme.neonCyan.opacity(0.4), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard(glow: vpnManager.isConnected ? AppTheme.neonLime : AppTheme.neonCyan, opacity: 0.15)
    }

    private func handleConnectLocalDevVPN() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        showPairingPromptAlert = true
    }

    private var vpnCardTitle: String {
        if LocalDevVPNBridge.isIOS18_7_x {
            return "LocalDevVPN & Pair (iOS 18.7.x)"
        } else if LocalDevVPNBridge.isIOS27 {
            return "LocalDevVPN (iOS 27)"
        } else {
            return "LocalDevVPN & Pair (iOS 18.7.x / 27)"
        }
    }

    private var vpnConnectButtonText: String {
        let os = LocalDevVPNBridge.isIOS18_7_x ? "iOS 18.7.x" : "iOS 27"
        if vpnManager.isConnected {
            return "Kết Nối Lại \(os)"
        } else {
            return "Kết Nối \(os)"
        }
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