import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Cửa sổ hiển thị trạng thái và hướng dẫn Ghép Đôi iOS 27 (RemotePairing)
/// Tương thích hoàn toàn với cơ chế ghép đôi không dây (Developer Mode) và AirTraffic/LocalDevVPN của iOS 27+.
struct RemotePairingSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject private var pairing = RemotePairingAdvertiser.shared
    @ObservedObject private var vpnManager = LocalDevVPNManager.shared
    @AppStorage(AppLanguage.storageKey) private var languageCode: String = AppLanguage.vietnamese.rawValue

    @State private var isPulsing: Bool = false
    @State private var showFileImporter: Bool = false
    @State private var showClearAlert: Bool = false
    @State private var diagnosticLogs: [String] = []
    @State private var isRunningProbe: Bool = false
    @State private var showCopiedAlert: Bool = false
    @State private var isTestingInject: Bool = false
    @State private var showTestInjectAlert: Bool = false
    @State private var testInjectAlertText: String = ""
    @State private var showShareSheet: Bool = false

    private var isEnglish: Bool {
        languageCode == AppLanguage.english.rawValue
    }

    var body: some View {
        ZStack {
            // Nền tối Cyberpunk sang trọng
            Color(red: 0.05, green: 0.05, blue: 0.08)
                .ignoresSafeArea()

            // Hiệu ứng ánh sáng nền
            VStack {
                Circle()
                    .fill(AppTheme.neonCyan.opacity(0.12))
                    .frame(width: 280, height: 280)
                    .blur(radius: 60)
                    .offset(y: -120)
                Spacer()
            }

            VStack(spacing: 0) {
                // Header Bar
                headerBar
                    .padding(.horizontal, 20)
                    .padding(.top, 18)
                    .padding(.bottom, 12)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Banner Thành công nếu ĐÃ CÓ FILE PAIRING
                        if pairing.hasExistingPairing {
                            pairedSuccessBanner
                        }

                        // Cảnh báo Wi-Fi nếu CHƯA GHÉP ĐÔI và đang dùng 4G
                        if !pairing.hasExistingPairing && !pairing.isWiFiConnected {
                            wifiWarningCard
                        }

                        // Card Trạng thái phát sóng Bonjour / Conduit
                        broadcastingCard

                        // Card Hành động ghép đôi (Nhập file .plist)
                        quickActionsCard

                        // Card Nhật ký phát tín hiệu ghép đôi Bonjour (Realtime)
                        // livePairingLogsCard

                        // Card Nhật ký kiểm tra thực tế File Pairing & Documents Free Fire
                        // diagnosticConsoleCard

                        // Card Mã PIN (nếu có yêu cầu từ hệ thống)
                        if !pairing.pinCode.isEmpty {
                            pinCodeCard
                        }

                        // Card Các bước thực hiện chi tiết
                        pairingStepsCard

                        // Card Thông số kỹ thuật
                        techDetailsCard

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 18)
                    .padding(.bottom, 24)
                }

                // Bottom Action Buttons
                bottomActionBar
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color(red: 0.07, green: 0.07, blue: 0.10).opacity(0.95))
                    .overlay(
                        Rectangle()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 1),
                        alignment: .top
                    )
            }
        }
        .preferredColorScheme(.dark)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "plist") ?? .data,
                UTType(filenameExtension: "mobiledevicepairing") ?? .data,
                UTType(filenameExtension: "mobilepair") ?? .data,
                .data
            ]
        ) { result in
            switch result {
            case .success(let url):
                if pairing.importPairingFile(from: url) {
                    runProbe()
                }
            case .failure(let error):
                print("[RemotePairing] File picker error: \(error)")
            }
        }
        .alert(
            isEnglish ? "Delete pairing record?" : "Xác nhận xoá file Pairing?",
            isPresented: $showClearAlert
        ) {
            Button(isEnglish ? "Delete" : "Xoá", role: .destructive) {
                pairing.clearPairing()
                runProbe()
            }
            Button(isEnglish ? "Cancel" : "Huỷ", role: .cancel) {}
        } message: {
            Text(isEnglish
                ? "This will delete the pairing credentials from the device."
                : "Hành động này sẽ xoá file pairing hiện tại để bạn có thể tạo mới hoặc nhập file khác.")
        }
        .alert(
            isEnglish ? "Copied to Clipboard" : "Đã sao chép nhật ký",
            isPresented: $showCopiedAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(isEnglish ? "Diagnostic logs copied successfully." : "Toàn bộ nhật ký kiểm tra đã được sao chép vào bộ nhớ tạm.")
        }
        .alert(
            isEnglish ? "Inject Test Result" : "Kết Quả Kiểm Tra Inject",
            isPresented: $showTestInjectAlert
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(testInjectAlertText)
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [AppLog.shared.exportLogURL()])
        }
        .onAppear {
            isPulsing = true
            if !pairing.isAdvertising {
                pairing.startAdvertising()
            }
            runProbe()
        }
    }

    // MARK: - Run Diagnostics Probe
    private func runProbe() {
        isRunningProbe = true
        DispatchQueue.global(qos: .userInitiated).async {
            let logs = LocalDevVPNBridge.runFullDiagnostics()
            DispatchQueue.main.async {
                self.diagnosticLogs = logs
                self.isRunningProbe = false
            }
        }
    }

    // MARK: - Test Inject Cheat Directly
    private func runInjectTest() {
        guard !isTestingInject else { return }
        isTestingInject = true

        let target = FreeFirePatchService.selectedTarget
        diagnosticLogs.append("═══════════════════════════════════════════════")
        diagnosticLogs.append("[TEST] 🚀 BẮT ĐẦU KIỂM TRA INJECT VÀO \(target.displayName.uppercased())...")
        diagnosticLogs.append("[TEST] 📁 File Pairing: \(pairing.pairingFilePath) (\(pairing.hasExistingPairing ? "OK" : "CHƯA CÓ"))")
        let vpn = LocalDevVPNBridge.detectVPNInterface()
        diagnosticLogs.append("[TEST] 🌐 LocalDevVPN: \(vpn.active ? "Đang BẬT (\(vpn.deviceIP))" : "Đang TẮT (Nên bật để mở cổng RSD 49152)")")
        diagnosticLogs.append("[TEST] 📶 Wi-Fi IP: \(RemotePairingAdvertiser.getWiFiAddress() ?? "Không có")")

        Task {
            do {
                try await FreeFirePatchService.inject(target: target)
                await MainActor.run {
                    self.isTestingInject = false
                    self.diagnosticLogs.append("[TEST] 🎉 KẾT QUẢ: INJECT THÀNH CÔNG 100% VÀO GAME!")
                    self.diagnosticLogs.append("[TEST] 💡 Bạn có thể mở \(target.displayName) để trải nghiệm.")
                    self.testInjectAlertText = "🎉 INJECT THÀNH CÔNG!\nĐã nạp toàn bộ module cheat vào \(target.displayName) qua kết nối Developer Mode!"
                    self.showTestInjectAlert = true
                }
            } catch {
                await MainActor.run {
                    self.isTestingInject = false
                    self.diagnosticLogs.append("[TEST] ❌ LỖI INJECT: \(error.localizedDescription)")
                    self.testInjectAlertText = "❌ LỖI INJECT:\n\(error.localizedDescription)\n\n👉 Vui lòng xem chi tiết trong khung 'NHẬT KÝ KIỂM TRA TRUY CẬP THỰC TẾ' bên dưới!"
                    self.showTestInjectAlert = true
                }
            }
        }
    }

    // MARK: - Live Pairing Broadcast Logs Card
    private var livePairingLogsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(AppTheme.neonLime)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 1) {
                    Text(isEnglish ? "LIVE BONJOUR & BROADCAST LOGS" : "NHẬT KÝ PHÁT TÍN HIỆU GHÉP ĐÔI (REALTIME)")
                        .font(.system(size: 11.5, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.neonLime)
                    Text(isEnglish ? "Verifies mDNS broadcast, port binding, and handshake" : "Chi tiết socket, cổng kết nối, phát mDNS và bắt tay hệ thống")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                HStack(spacing: 4) {
                    Circle()
                        .fill(pairing.isPublishedSuccessfully ? AppTheme.neonLime : (pairing.isAdvertising ? AppTheme.neonAmber : Color.gray))
                        .frame(width: 6, height: 6)
                    Text(pairing.isPublishedSuccessfully ? "mDNS: OK" : (pairing.isAdvertising ? "WAITING" : "OFF"))
                        .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                        .foregroundColor(pairing.isPublishedSuccessfully ? AppTheme.neonLime : (pairing.isAdvertising ? AppTheme.neonAmber : .gray))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
            }

            // Terminal View
            VStack(alignment: .leading, spacing: 4) {
                if pairing.logs.isEmpty {
                    Text(isEnglish ? "No broadcast logs yet. Tap Start to begin broadcasting." : "Chưa có log phát sóng. Dịch vụ đang sẵn sàng.")
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(pairing.logs.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(colorForLogLine(line))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 180)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.02, green: 0.02, blue: 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppTheme.neonLime.opacity(0.25), lineWidth: 1)
            )

            // Footer bar
            HStack {
                Button {
                    UIPasteboard.general.string = pairing.logs.joined(separator: "\n")
                    showCopiedAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9.5))
                        Text(isEnglish ? "Copy Logs" : "Sao chép")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    AppLog.shared.flush()
                    showShareSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 9.5))
                        Text(isEnglish ? "Export log.txt" : "Xuất log.txt")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(AppTheme.neonLime)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.neonLime.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(pairing.isWiFiConnected
                    ? "📶 Wi-Fi: \(RemotePairingAdvertiser.getWiFiAddress() ?? "OK")"
                    : "⚠️ KHÔNG CÓ WI-FI (4G)")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(pairing.isWiFiConnected ? AppTheme.neonCyan : AppTheme.neonAmber)
            }
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.neonLime.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Diagnostic Console Card (Log thực tế kiểm tra Pairing & Documents)
    private var diagnosticConsoleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "terminal.fill")
                    .foregroundColor(AppTheme.neonCyan)
                    .font(.system(size: 14))

                VStack(alignment: .leading, spacing: 1) {
                    Text(isEnglish ? "FILE & DOCUMENTS ACCESS LOGS" : "NHẬT KÝ KIỂM TRA TRUY CẬP THỰC TẾ")
                        .font(.system(size: 11.5, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.neonCyan)
                    Text(isEnglish ? "Verifies pairing record & Free Fire container access" : "Xác thực file pairing và quyền truy cập Documents của game")
                        .font(.system(size: 9.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                }

                Spacer()

                Button {
                    runProbe()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isRunningProbe ? "arrow.triangle.2.circlepath" : "arrow.clockwise")
                            .rotationEffect(isRunningProbe ? .degrees(360) : .zero)
                            .animation(isRunningProbe ? Animation.linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isRunningProbe)
                        Text(isEnglish ? "Re-test" : "Quét lại")
                    }
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(AppTheme.neonCyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.neonCyan.opacity(0.12))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isRunningProbe)
            }

            // Terminal View
            VStack(alignment: .leading, spacing: 4) {
                if diagnosticLogs.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonCyan))
                            .scaleEffect(0.7)
                        Text(isEnglish ? "Running diagnostics probe..." : "Đang chạy kiểm tra truy cập...")
                            .font(.system(size: 10.5, design: .monospaced))
                            .foregroundColor(.white.opacity(0.6))
                    }
                    .padding(.vertical, 16)
                    .frame(maxWidth: .infinity, alignment: .center)
                } else {
                    ScrollView(.vertical, showsIndicators: true) {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(Array(diagnosticLogs.enumerated()), id: \.offset) { _, line in
                                Text(line)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(colorForLogLine(line))
                                    .fixedSize(horizontal: false, vertical: true)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(8)
                    }
                    .frame(maxHeight: 180)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color(red: 0.02, green: 0.02, blue: 0.04))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(AppTheme.neonCyan.opacity(0.25), lineWidth: 1)
            )

            // Footer bar: Sao chép nhật ký & Giải thích kết quả
            HStack {
                Button {
                    UIPasteboard.general.string = diagnosticLogs.joined(separator: "\n")
                    showCopiedAlert = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 9.5))
                        Text(isEnglish ? "Copy Logs" : "Sao chép")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(.white.opacity(0.75))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Button {
                    AppLog.shared.flush()
                    showShareSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 9.5))
                        Text(isEnglish ? "Export log.txt" : "Xuất log.txt")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(AppTheme.neonCyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(AppTheme.neonCyan.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)

                Spacer()

                Text(diagnosticLogs.contains(where: { $0.contains("100% ACCESS") || $0.contains("ĐÃ GHI & ĐỌC THÀNH CÔNG") })
                    ? (isEnglish ? "✅ DOCUMENTS ACCESS: VERIFIED" : "✅ QUYỀN TRUY CẬP DOCUMENTS: OK")
                    : (isEnglish ? "⚠️ PENDING GAME LAUNCH" : "⚠️ CẦN MỞ GAME 1 LẦN"))
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundColor(diagnosticLogs.contains(where: { $0.contains("100% ACCESS") || $0.contains("ĐÃ GHI & ĐỌC THÀNH CÔNG") }) ? AppTheme.neonLime : AppTheme.neonAmber)
            }
        }
        .padding(12)
        .background(Color(red: 0.08, green: 0.08, blue: 0.12))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.neonCyan.opacity(0.3), lineWidth: 1)
        )
    }

    private func colorForLogLine(_ line: String) -> Color {
        if line.contains("✅") || line.contains("100% ACCESS") || line.contains("THÀNH CÔNG") {
            return AppTheme.neonLime
        } else if line.contains("❌") || line.contains("Lỗi") || line.contains("FAILED") {
            return AppTheme.neonRed
        } else if line.contains("⚠️") || line.contains("CHƯA CÓ") || line.contains("ĐANG TẮT") {
            return AppTheme.neonAmber
        } else if line.contains("🎮") || line.contains("🚀") || line.contains("🏁") {
            return AppTheme.neonCyan
        } else if line.contains("📂") || line.contains("📁") || line.contains("📄") {
            return Color(red: 0.6, green: 0.85, blue: 1.0)
        } else {
            return Color.white.opacity(0.85)
        }
    }

    // MARK: - Paired Success Banner
    private var pairedSuccessBanner: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(AppTheme.neonLime.opacity(0.2))
                        .frame(width: 38, height: 38)
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(AppTheme.neonLime)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isEnglish ? "PAIRING ACTIVE (READY)" : "GHÉP ĐÔI THÀNH CÔNG (ĐÃ SẴN SÀNG)")
                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.neonLime)

                    Text(isEnglish ? "Valid Pairing Record found on device" : "Đã có File Pairing hợp lệ trên máy")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                Spacer()
            }

            Text(isEnglish
                ? "Pairing record verified on-device! You DO NOT need to pair in Settings Developer Mode. Simply turn ON LocalDevVPN, open Free Fire, and apply mods directly!"
                : "Đã có File Pairing hợp lệ trên máy! Bạn KHÔNG CẦN phải vào Cài đặt Chế độ Nhà phát triển để ghép đôi nữa. Chỉ cần: Bật LocalDevVPN -> Mở game Free Fire -> Bấm Nạp Mod là hoàn tất 100%!")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(2.5)

            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(AppTheme.neonLime)
                    .font(.system(size: 11))
                Text(isEnglish ? "Pairing active. Turn on LocalDevVPN and open game!" : "Ghép đôi sẵn sàng. Hãy Bật LocalDevVPN và mở game nạp mod ngay!")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(AppTheme.neonLime)
            }
            .padding(.top, 2)
        }
        .padding(14)
        .background(Color(red: 0.05, green: 0.16, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.neonLime.opacity(0.8), lineWidth: 1.5)
        )
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(pairing.hasExistingPairing ? AppTheme.neonLime : (pairing.isAdvertising ? AppTheme.neonCyan : AppTheme.neonAmber))
                        .frame(width: 8, height: 8)
                        .scaleEffect(isPulsing ? 1.2 : 0.8)
                        .animation(Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulsing)

                    Text(isEnglish ? "iOS 27 PAIRING CONDUIT" : "GHÉP ĐÔI iOS 27")
                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.neonCyan)
                }

                Text(isEnglish ? "Developer Mode Wireless Pairing" : "Ghép đôi Chế độ Nhà phát triển")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            Spacer()

            Button {
                presentationMode.wrappedValue.dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Broadcasting Card
    private var broadcastingCard: some View {
        VStack(spacing: 12) {
            radarAnimationView
            broadcastingInfoSection
            broadcastingPillsSection
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
        .background(Color(red: 0.10, green: 0.10, blue: 0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    (pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.45),
                    lineWidth: 1
                )
        )
    }

    private var radarAnimationView: some View {
        ZStack {
            radarRingsView

            Circle()
                .fill(
                    LinearGradient(
                        colors: pairing.hasExistingPairing
                            ? [AppTheme.neonLime, Color(red: 0.1, green: 0.8, blue: 0.3)]
                            : [AppTheme.neonCyan, Color(red: 0.0, green: 0.48, blue: 1.0)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 58, height: 58)
                .shadow(color: (pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.6), radius: 10)

            Image(systemName: pairing.hasExistingPairing ? "checkmark.seal.fill" : "antenna.radiowaves.left.and.right")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.black)
        }
        .padding(.top, 10)
    }

    private var radarRingsView: some View {
        ZStack {
            Circle()
                .strokeBorder((pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.25), lineWidth: 1.5)
                .frame(width: 64, height: 64)

            Circle()
                .strokeBorder((pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.18), lineWidth: 1.5)
                .frame(width: 92, height: 92)

            Circle()
                .strokeBorder((pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan).opacity(0.11), lineWidth: 1.5)
                .frame(width: 120, height: 120)
        }
        .scaleEffect(isPulsing ? 1.08 : 0.95)
        .animation(Animation.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: isPulsing)
    }

    private var broadcastingInfoSection: some View {
        VStack(spacing: 4) {
            Text(pairing.advertisedName)
                .font(.system(size: 17, weight: .heavy, design: .monospaced))
                .foregroundColor(.white)

            Text(pairing.statusMessage)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonAmber)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
        }
    }

    private var broadcastingPillsSection: some View {
        HStack(spacing: 8) {
            statusPill(
                icon: "network",
                label: "PORT",
                value: "\(pairing.listeningPort)"
            )
            statusPill(
                icon: pairing.isWiFiConnected ? "wifi" : "wifi.slash",
                label: "NETWORK",
                value: pairing.isWiFiConnected ? "WI-FI OK" : "4G (CELLULAR)"
            )
            statusPill(
                icon: "lock.shield.fill",
                label: "STATUS",
                value: pairing.hasExistingPairing ? "PAIRED" : "READY"
            )
        }
        .padding(.top, 4)
    }

    // MARK: - Quick Actions Card
    private var quickActionsCard: some View {
        VStack(spacing: 10) {
            // Nút Mở Ứng Dụng LocalDevVPN (nếu VPN chưa bật)
            if !vpnManager.isConnected {
                Button {
                    if let url = URL(string: "localdevvpn://"), UIApplication.shared.canOpenURL(url) {
                        UIApplication.shared.open(url)
                    } else {
                        diagnosticLogs.append("[VPN] ℹ️ Hãy thoát ra màn hình chính và mở app LocalDevVPN")
                    }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "network")
                            .font(.system(size: 13, weight: .bold))
                        Text(isEnglish ? "OPEN LOCALDEVVPN APP" : "🌐 MỞ APP LOCALDEVVPN (KÍCH HOẠT 10.7.0.1)")
                            .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    }
                    .foregroundColor(AppTheme.neonCyan)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(AppTheme.neonCyan.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(AppTheme.neonCyan.opacity(0.35), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            // Nút 2: Nhập file pairing (.plist) từ máy tính (pymobiledevice3 / Files)
            Button {
                showFileImporter = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.arrow.up.fill")
                        .font(.system(size: 14, weight: .bold))
                    Text(isEnglish ? "IMPORT PAIRING FILE (.plist)" : "NHẬP FILE PAIRING (.plist TỪ MÁY TÍNH)")
                        .font(.system(size: 12, weight: .heavy, design: .monospaced))
                }
                .foregroundColor(AppTheme.neonCyan)
                .frame(maxWidth: .infinity)
                .frame(height: 42)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(AppTheme.neonCyan.opacity(0.5), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)

            // Nút 3 (nếu đã có file): Xoá file để thiết lập lại
            if pairing.hasExistingPairing {
                Button {
                    showClearAlert = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text(isEnglish ? "Reset Pairing Record" : "Xoá file Pairing để tạo lại")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(AppTheme.neonRed.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .frame(height: 28)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    // MARK: - Wi-Fi Warning Card
    private var wifiWarningCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(AppTheme.neonAmber)
                Text(isEnglish ? "NO WI-FI CONNECTION DETECTED" : "CHƯA KẾT NỐI WI-FI")
                    .font(.system(size: 11.5, weight: .heavy, design: .monospaced))
                    .foregroundColor(AppTheme.neonAmber)
                Spacer()
            }

            Text(isEnglish
                ? "Bonjour scanning requires Wi-Fi. You can connect to Wi-Fi to pair in iPhone Settings, or import a pairing record (.plist) from your computer."
                : "Quét Bonjour đòi hỏi Wi-Fi. Hãy kết nối Wi-Fi để ghép đôi trong Cài đặt iPhone, hoặc bấm 'Nhập file pairing (.plist)' ở trên.")
                .font(.system(size: 11.5, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
                .lineSpacing(2)
        }
        .padding(14)
        .background(Color(red: 0.18, green: 0.12, blue: 0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.neonAmber.opacity(0.6), lineWidth: 1)
        )
    }

    // MARK: - PIN Code Card
    private var pinCodeCard: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "key.fill")
                    .foregroundColor(AppTheme.neonAmber)
                Text(isEnglish ? "VERIFICATION PIN" : "MÃ PIN XÁC THỰC GHÉP ĐÔI")
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(AppTheme.neonAmber)
                Spacer()
            }

            HStack(spacing: 8) {
                ForEach(Array(pairing.pinCode), id: \.self) { char in
                    Text(String(char))
                        .font(.system(size: 26, weight: .heavy, design: .monospaced))
                        .foregroundColor(AppTheme.neonCyan)
                        .frame(width: 42, height: 50)
                        .background(Color.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(AppTheme.neonCyan.opacity(0.6), lineWidth: 1.5)
                        )
                }
            }
            .padding(.vertical, 4)

            Text(isEnglish ? "Enter this PIN on device if prompted in Settings" : "Nhập mã PIN này trên máy nếu mục Ghép đôi yêu cầu xác nhận.")
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(.white.opacity(0.65))
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .background(Color(red: 0.12, green: 0.10, blue: 0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(AppTheme.neonAmber.opacity(0.5), lineWidth: 1)
        )
    }

    // MARK: - Pairing Steps Card
    private var pairingStepsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "list.number")
                    .foregroundColor(AppTheme.neonCyan)
                Text(pairing.hasExistingPairing
                    ? (isEnglish ? "HOW TO APPLY MOD (3 STEPS)" : "CÁCH NẠP MOD (3 BƯỚC)")
                    : (isEnglish ? "SETUP INSTRUCTIONS" : "HƯỚNG DẪN THIẾT LẬP"))
                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                    .foregroundColor(AppTheme.neonCyan)
                Spacer()
            }

            if pairing.hasExistingPairing {
                stepRow(
                    number: 1,
                    title: isEnglish ? "Install & Open Apple Books" : "Cài & Mở Ứng Dụng Sách (Apple Books)",
                    desc: isEnglish ? "AirTraffic sync requires Books app active" : "Cài ứng dụng Sách từ App Store và mở 1 lần để kích hoạt AirTraffic"
                )

                stepRow(
                    number: 2,
                    title: isEnglish ? "Turn ON LocalDevVPN" : "Bật LocalDevVPN",
                    desc: isEnglish ? "Activate the 10.7.0.1 tunnel interface" : "Bật ứng dụng LocalDevVPN để mở tunnel 10.7.0.1 / 10.7.1.1"
                )

                stepRow(
                    number: 3,
                    title: isEnglish ? "Launch Free Fire Game" : "Mở Game Free Fire",
                    desc: isEnglish ? "Open game so the container is active" : "Mở game lên để container ứng dụng sẵn sàng nhận tệp mod"
                )

                stepRow(
                    number: 4,
                    title: isEnglish ? "Tap Apply Mod / Anti-Ban" : "Bấm Nạp Mod / Anti-Ban",
                    desc: isEnglish ? "System conduit writes patches instantly" : "Cầu nối hệ thống sẽ ghi patch và áp dụng cheat thành công!"
                )
            } else {
                stepRow(
                    number: 1,
                    title: isEnglish ? "Open iOS Developer Mode" : "Mở Cài Đặt > Chế độ Nhà phát triển",
                    desc: isEnglish ? "Go to Settings -> Privacy & Security -> Developer Mode -> Other Devices" : "Vào Cài đặt -> Quyền riêng tư & Bảo mật -> Chế độ nhà phát triển -> Các thiết bị khác"
                )

                stepRow(
                    number: 2,
                    title: isEnglish ? "Tap 'Pair with INNOVA CHEAT'" : "Nhấn 'Ghép đôi với INNOVA CHEAT'",
                    desc: isEnglish ? "Confirm prompt and enter your device passcode" : "Bấm Ghép đôi và nhập mật mã iPhone để lưu ghép đôi hệ thống"
                )

                stepRow(
                    number: 3,
                    title: isEnglish ? "Or Import .plist File" : "Hoặc Nhập File .plist",
                    desc: isEnglish ? "Import pairing record file (.plist) from computer" : "Hoặc bấm nút 'Nhập File Pairing (.plist)' nếu bạn đã có file ghép đôi"
                )
            }
        }
        .padding(14)
        .background(Color(red: 0.08, green: 0.08, blue: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    // MARK: - Tech Details Card
    private var techDetailsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(isEnglish ? "CONDUIT DIAGNOSTICS" : "THÔNG SỐ CẦU NỐI")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
                Spacer()
                Text(pairing.hasExistingPairing ? "FILE PAIRING: TỒN TẠI" : "FILE PAIRING: CHƯA CÓ")
                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                    .foregroundColor(pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonAmber)
            }

            VStack(alignment: .leading, spacing: 3) {
                techRow(label: "Bonjour Type", value: "_remotepairing-pairable-host._tcp.")
                techRow(label: "Hardware Model", value: "Mac17,7 (Apple Silicon Host)")
                techRow(label: "Loopback Tunnel", value: "\(vpnManager.lastConnectedHost)")
                techRow(label: "Keep-Alive Audio", value: "Active (AVAudioEngine background)")
            }
        }
        .padding(12)
        .background(Color.black.opacity(0.35))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        VStack(spacing: 8) {
            if pairing.hasExistingPairing {
                // Nút: Kết nối VPN & Vào game
                Button {
                    Task {
                        _ = await vpnManager.connect()
                    }
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 14, weight: .bold))
                        Text(isEnglish ? "ENABLE VPN & ENTER GAME" : "BẬT LOCALDEVVPN & VÀO GAME")
                            .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    }
                    .foregroundColor(AppTheme.neonLime)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.neonLime.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppTheme.neonLime.opacity(0.4), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 10) {
                Button {
                    showFileImporter = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "doc.badge.arrow.up")
                        Text(isEnglish ? "Import .plist" : "Nhập .plist")
                    }
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(AppTheme.neonCyan)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)

                /*
                Button {
                    AppLog.shared.flush()
                    showShareSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                        Text(isEnglish ? "Export log.txt" : "Xuất log.txt")
                    }
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundColor(AppTheme.neonLime)
                    .frame(maxWidth: .infinity)
                    .frame(height: 34)
                    .background(AppTheme.neonLime.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                */

                Button {
                    pairing.stopAdvertising()
                    presentationMode.wrappedValue.dismiss()
                } label: {
                    Text(isEnglish ? "Close" : "Đóng")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(maxWidth: .infinity)
                        .frame(height: 34)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Helper Views
    private func statusPill(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                .foregroundColor(.white.opacity(0.5))
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan)
                Text(value)
                    .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func stepRow(number: Int, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                .foregroundColor(.black)
                .frame(width: 20, height: 20)
                .background(pairing.hasExistingPairing ? AppTheme.neonLime : AppTheme.neonCyan)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12.5, weight: .bold))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(.white.opacity(0.6))
            }
            Spacer()
        }
    }

    private func techRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white.opacity(0.55))
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.85))
        }
    }
}
