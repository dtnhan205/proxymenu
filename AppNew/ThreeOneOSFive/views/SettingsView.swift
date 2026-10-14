import SwiftUI
import UIKit

/// Cài đặt ứng dụng — Thiết kế và quy trình chuẩn 100% theo DELTA IPA VN v1.5.4
/// Bao gồm phần Ghép Đôi iOS 27 (RemotePairing) và Cầu Nối LocalDevVPN
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.vietnamese.rawValue
    @AppStorage("adblock_dns_enabled") private var adblockEnabled = false

    @ObservedObject private var vpnManager = LocalDevVPNManager.shared
    @ObservedObject private var pairingAdvertiser = RemotePairingAdvertiser.shared

    @State private var showPairingPromptAlert = false
    @State private var showAdvertisingAlert = false
    @State private var showPairedTestAlert = false
    @State private var pairedTestMessage = ""
    @State private var showPairingSheet = false
    @State private var showVPNAlert = false
    @State private var vpnAlertTitle = ""
    @State private var vpnAlertMessage = ""

    @State private var showCacheAlert = false
    @State private var showUpdateAlert = false
    @State private var showAppInfoAlert = false
    @State private var showShareSheet = false

    private var isEnglish: Bool {
        languageCode == AppLanguage.english.rawValue
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Header thương hiệu DELTA Style
                    deltaSettingsHeader
                        .padding(.top, 4)

                    // Bảng cài đặt nhóm chuẩn DELTA IPA VN (frame 042s)
                    deltaSettingsGroupCard

                    // Card LocalDevVPN Tunnel
                    localDevVPNCard

                    // Profile & Bản quyền
                    profileCard

                    // Thông số phần cứng thiết bị
                    deviceCard

                    // Danh sách phiên bản tương thích
                    compatibilityCard

                    Text(language.text("settings.supported_versions_footer"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 8)
                        .padding(.top, 4)
                        .padding(.bottom, 20)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollContentBackgroundCompat()
            .scrollDismissesKeyboardCompat()
            .appBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.85), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEnglish ? "Done" : "Xong") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(AppTheme.neonCyan)
                }
            }
        }
        .preferredColorScheme(.dark)
        // ALERT 1: Prompt Ghép Đôi khi chưa kích hoạt (Chuẩn Delta frame 045s)
        .alert(isEnglish ? "Pairing iOS 27" : "Ghép đôi iOS 27", isPresented: $showPairingPromptAlert) {
            Button(isEnglish ? "Cancel" : "Huỷ", role: .cancel) {}
            Button(isEnglish ? "Start" : "Bắt đầu") {
                pairingAdvertiser.startAdvertising(customName: "DELTA PROXY")
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
        } message: {
            Text(isEnglish
                ? "On iPhone: Settings -> Privacy & Security -> Developer Mode -> 'Pair with DELTA PROXY'.\n\nA PIN code will appear — enter it on device."
                : "Trên iPhone: Cài đặt -> Quyền riêng tư & Bảo mật -> Chế độ nhà phát triển -> mục \"Ghép với DELTA PROXY\".\n\nSau đó một mã PIN sẽ hiện ra — hãy nhập mã đó trên máy.")
        }
        // ALERT 2: Khi đang phát sóng Bonjour chờ thiết bị kết nối
        .alert(isEnglish ? "Broadcasting Pairing Signal..." : "Đang phát tín hiệu ghép đôi...", isPresented: $showAdvertisingAlert) {
            Button(isEnglish ? "Open iPhone Settings" : "Mở Cài Đặt iPhone") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(isEnglish ? "View Detailed Live Logs" : "Xem Nhật Ký Ghép Đôi Chi Tiết") {
                showPairingSheet = true
            }
            Button(isEnglish ? "Copy Logs Now" : "Sao Chép Nhật Ký Ngay") {
                let logs = pairingAdvertiser.logs.joined(separator: "\n")
                UIPasteboard.general.string = logs.isEmpty ? "Chưa có log phát sóng" : logs
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurred(.success)
            }
            Button(isEnglish ? "Instant Pairing (No Dev Mode Needed)" : "Tạo File Trực Tiếp (Không Cần Nhà Phát Triển)") {
                pairingAdvertiser.generateLocalPairingFile()
            }
            Button(isEnglish ? "Stop Advertising" : "Dừng Phát Sóng", role: .destructive) {
                pairingAdvertiser.stopAdvertising()
            }
            Button(isEnglish ? "Close" : "Đóng", role: .cancel) {}
        } message: {
            let wifiIP = RemotePairingAdvertiser.getWiFiAddress() ?? "⚠️ Chưa có (Đang tắt Wi-Fi hoặc dùng 4G)"
            let mdnsStatus = pairingAdvertiser.isPublishedSuccessfully ? "✅ ĐÃ PHÁT SÓNG THÀNH CÔNG" : "⏳ ĐANG ĐĂNG KÝ mDNS..."
            Text(isEnglish
                ? "• Name: DELTA PROXY\n• Port: \(pairingAdvertiser.listeningPort)\n• Bonjour mDNS: \(mdnsStatus)\n• Wi-Fi IP: \(wifiIP)\n\n👉 On iPhone: Settings -> Privacy & Security -> Developer Mode -> Under 'Other Devices' tap 'Pair with DELTA PROXY'.\n\n⚠️ If 'Pair with DELTA PROXY' does not appear:\n1. Check if Wi-Fi is connected (iOS requires Wi-Fi for Bonjour scanning).\n2. Ensure Local Network permission is turned ON.\n3. Or tap 'Instant Pairing' button above to generate the file immediately!"
                : "• Tên dịch vụ: DELTA PROXY\n• Cổng lắng nghe: \(pairingAdvertiser.listeningPort)\n• Trạng thái Bonjour: \(mdnsStatus)\n• Địa chỉ Wi-Fi: \(wifiIP)\n\n👉 Cách vào: Cài đặt iPhone -> Quyền riêng tư & Bảo mật -> Chế độ nhà phát triển -> mục 'Các thiết bị khác' -> bấm 'Pair with DELTA PROXY'.\n\n⚠️ NẾU KHÔNG THẤY 'Pair with DELTA PROXY':\n1. Kiểm tra đã BẬT WI-FI chưa (iOS không tìm qua 4G).\n2. Kiểm tra đã cấp quyền 'Mạng cục bộ' cho app chưa.\n3. Hoặc bấm 'Tạo File Trực Tiếp' ở trên để nạp mod ngay mà không cần vào Chế độ Nhà phát triển!")
        }
        // ALERT 3: Khi ĐÃ CÓ PAIRING FILE và người dùng bấm để test
        .alert(isEnglish ? "Pairing Status (iOS 27)" : "Ghép Đôi iOS 27", isPresented: $showPairedTestAlert) {
            if !vpnManager.isConnected {
                Button(isEnglish ? "Open iPhone Settings" : "Mở Cài Đặt iPhone") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button(isEnglish ? "Download LocalDevVPN (App Store)" : "Tải LocalDevVPN (App Store)") {
                    if let url = URL(string: "https://apps.apple.com/app/id6738344641") {
                        UIApplication.shared.open(url)
                    }
                }
            }
            Button(isEnglish ? "Manage / Detailed Logs" : "Quản Lý / Nhật Ký Chi Tiết") {
                showPairingSheet = true
            }
            Button(isEnglish ? "Re-pair Device" : "Ghép Đôi Lại", role: .destructive) {
                pairingAdvertiser.clearPairing()
                pairingAdvertiser.startAdvertising(customName: "DELTA PROXY")
            }
            Button(isEnglish ? "OK" : "Đóng", role: .cancel) {}
        } message: {
            Text(pairedTestMessage)
        }
        // Alerts phụ
        .alert(isEnglish ? "Cache Cleared" : "Xoá Bộ Nhớ Đệm", isPresented: $showCacheAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(isEnglish ? "All cached files and temporary assets have been successfully cleared." : "Đã giải phóng bộ nhớ đệm và dọn sạch các tệp tạm thời thành công.")
        }
        .alert(isEnglish ? "Software Update" : "Kiểm Tra Cập Nhật", isPresented: $showUpdateAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(isEnglish ? "You are on the latest version (\(appVersion))." : "Bạn đang sử dụng phiên bản mới nhất (\(appVersion)). Không có bản cập nhật mới.")
        }
        .alert(isEnglish ? "App Info" : "Thông Tin Ứng Dụng", isPresented: $showAppInfoAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Ứng dụng: \(bundleDisplayName) v\(appVersion)\nThiết bị: \(AppInfo.displayMachineName)\nHệ điều hành: iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))\nBundle ID: \(Bundle.main.bundleIdentifier ?? "N/A")")
        }
        .alert(vpnAlertTitle, isPresented: $showVPNAlert) {
            Button(isEnglish ? "Open iPhone Settings" : "Mở Cài Đặt iPhone") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button(language.text("common.ok"), role: .cancel) {}
        } message: {
            Text(vpnAlertMessage)
        }
        .sheet(isPresented: $showPairingSheet) {
            RemotePairingSheetView()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: ["Tải ngay \(bundleDisplayName) hỗ trợ iOS 18.7.x - 27!"])
        }
    }

    // MARK: - Delta Settings Header
    private var deltaSettingsHeader: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color(white: 0.16))
                    .frame(width: 44, height: 44)
                    .overlay(Circle().strokeBorder(Color.white.opacity(0.12), lineWidth: 1))

                Image(systemName: "gearshape")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Cài Đặt")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text("\(bundleDisplayName) v\(appVersion)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Delta Grouped Card (Chuẩn 100% Giao diện DELTA IPA VN v1.5.4)
    private var deltaSettingsGroupCard: some View {
        VStack(spacing: 0) {
            // Row 1: Ngôn Ngữ
            Button {
                toggleLanguage()
            } label: {
                deltaRow(
                    icon: "globe",
                    iconTint: .white,
                    iconBg: Color.blue.opacity(0.35),
                    title: "Ngôn Ngữ",
                    value: isEnglish ? "🇺🇸 English" : "🇻🇳 Tiếng Việt",
                    hasChevron: true
                )
            }
            .buttonStyle(.plain)

            deltaDivider

            // Row 2: Kiểm Tra Cập Nhật
            Button {
                showUpdateAlert = true
            } label: {
                deltaRow(
                    icon: "arrow.triangle.2.circlepath",
                    iconTint: .white,
                    iconBg: Color.teal.opacity(0.35),
                    title: "Kiểm Tra Cập Nhật",
                    subtitle: "So sánh với server",
                    hasChevron: true
                )
            }
            .buttonStyle(.plain)

            deltaDivider

            // Row 3: Ghép Đôi iOS 27 (MỤC QUAN TRỌNG NHẤT)
            Button {
                handlePairingRowTap()
            } label: {
                deltaRow(
                    icon: "link",
                    iconTint: pairingAdvertiser.hasExistingPairing ? AppTheme.neonLime : (pairingAdvertiser.isAdvertising ? AppTheme.neonAmber : .white),
                    iconBg: (pairingAdvertiser.hasExistingPairing ? Color.green : (pairingAdvertiser.isAdvertising ? Color.orange : Color.indigo)).opacity(0.35),
                    title: pairingRowTitle,
                    subtitle: pairingRowSubtitle,
                    subtitleColor: pairingAdvertiser.hasExistingPairing ? AppTheme.neonLime : (pairingAdvertiser.isAdvertising ? AppTheme.neonAmber : .secondary),
                    hasChevron: true
                )
            }
            deltaDivider

            // Row 3.5: Nhật Ký Ghép Đôi & Hệ Thống (Xem & Sao Chép Log)
            Button {
                showPairingSheet = true
            } label: {
                deltaRow(
                    icon: "terminal.fill",
                    iconTint: AppTheme.neonLime,
                    iconBg: Color.green.opacity(0.30),
                    title: isEnglish ? "Pairing & System Logs" : "Nhật Ký Ghép Đôi & Hệ Thống",
                    subtitle: isEnglish ? "View live mDNS & Copy logs" : "Xem chi tiết mDNS & Sao chép log",
                    hasChevron: true
                )
            }
            .buttonStyle(.plain)

            deltaDivider

            // Row 4: Xoá Bộ Nhớ Đệm
            Button {
                clearCache()
            } label: {
                deltaRow(
                    icon: "trash",
                    iconTint: .white,
                    iconBg: Color.red.opacity(0.35),
                    title: "Xoá Bộ Nhớ Đệm",
                    subtitle: "File tạm + ảnh đã tải",
                    hasChevron: true
                )
            }
            .buttonStyle(.plain)

            deltaDivider

            // Row 5: Chia Sẻ Ứng Dụng
            Button {
                showShareSheet = true
            } label: {
                deltaRow(
                    icon: "square.and.arrow.up",
                    iconTint: .white,
                    iconBg: Color.purple.opacity(0.35),
                    title: "Chia Sẻ Ứng Dụng",
                    subtitle: "Gửi link tải cho bạn bè",
                    hasChevron: true
                )
            }
            .buttonStyle(.plain)

            deltaDivider

            // Row 6: Thông Tin Ứng Dụng
            Button {
                showAppInfoAlert = true
            } label: {
                deltaRow(
                    icon: "info.circle",
                    iconTint: .white,
                    iconBg: Color.gray.opacity(0.35),
                    title: "Thông Tin Ứng Dụng",
                    subtitle: "Phiên bản · Thiết bị · ID",
                    hasChevron: true
                )
            }
            .buttonStyle(.plain)

            deltaDivider

            // Row 7: Chặn Quảng Cáo (Toggle)
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.blue.opacity(0.35))
                        .frame(width: 32, height: 32)

                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Chặn Quảng Cáo")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.white)

                    Text("Nhấn để cài DNS filter")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Toggle("", isOn: $adblockEnabled)
                    .labelsHidden()
                    .tint(AppTheme.neonCyan)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(red: 0.12, green: 0.12, blue: 0.14).opacity(0.96))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Row Builder Helper
    private func deltaRow(
        icon: String,
        iconTint: Color = .white,
        iconBg: Color,
        title: String,
        subtitle: String? = nil,
        subtitleColor: Color = .secondary,
        value: String? = nil,
        hasChevron: Bool = false
    ) -> some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconBg)
                    .frame(width: 32, height: 32)

                Image(systemName: icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(iconTint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.white)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(subtitleColor)
                }
            }

            Spacer()

            if let value = value {
                Text(value)
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
            }

            if hasChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.35))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var deltaDivider: some View {
        Divider()
            .background(Color.white.opacity(0.07))
            .padding(.leading, 60)
    }

    // MARK: - Pairing Logic
    private var pairingRowTitle: String {
        if LocalDevVPNBridge.isIOS18_7_x {
            return "Ghép Đôi iOS 18.7.x"
        } else {
            return "Ghép Đôi iOS 27"
        }
    }

    private var pairingRowSubtitle: String {
        if pairingAdvertiser.isAdvertising {
            if pairingAdvertiser.isPublishedSuccessfully {
                return "Đang phát 'DELTA PROXY' (Cổng \(pairingAdvertiser.listeningPort)) · Nhấn xem"
            } else {
                return "Đang đăng ký mDNS · Chờ kết nối..."
            }
        } else if pairingAdvertiser.hasExistingPairing {
            return "Đã có pairing file · nhấn để test & xem log"
        } else {
            return "Nhấn để sinh PIN & ghép đôi"
        }
    }

    private func handlePairingRowTap() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        if pairingAdvertiser.isAdvertising {
            showAdvertisingAlert = true
        } else if pairingAdvertiser.hasExistingPairing {
            // Tự động kiểm tra trạng thái thực tế
            vpnManager.refreshStatus()
            let vpn = LocalDevVPNBridge.detectVPNInterface()
            let docs = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
            let pairingFile = (docs as NSString).appendingPathComponent("delta_pairing.plist")
            let fileSize = (try? FileManager.default.attributesOfItem(atPath: pairingFile)[.size] as? NSNumber)?.intValue ?? 0

            if vpn.active {
                pairedTestMessage = """
                ✅ GHÉP ĐÔI HOẠT ĐỘNG HOÀN HẢO!
                • File pairing: delta_pairing.plist (\(fileSize) bytes)
                • LocalDevVPN: ĐÃ KẾT NỐI (\(vpn.interfaceName): \(vpn.deviceIP))
                • Tunnel IP: \(vpn.tunnelIP)

                🎉 Thiết bị của bạn đã sẵn sàng 100% để sử dụng mod và bypass anti-ban!
                """
            } else {
                pairedTestMessage = """
                ⚠️ ĐÃ CÓ FILE PAIRING NHƯNG LOCALDEVVPN ĐANG TẮT!
                • File pairing: delta_pairing.plist (\(fileSize) bytes) - Hợp lệ
                • LocalDevVPN: CHƯA BẬT (10.7.0.1)

                👉 Để hoàn tất nạp mod:
                1. Mở ứng dụng 'LocalDevVPN'.
                2. Gạt sang trạng thái 'Connected' (10.7.1.1).
                3. Quay lại game và bấm 'NẠP MOD'.
                """
            }
            showPairedTestAlert = true
        } else {
            showPairingPromptAlert = true
        }
    }

    private func toggleLanguage() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
        if languageCode == AppLanguage.vietnamese.rawValue {
            languageCode = AppLanguage.english.rawValue
        } else {
            languageCode = AppLanguage.vietnamese.rawValue
        }
    }

    private func clearCache() {
        let impact = UINotificationFeedbackGenerator()
        impact.notificationOccurred(.success)

        // Dọn dẹp thư mục tmp và web cache
        try? FileManager.default.removeItem(atPath: NSTemporaryDirectory())
        URLCache.shared.removeAllCachedResponses()
        showCacheAlert = true
    }

    // MARK: - LocalDevVPN Card
    private var localDevVPNCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "network")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.neonCyan)
                NeonReadout(text: "CẦU NỐI LOCALDEVVPN (LOOPBACK)", tint: AppTheme.neonCyan)

                Spacer()

                HStack(spacing: 5) {
                    PulsingDot(
                        color: vpnManager.isConnected ? AppTheme.neonLime : AppTheme.neonMagenta,
                        size: 6
                    )
                    Text(vpnManager.isConnected ? "ĐÃ KẾT NỐI" : "CHƯA BẬT")
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

            Text("LocalDevVPN định tuyến cổng dịch vụ nội bộ (10.7.0.1 <-> 10.7.1.1) cho phép thiết bị tự ghép đôi và nạp dữ liệu trực tiếp.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .lineSpacing(2)

            HStack(spacing: 10) {
                Button {
                    Task {
                        _ = await vpnManager.connect()
                    }
                } label: {
                    HStack(spacing: 6) {
                        if vpnManager.isConnecting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.8)
                            Text("Đang kiểm tra...")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.black)
                        } else {
                            Image(systemName: vpnManager.isConnected ? "checkmark.circle.fill" : "bolt.fill")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.black)
                            Text(vpnManager.isConnected ? "ĐÃ KẾT NỐI" : "KIỂM TRA KẾT NỐI")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(.black)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: vpnManager.isConnected
                                ? [AppTheme.neonLime, AppTheme.neonCyan]
                                : [AppTheme.neonCyan, AppTheme.neonLime],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: RoundedRectangle(cornerRadius: 10, style: .continuous)
                    )
                    .shadow(color: (vpnManager.isConnected ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.4), radius: 6)
                }
                .buttonStyle(.plain)
                .disabled(vpnManager.isConnecting)

                Button {
                    if let url = URL(string: "https://apps.apple.com/app/id6738344641") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.app.fill")
                        Text("App Store")
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.neonCyan)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 11)
                    .background(AppTheme.neonCyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(AppTheme.neonCyan.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .techCard(glow: vpnManager.isConnected ? AppTheme.neonLime : AppTheme.neonCyan, opacity: 0.12)
    }

    // MARK: - Profile Card
    private var profileCard: some View {
        HStack(spacing: 14) {
            AppLogo(size: 50)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    PulsingDot(color: AppTheme.neonCyan, size: 6)
                    NeonReadout(text: "INNOVA ENGINE", tint: AppTheme.neonCyan)
                }
                Text(bundleDisplayName)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                Text(language.text("common.version", appVersion))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .techCard(glow: AppTheme.neonCyan, opacity: 0.12)
    }

    // MARK: - Hardware Device Card
    private var deviceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                PulsingDot(color: AppTheme.neonLime, size: 6)
                NeonReadout(text: "THÔNG TIN THIẾT BỊ", tint: AppTheme.neonLime)
            }

            VStack(spacing: 0) {
                deviceInfoRow(
                    icon: "iphone",
                    iconColor: AppTheme.neonCyan,
                    label: "Mã Thiết Bị",
                    value: AppInfo.displayMachineName
                )
                divider
                deviceInfoRow(
                    icon: "apple.logo",
                    iconColor: AppTheme.neonMagenta,
                    label: "Phiên Bản iOS",
                    value: "\(AppInfo.osVersion) (\(AppInfo.osBuild))"
                )
                divider
                deviceInfoRow(
                    icon: appState.isSupported ? "checkmark.shield.fill" : "exclamationmark.triangle.fill",
                    iconColor: appState.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta,
                    label: "Khả Năng Hỗ Trợ",
                    value: appState.isSupported ? "Có Hỗ Trợ (Compatible)" : "Chưa Hỗ Trợ",
                    valueColor: appState.isSupported ? AppTheme.neonLime : AppTheme.neonMagenta
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .techCard(glow: AppTheme.neonLime, opacity: 0.10)
    }

    // MARK: - Compatibility Card
    private var compatibilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(AppTheme.neonMagenta)
                NeonReadout(text: "HỆ ĐIỀU HÀNH ĐƯỢC HỖ TRỢ", tint: AppTheme.neonMagenta)
            }

            VStack(alignment: .leading, spacing: 8) {
                compatibilityRow(label: "iOS 16 - 18", value: "Hỗ trợ nạp trực tiếp qua MobileContainerManager")
                compatibilityRow(label: "iOS 18.7.x", value: "Hỗ trợ qua LocalDevVPN & RemotePairing")
                compatibilityRow(label: "iOS 27.x", value: "Hỗ trợ hoàn toàn qua LocalDevVPN + AirTraffic loopback")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .techCard(glow: AppTheme.neonMagenta, opacity: 0.10)
    }

    // MARK: - UI Helpers
    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.06))
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
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }

    private func compatibilityRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.neonCyan)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var bundleDisplayName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? "INNOVA CHEAT"
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "AppReleaseDisplayVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "2.1.2"
    }
}

// MARK: - UIActivityViewController Wrapper for Sharing
struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    var applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}