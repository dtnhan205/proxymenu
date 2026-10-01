import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.english.rawValue

    var body: some View {
        ZStack {
            // Nền ảnh được paint ở App.swift (Image("Background") trong ZStack
            // gốc của WindowGroup) → đã phủ kín mọi màn hình, không cần
            // TechBackground() riêng cho Settings.

            NavigationStack {
                ScrollView {
                    VStack(spacing: 16) {
                        profileCard
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

                VStack(alignment: .leading, spacing: 4) {
                    Text("iOS 27.0")
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
            ?? "ProxyIPA OB55"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "1.0"
    }

    private func versionLabel(
        _ version: (beta: Int, publicBeta: Int?, build: String)
    ) -> String {
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