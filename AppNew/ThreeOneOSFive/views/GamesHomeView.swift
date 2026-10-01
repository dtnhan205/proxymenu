import AVKit
import SafariServices
import SwiftUI
import UIKit

struct GamesHomeView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var draftCoordinator: PatchDraftCoordinator
    @StateObject private var store = PatchProjectStore()
    @State private var games: [RemoteGameSummary] = []
    @State private var isLoadingGames = false
    @State private var showingGamePatches = false
    @State private var selectedGame: RemoteGameSummary?
    @State private var dnsInfo: RemoteDnsAntibanInfo?
    @State private var isLoadingDns = false
    @State private var showingDnsSafari = false
    @State private var tutorialVideoInfo: RemoteTutorialVideoInfo?
    @State private var isLoadingVideoInfo = false
    @State private var showingVideoPlayer = false
    @State private var showingBanReportDialog = false
    @State private var isSubmittingFeedback = false
    @State private var feedbackAlertMessage: String?
    @State private var showingFeedbackAlert = false
    @State private var activeAnnouncement: RemoteAnnouncementInfo?
    @State private var showingAnnouncementPopup = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 14)]

    var body: some View {
        NavigationStackCompat {
            ScrollView {
                // Top Brand & Profile Header
                topHeaderSection
                    .padding(.horizontal, 16)
                    .padding(.top, 10)

                // 2-Column Status Row: DEVICE STATUS & DNS ANTIBAN
                twoColumnStatusSection
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Client Feedback & Ban Reporting Card
                clientFeedbackCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Featured Tutorial Video Card
                tutorialVideoCard
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Game Library Section
                gameLibrarySection
                    .padding(.top, 16)

                emptyStatePlaceholder
            }
            .frame(maxWidth: .infinity)
            .appBackground()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { homeToolbar }
            .toolbarBackground(.hidden, for: .navigationBar)
            .refreshable {
                async let g: () = loadGames()
                async let d: () = loadDnsAntiban()
                async let v: () = loadTutorialVideo()
                async let a: () = loadAnnouncementPopup()
                _ = await (g, d, v, a)
            }
            .task {
                async let g: () = loadGames()
                async let d: () = loadDnsAntiban()
                async let v: () = loadTutorialVideo()
                async let a: () = loadAnnouncementPopup()
                _ = await (g, d, v, a)
            }
            .confirmationDialog(
                language.text("home.feedback.dialog_title"),
                isPresented: $showingBanReportDialog,
                titleVisibility: .visible
            ) {
                Button(language.text("home.feedback.banned_3d"), role: .destructive) {
                    Task { await submitFeedback(status: .banned3d) }
                }
                Button(language.text("home.feedback.banned_7d"), role: .destructive) {
                    Task { await submitFeedback(status: .banned7d) }
                }
                Button(language.text("home.feedback.banned_perm"), role: .destructive) {
                    Task { await submitFeedback(status: .bannedPerm) }
                }
                Button(language.text("common.cancel"), role: .cancel) {}
            } message: {
                Text(language.text("home.feedback.dialog_message"))
            }
            .alert(language.text("home.feedback.alert_title"), isPresented: $showingFeedbackAlert) {
                Button(language.text("home.feedback.alert_dismiss"), role: .cancel) {}
            } message: {
                Text(feedbackAlertMessage ?? "")
            }
            .sheet(item: $draftCoordinator.request) { request in
                PatchProjectEditorView(
                    existingProject: nil,
                    passwordIsProtected: false,
                    initialDraft: request.draft
                ) { project, password in
                    store.create(project: project, password: password)
                    draftCoordinator.clear()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                AnnouncementSnoozeManager.recordBackground()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                AnnouncementSnoozeManager.checkForegroundResume()
                Task {
                    await loadAnnouncementPopup()
                }
            }
        }
        .overlay {
            if showingAnnouncementPopup, let announcement = activeAnnouncement {
                AnnouncementPopupDialog(
                    announcement: announcement,
                    onDismiss: {
                        AnnouncementSnoozeManager.markDismissedOrShown()
                        withAnimation(.easeOut(duration: 0.25)) {
                            showingAnnouncementPopup = false
                        }
                    },
                    onSnoozeTwoHours: {
                        AnnouncementSnoozeManager.snoozeTwoHours(for: announcement.id)
                        withAnimation(.easeOut(duration: 0.25)) {
                            showingAnnouncementPopup = false
                        }
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.93)))
                .zIndex(999)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .tint(AppTheme.neonCyan)
        .preferredColorScheme(.dark)
    }

    /// Grid chứa danh sách game — tách riêng để Swift type-checker xử lý
    /// được trong thời gian hợp lý (tránh timeout compile ở build -O).
    private var gamesGrid: some View {
        LazyVGrid(columns: columns, spacing: 14) {
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                gameCardButton(for: game, at: index)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .animation(.easeOut(duration: 0.3), value: games)
        .navigationDestinationCompat(isPresented: $showingGamePatches) {
            if let game = selectedGame {
                GamePatchesView(game: game, store: store)
            }
        }
    }

    private func gameCardButton(for game: RemoteGameSummary, at index: Int) -> some View {
        Button {
            selectedGame = game
            showingGamePatches = true
        } label: {
            GameCardView(
                title: game.name,
                subtitle: game.bundleID.isEmpty ? " " : game.bundleID,
                bannerColor: Color(hex: game.bannerColor) ?? AppTheme.neonCyan,
                iconURL: game.iconURL,
                systemIconName: "app.fill",
                accent: AppTheme.rowColor(index)
            )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var emptyStatePlaceholder: some View {
        if games.isEmpty && !isLoadingGames {
            Text(language.text("patch.no_games_yet"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .padding(.top, 8)
        }
    }

    @ToolbarContentBuilder
    private var homeToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 4) {
                PulsingDot(color: AppTheme.neonLime, size: 6)
                NeonReadout(text: "ONLINE", tint: AppTheme.neonLime)
            }
        }
        ToolbarItem(placement: .navigationBarTrailing) {
            NavigationLink {
                SettingsView()
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(AppTheme.neonCyan)
                    .shadow(color: AppTheme.neonCyan.opacity(0.6), radius: 4)
            }
            .accessibilityLabel(AppBranding.string("tabSettings", locale: language.rawValue))
        }
    }

    private func loadGames() async {
        isLoadingGames = true
        if let fetched = try? await PatchHubService.fetchGames() {
            games = fetched
        }
        isLoadingGames = false
    }

    private func loadDnsAntiban() async {
        isLoadingDns = true
        if let info = try? await PatchHubService.fetchDnsAntibanInfo() {
            dnsInfo = info
        }
        isLoadingDns = false
    }

    private func openDnsInSafari() {
        let url = PatchHubService.dnsAntibanDownloadURL
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func loadTutorialVideo() async {
        isLoadingVideoInfo = true
        if let info = try? await PatchHubService.fetchTutorialVideoInfo() {
            tutorialVideoInfo = info
        }
        isLoadingVideoInfo = false
    }

    private func openTutorialVideoInSafari() {
        let url = tutorialVideoInfo?.resolvedURL ?? PatchHubService.defaultTutorialVideoURL
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }

    private func submitFeedback(status: ClientFeedbackStatus) async {
        guard !isSubmittingFeedback else { return }
        guard ClientFeedbackLimitManager.canSubmit() else {
            await MainActor.run {
                feedbackAlertMessage = language.text("home.feedback.limit_reached")
                showingFeedbackAlert = true
            }
            return
        }
        isSubmittingFeedback = true
        do {
            let res = try await PatchHubService.sendClientFeedback(status: status)
            ClientFeedbackLimitManager.recordSubmission()
            let remaining = ClientFeedbackLimitManager.remainingSubmissionsToday()
            await MainActor.run {
                isSubmittingFeedback = false
                let defaultMsg = status == .safe
                    ? language.text("home.feedback.safe_success")
                    : language.text("home.feedback.ban_success")
                let serverMsg = res.message ?? defaultMsg
                let note = language.text("home.feedback.remaining_note", remaining)
                feedbackAlertMessage = "\(serverMsg)\(note)"
                showingFeedbackAlert = true
            }
        } catch {
            await MainActor.run {
                isSubmittingFeedback = false
                feedbackAlertMessage = language.text("home.feedback.error", error.localizedDescription)
                showingFeedbackAlert = true
            }
        }
    }

    private func loadAnnouncementPopup() async {
        guard AnnouncementSnoozeManager.shouldShowAnnouncement() else { return }
        if let ann = try? await PatchHubService.fetchLatestAnnouncement(), ann.isPopup != false {
            await MainActor.run {
                guard AnnouncementSnoozeManager.shouldShowAnnouncement() else { return }
                AnnouncementSnoozeManager.markDismissedOrShown()
                self.activeAnnouncement = ann
                withAnimation(.spring(response: 0.45, dampingFraction: 0.82)) {
                    self.showingAnnouncementPopup = true
                }
            }
        }
    }

    // MARK: - Top Brand & Profile Header
    private var topHeaderSection: some View {
        VStack(spacing: 10) {
            // Brand bar: Logo & App name + Bell / Settings
            HStack {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [AppTheme.neonCyan, AppTheme.neonMagenta],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.5
                            )
                            .frame(width: 32, height: 32)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            )
                        Image(systemName: "cpu.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.neonCyan, AppTheme.neonIce],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    }

                    Text("PROXYIPA OB55")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [AppTheme.neonCyan, Color.white, AppTheme.neonMagenta],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                }

                Spacer()

                NavigationLink {
                    SettingsView()
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Circle().strokeBorder(AppTheme.neonCyan.opacity(0.35), lineWidth: 1)
                            )
                        Image(systemName: "bell.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(AppTheme.neonCyan)
                    }
                }
            }

            // User greeting / Level & Status bar
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.neonCyan.opacity(0.3), AppTheme.neonMagenta.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                        .overlay(
                            Circle().strokeBorder(AppTheme.neonCyan.opacity(0.8), lineWidth: 1.2)
                        )
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(AppTheme.neonIce)
                }

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Hi, Gay")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                        Text("|")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                        Text("Ver 1.0.5")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppTheme.neonCyan)
                    }
                    Text("Device Verified & System Ready")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                PulsingDot(color: AppTheme.neonLime, size: 6)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
    }

    // MARK: - 2-Column Status Section: DEVICE STATUS & DNS ANTIBAN
    private var twoColumnStatusSection: some View {
        HStack(alignment: .top, spacing: 10) {
            deviceStatusCard
            dnsStatusCard
        }
    }

    private var deviceStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(AppTheme.neonCyan.opacity(0.8), lineWidth: 1)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.neonCyan.opacity(0.12).clipShape(RoundedRectangle(cornerRadius: 6)))
                    Image(systemName: "iphone")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.neonCyan)
                }
                Text(language.text("home.status.title"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.neonCyan)
                    .lineLimit(1)
            }

            VStack(spacing: 5) {
                statusRow(label: language.text("home.status.model"), value: shortHardwareName)
                statusRow(label: language.text("home.status.os"), value: "iOS \(shortOSVersion)")
                statusRow(label: language.text("home.status.root"), value: language.text("home.status.untethered"))
                statusRow(label: language.text("home.status.battery"), value: batteryLevelString)
                statusRow(label: language.text("home.status.storage"), value: storageString)
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.02, green: 0.05, blue: 0.10).opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.neonCyan.opacity(0.75), lineWidth: 1.2)
        )
        .shadow(color: AppTheme.neonCyan.opacity(0.2), radius: 6)
    }

    private var dnsStatusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(AppTheme.neonLime.opacity(0.8), lineWidth: 1)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.neonLime.opacity(0.12).clipShape(RoundedRectangle(cornerRadius: 6)))
                    Image(systemName: "shield.checkerboard")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.neonLime)
                }
                Text(language.text("home.dns.title"))
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .foregroundStyle(AppTheme.neonLime)
                    .lineLimit(1)
            }

            VStack(spacing: 5) {
                HStack {
                    Text(language.text("home.dns.status"))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(language.text("home.dns.protected"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppTheme.neonLime)
                }
                statusRow(label: language.text("home.dns.server"), value: dnsInfo?.fileName ?? "CyberDNS Ultra")
                statusRow(label: language.text("home.dns.region"), value: language.text("home.dns.global"))
            }

            Spacer(minLength: 4)

            // Nút Tải Về DNS Antiban
            HStack(spacing: 5) {
                Button {
                    showingDnsSafari = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(language.text("home.dns.download"))
                            .font(.system(size: 10, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.neonLime, AppTheme.neonCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .shadow(color: AppTheme.neonLime.opacity(0.4), radius: 4, y: 1)
                }
                .buttonStyle(.plain)

                Button {
                    openDnsInSafari()
                } label: {
                    Image(systemName: "safari.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(AppTheme.neonIce)
                        .frame(width: 28, height: 26)
                        .background(Color.white.opacity(0.06))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(AppTheme.neonIce.opacity(0.3), lineWidth: 0.8)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(language.text("home.dns.open_safari"))
            }
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.02, green: 0.08, blue: 0.04).opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(AppTheme.neonLime.opacity(0.75), lineWidth: 1.2)
        )
        .shadow(color: AppTheme.neonLime.opacity(0.2), radius: 6)
        .sheet(isPresented: $showingDnsSafari) {
            SafariView(url: PatchHubService.dnsAntibanDownloadURL)
                .ignoresSafeArea()
        }
    }

    private func statusRow(label: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Text(value)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var shortHardwareName: String {
        let name = AppInfo.hardwareDisplayName
        if name.contains("iPhone") {
            return name.replacingOccurrences(of: "iPhone ", with: "iPhone ")
        }
        return name
    }

    private var batteryLevelString: String {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        if level < 0 { return "84% ⚡" }
        return "\(Int(level * 100))% ⚡"
    }

    private var storageString: String {
        if let attrs = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let total = attrs[.systemSize] as? Int64,
           let free = attrs[.systemFreeSize] as? Int64 {
            let used = total - free
            let totalGB = total / (1024 * 1024 * 1024)
            let usedGB = used / (1024 * 1024 * 1024)
            return language.text("home.status.storage_used", totalGB, usedGB)
        }
        return language.text("home.status.storage_used", 512, 390)
    }

    // MARK: - Client Feedback & Ban Telemetry
    private var clientFeedbackCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(AppTheme.neonAmber.opacity(0.8), lineWidth: 1)
                        .frame(width: 24, height: 24)
                        .background(AppTheme.neonAmber.opacity(0.12).clipShape(RoundedRectangle(cornerRadius: 6)))
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.neonAmber)
                }

                Text(language.text("home.feedback.title"))
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 4) {
                    PulsingDot(color: ClientFeedbackLimitManager.canSubmit() ? AppTheme.neonCyan : Color(red: 1.0, green: 0.35, blue: 0.35), size: 5)
                    Text(language.text("home.feedback.today_count", ClientFeedbackLimitManager.todaySubmissionCount()))
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(ClientFeedbackLimitManager.canSubmit() ? AppTheme.neonCyan : Color(red: 1.0, green: 0.45, blue: 0.45))
                }
            }

            Text(language.text("home.feedback.description"))
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 10) {
                // 1. Nút Báo cáo bị ban
                Button {
                    if !ClientFeedbackLimitManager.canSubmit() {
                        feedbackAlertMessage = language.text("home.feedback.limit_reached")
                        showingFeedbackAlert = true
                    } else {
                        showingBanReportDialog = true
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .font(.system(size: 11, weight: .bold))
                        Text(language.text("home.feedback.report_ban"))
                            .font(.system(size: 11, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [Color(red: 0.95, green: 0.2, blue: 0.35), Color(red: 0.8, green: 0.05, blue: 0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: Color.red.opacity(0.35), radius: 5, y: 1)
                }
                .disabled(isSubmittingFeedback)
                .buttonStyle(.plain)

                // 2. Nút Vẫn đang an toàn
                Button {
                    if !ClientFeedbackLimitManager.canSubmit() {
                        feedbackAlertMessage = language.text("home.feedback.limit_reached")
                        showingFeedbackAlert = true
                    } else {
                        Task { await submitFeedback(status: .safe) }
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isSubmittingFeedback {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(0.65)
                            Text(language.text("home.feedback.sending"))
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.black)
                        } else {
                            Image(systemName: "checkmark.shield.fill")
                                .font(.system(size: 11, weight: .bold))
                            Text(language.text("home.feedback.still_safe"))
                                .font(.system(size: 11, weight: .bold))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.neonLime, AppTheme.neonCyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.black)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .shadow(color: AppTheme.neonLime.opacity(0.35), radius: 5, y: 1)
                }
                .disabled(isSubmittingFeedback)
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.04, green: 0.04, blue: 0.08).opacity(0.9))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            AppTheme.neonAmber.opacity(0.6),
                            AppTheme.neonCyan.opacity(0.3)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: AppTheme.neonAmber.opacity(0.15), radius: 6)
    }

    // MARK: - Featured Tutorial Video Card
    private var tutorialVideoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(AppTheme.neonMagenta.opacity(0.8), lineWidth: 1.2)
                        .frame(width: 28, height: 28)
                        .background(AppTheme.neonMagenta.opacity(0.12).clipShape(RoundedRectangle(cornerRadius: 8)))
                    Image(systemName: "book.pages.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(AppTheme.neonMagenta)
                }

                Text(language.text("home.tutorial.title"))
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.primary)

                Spacer()

                HStack(spacing: 4) {
                    Text(language.text("home.tutorial.badge"))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(AppTheme.neonCyan)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(AppTheme.neonCyan.opacity(0.12))
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(AppTheme.neonCyan.opacity(0.6), lineWidth: 1))
            }

            // Video Preview Container
            Button {
                showingVideoPlayer = true
            } label: {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.08, green: 0.04, blue: 0.16),
                                    Color(red: 0.03, green: 0.02, blue: 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [AppTheme.neonMagenta.opacity(0.6), AppTheme.neonCyan.opacity(0.3)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )

                    // Cyberpunk center play button
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .strokeBorder(AppTheme.neonCyan.opacity(0.4), lineWidth: 1.5)
                                .frame(width: 58, height: 58)

                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [AppTheme.neonMagenta.opacity(0.35), AppTheme.neonCyan.opacity(0.2)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Circle().strokeBorder(AppTheme.neonMagenta.opacity(0.85), lineWidth: 1.5)
                                )
                                .shadow(color: AppTheme.neonMagenta.opacity(0.9), radius: 12)

                            Image(systemName: "play.fill")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(.white)
                                .offset(x: 2)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 135)
                }
            }
            .buttonStyle(.plain)

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(tutorialVideoInfo?.displayTitle(language: language) ?? language.text("home.tutorial.default_title"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.primary)
                Text(language.text("home.tutorial.subtitle"))
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            // Action Buttons
            HStack(spacing: 12) {
                Button {
                    showingVideoPlayer = true
                } label: {
                    HStack(spacing: 6) {
                        Text(language.text("home.tutorial.watch_now"))
                            .font(.system(size: 12, weight: .bold))
                        Image(systemName: "play.fill")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        LinearGradient(
                            colors: [AppTheme.neonMagenta, Color(red: 0.80, green: 0.10, blue: 0.85)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .shadow(color: AppTheme.neonMagenta.opacity(0.5), radius: 8, y: 2)
                }
                .buttonStyle(.plain)

                Button {
                    openTutorialVideoInSafari()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 12, weight: .semibold))
                        Text(language.text("home.tutorial.open_safari"))
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(Color.white.opacity(0.04))
                    .foregroundStyle(AppTheme.neonCyan)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(AppTheme.neonCyan.opacity(0.7), lineWidth: 1.2)
                    )
                    .shadow(color: AppTheme.neonCyan.opacity(0.25), radius: 6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(red: 0.05, green: 0.03, blue: 0.10).opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            AppTheme.neonMagenta.opacity(0.65),
                            AppTheme.neonCyan.opacity(0.4)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
        .shadow(color: AppTheme.neonMagenta.opacity(0.2), radius: 8)
        .sheet(isPresented: $showingVideoPlayer) {
            TutorialVideoModalView(
                videoURL: tutorialVideoInfo?.resolvedURL ?? PatchHubService.defaultTutorialVideoURL,
                title: tutorialVideoInfo?.displayTitle(language: language) ?? language.text("home.tutorial.modal_title")
            )
        }
    }

    // MARK: - Game Library Section
    private var gameLibrarySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LIST GAMES")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(.primary)
                Spacer()
            }
            .padding(.horizontal, 16)

            gamesGrid
        }
    }

    private var shortOSVersion: String {
        let version = AppInfo.osVersion
        if version.hasSuffix(".0") {
            return String(version.dropLast(2))
        }
        return version
    }
}

struct GameCardView: View {
    let title: String
    let subtitle: String
    let bannerColor: Color
    let iconURL: URL?
    let systemIconName: String
    let accent: Color

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                // Banner đã được làm MỜ hơn để ảnh nền (`Background.imageset`) lấp
                // ló qua các thẻ game. Trước đây opacity full → 0.6 → 0.4 che kín
                // ảnh nền; giờ giảm còn 0.55 → 0.28 → 0.18, đồng thời thêm lớp
                // `.blendMode(.plusLighter)` ở cuối để giữ màu neon vẫn pop mà
                // không chặn hoàn toàn background.
                LinearGradient(
                    colors: [
                        bannerColor.opacity(0.55),
                        bannerColor.opacity(0.28),
                        Color.black.opacity(0.18),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.plusLighter)
                // Sheen sweep removed: it was an 8s `repeatForever` LinearGradient
                // offset + rotation + `blendMode(.overlay)` running on EVERY card
                // in the home grid. With 8–15 game cards visible at once that was
                // 8–15 simultaneous always-on animations — the largest single
                // source of frame drops on the home screen. Visual is preserved
                // by the static gradient + icon overlay below.
                iconView
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
            }
            .frame(height: 88)

            VStack(spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(1)
                if !subtitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(subtitle)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(AppTheme.techCardFill)
        }
        .background(Color.black.opacity(0.001))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            accent.opacity(0.6),
                            accent.opacity(0.15),
                            accent.opacity(0.6),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        // Sheen sweep removed for performance — see comment in `body`.
    }

    @ViewBuilder
    private var iconView: some View {
        if let iconURL {
            CachedAsyncImage(url: iconURL) {
                placeholderIcon
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: systemIconName)
            .resizable()
            .scaledToFit()
            .padding(13)
            .foregroundStyle(.white)
    }
}

/// Shows a locally cached copy immediately if one exists (so icons still render offline after
/// their first successful load), then refreshes from the network in the background when
/// possible. See RemoteImageCache for the on-disk persistence.
struct CachedAsyncImage<Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            if let cached = RemoteImageCache.cachedImage(for: url) {
                uiImage = cached
            }
            if let fresh = await RemoteImageCache.fetchAndCache(url) {
                uiImage = fresh
            }
        }
    }
}

extension Color {
    init?(hex: String) {
        var value = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("#") { value.removeFirst() }
        guard value.count == 6, let rgb = UInt32(value, radix: 16) else { return nil }
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255,
            green: Double((rgb >> 8) & 0xFF) / 255,
            blue: Double(rgb & 0xFF) / 255
        )
    }
}

struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = false
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = UIColor(AppTheme.neonCyan)
        vc.dismissButtonStyle = .done
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

struct TutorialVideoModalView: View {
    @Environment(\.appLanguage) private var language
    let videoURL: URL
    let title: String
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStackCompat {
            ZStack {
                Color.black.ignoresSafeArea()

                if let player {
                    VideoPlayer(player: player)
                        .ignoresSafeArea(edges: .bottom)
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: AppTheme.neonMagenta))
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        player?.pause()
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "xmark.circle.fill")
                            Text(language.text("common.close"))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppTheme.neonMagenta)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: videoURL) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(AppTheme.neonCyan)
                    }
                }
            }
            .toolbarBackground(AppTheme.techBackgroundTop.opacity(0.9), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            let avPlayer = AVPlayer(url: videoURL)
            self.player = avPlayer
            avPlayer.play()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Announcement Popup Dialog
struct AnnouncementPopupDialog: View {
    let announcement: RemoteAnnouncementInfo
    let onDismiss: () -> Void
    let onSnoozeTwoHours: () -> Void

    var body: some View {
        ZStack {
            // Dark blur backdrop
            Color.black.opacity(0.72)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Popup Card Container
            VStack(spacing: 0) {
                // Header badge bar
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                LinearGradient(
                                    colors: [AppTheme.neonCyan, AppTheme.neonMagenta],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1.2
                            )
                            .frame(width: 30, height: 30)
                            .background(
                                AppTheme.neonCyan.opacity(0.15)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            )

                        Image(systemName: "megaphone.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(AppTheme.neonCyan)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("THÔNG BÁO HỆ THỐNG")
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppTheme.neonCyan, Color.white],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                        Text("Cập nhật từ máy chủ")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 12)

                Divider()
                    .overlay(
                        LinearGradient(
                            colors: [
                                AppTheme.neonCyan.opacity(0.4),
                                AppTheme.neonMagenta.opacity(0.4)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                // Title & Content
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(announcement.title)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .lineLimit(3)

                        Text(announcement.content)
                            .font(.system(size: 13, weight: .regular))
                            .foregroundStyle(Color.white.opacity(0.88))
                            .lineSpacing(4)
                            .fixedSize(horizontal: false, vertical: true)

                        if let link = announcement.link, let url = URL(string: link), !link.isEmpty {
                            Link(destination: url) {
                                HStack(spacing: 6) {
                                    Image(systemName: "link")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text("Xem chi tiết liên kết")
                                        .font(.system(size: 12, weight: .semibold))
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.app")
                                        .font(.system(size: 11))
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 9)
                                .background(AppTheme.neonCyan.opacity(0.12))
                                .foregroundStyle(AppTheme.neonCyan)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .strokeBorder(AppTheme.neonCyan.opacity(0.5), lineWidth: 1)
                                )
                            }
                            .padding(.top, 4)
                        }
                    }
                    .padding(16)
                }
                .frame(maxHeight: 280)

                // Action Buttons: "Đóng" and "Đóng 2 Giờ"
                HStack(spacing: 10) {
                    // Nút Đóng bình thường
                    Button(action: onDismiss) {
                        HStack(spacing: 6) {
                            Image(systemName: "xmark")
                                .font(.system(size: 12, weight: .bold))
                            Text("Đóng")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.08))
                        .foregroundStyle(.white.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    // Nút Đóng 2 Giờ
                    Button(action: onSnoozeTwoHours) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock.badge.checkmark.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Đóng 2 Giờ")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.neonCyan, AppTheme.neonMagenta],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: AppTheme.neonCyan.opacity(0.4), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .padding(.top, 10)
            }
            .frame(maxWidth: 340)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(red: 0.05, green: 0.04, blue: 0.11).opacity(0.96))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                AppTheme.neonCyan.opacity(0.9),
                                AppTheme.neonMagenta.opacity(0.7),
                                AppTheme.neonCyan.opacity(0.3)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: AppTheme.neonCyan.opacity(0.3), radius: 18)
            .padding(.horizontal, 24)
        }
    }
}

