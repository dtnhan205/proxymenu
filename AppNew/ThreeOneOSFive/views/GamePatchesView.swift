import SwiftUI

// MARK: - ⚙️ CẤU HÌNH HIỂN THỊ LOG PATCH KHI BUILD IPA (DEV / PUBLIC)
// ═══════════════════════════════════════════════════════════════════════════════
// Đổi giá trị biến `mode` dưới đây:
//
//   • "dev"    : Hiển thị log patch, các nút log trên thanh công cụ và tự bung popup log khi lỗi (Dùng để phân tích & sửa lỗi)
//   • "public" : Ẩn hoàn toàn phần log patch và toàn bộ giao diện UI log khỏi app
// ═══════════════════════════════════════════════════════════════════════════════
enum PatchLogConfig {
    static let mode: String = "public" // <--- ĐỔI TẠI ĐÂY: "dev" HOẶC "public"

    /// Kiểm tra xem chế độ log có đang được bật hay không
    static var isEnabled: Bool {
        mode.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "dev"
    }
}

struct GamePatchesView: View {
    @Environment(\.appLanguage) private var language
    @EnvironmentObject private var appState: AppState
    let game: RemoteGameSummary
    @ObservedObject var store: PatchProjectStore

    @State private var isSyncing = false
    @State private var projectStates: [UUID: Bool] = [:]
    @State private var togglingProjectID: UUID?
    @State private var toast: ToastMessage?
    @State private var showKeySheet = false
    @State private var keyBannerVisible = true
    @State private var showPatchLog = false
    @AppStorage("patch.importedOnlineIDs") private var importedOnlineIDsRaw = ""
    @AppStorage("patch.gameAssignments") private var gameAssignmentsRaw = "{}"
    @AppStorage("patch.remoteToLocalMap") private var remoteToLocalMapRaw = "{}"
    @AppStorage("patch.remotePatchNames") private var remotePatchNamesRaw = "{}"
    @AppStorage("patch.activeProjectStates") private var activeProjectStatesRaw = "{}"

    private var activeProjectStates: [String: Bool] {
        (try? JSONDecoder().decode([String: Bool].self, from: Data(activeProjectStatesRaw.utf8))) ?? [:]
    }

    private func saveProjectState(id: UUID, isOn: Bool) {
        var states = activeProjectStates
        states[id.uuidString] = isOn
        if let data = try? JSONEncoder().encode(states), let json = String(data: data, encoding: .utf8) {
            activeProjectStatesRaw = json
        }
    }

    /// Maps both local packageID -> server project name and serverID -> server project name,
    /// ensuring patches always display the project name from the server instead of the 3105 file name.
    private var remotePatchNames: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(remotePatchNamesRaw.utf8))) ?? [:]
    }

    private func displayName(for item: PatchLibraryItem) -> String {
        let localID = item.id.uuidString
        let names = remotePatchNames
        if let serverName = names[localID], !serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return serverName
        }
        if let serverID = remoteToLocalMap.first(where: { $0.value == localID })?.key,
           let serverName = names[serverID], !serverName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return serverName
        }
        if let projectName = item.project?.name, !projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return projectName
        }
        let fileName = item.packageURL.deletingPathExtension().lastPathComponent
        if !fileName.isEmpty {
            return fileName
        }
        return language.text("patch.locked_project")
    }

    @ObservedObject private var appLog = AppLog.shared

    private var importedOnlineIDs: Set<String> {
        Set(importedOnlineIDsRaw.split(separator: ",").map(String.init))
    }

    private var gameAssignments: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(gameAssignmentsRaw.utf8))) ?? [:]
    }

    /// Server patch id -> local packageID, so a patch removed on the server can be traced back
    /// to the local file it downloaded into and deleted, instead of only ever growing the library.
    private var remoteToLocalMap: [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(remoteToLocalMapRaw.utf8))) ?? [:]
    }

    private var items: [PatchLibraryItem] {
        let assignments = gameAssignments
        return store.items.filter { assignments[$0.id.uuidString] == game.id }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    header
                    menuCard
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .appBackground()
            .refreshable {
                await sync()
                await loadProjectStates()
            }

            // Patch log overlay
            if PatchLogConfig.isEnabled && showPatchLog {
                patchLogOverlay
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    if isSyncing {
                        HStack(spacing: 6) {
                            PulsingDot(color: AppTheme.neonCyan, size: 6)
                            NeonReadout(text: "SYNC", tint: AppTheme.neonCyan)
                        }
                    }
                    if PatchLogConfig.isEnabled {
                        // Toggle logging button
                        Button {
                            DevicePatchService.toggleLogging()
                        } label: {
                            Image(systemName: DevicePatchService.isLoggingEnabled ? "terminal.fill" : "terminal")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(DevicePatchService.isLoggingEnabled ? AppTheme.neonCyan : .secondary)
                        }
                        // Show log panel button
                        Button {
                            showPatchLog.toggle()
                        } label: {
                            Image(systemName: showPatchLog ? "list.bullet.rectangle.portrait.fill" : "list.bullet.rectangle.portrait")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(showPatchLog ? AppTheme.neonMagenta : .secondary)
                        }
                    }
                }
            }
        }
        .toolbarBackground(AppTheme.techBackgroundTop.opacity(0.6), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await sync()
            await loadProjectStates()
        }
        .onAppear {
            // Vào game mà chưa nhập key thì bắt nhập ngay, không đợi Toggle.
            if !hasValidKey {
                showKeySheet = true
            }
        }
        .alert(item: $store.alert) { alert in
            Alert(
                title: Text(language.text(alert.titleKey)),
                message: Text(alert.message(language: language)),
                dismissButton: .default(Text(language.text("common.ok")))
            )
        }
        .sheet(isPresented: $showKeySheet) {
            LicenseKeyView { _ in
                toast = ToastMessage(text: "Kích hoạt key thành công")
                // Reset visible toggles so the user sees a fresh state.
                Task { await loadProjectStates() }
            }
        }
        .toast($toast)
    }

    private var hasValidKey: Bool {
        // Nếu không có key đã lưu thì chắc chắn chưa hợp lệ. Có key rồi thì
        // mặc định coi là hợp lệ — đã qua LicenseGateView rồi (gate chỉ mở khi
        // server xác thực thành công). Không ép thêm expiresAt ở đây vì server
        // có thể không trả expiresAt cho vài response shape (vd. verify only),
        // sẽ làm giả → kẹt không bật được toggle.
        LicenseKeyManager.savedKey?.isEmpty == false
    }

    /// The single bordered box holding every patch for this game as a switch row, matching the
    /// reference "PROXY MOD MENU" card instead of a plain grouped list.
    private var menuCard: some View {
        VStack(spacing: 0) {
            menuHeader

            if items.isEmpty {
                emptyState
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        itemRow(item, colorIndex: index)
                        if item.id != items.last?.id {
                            Divider()
                                .overlay(AppTheme.neonCyan.opacity(0.12))
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.bottom, 10)
            }
        }
        .techCard(glow: AppTheme.neonMagenta, opacity: 0.18)
    }

    private var menuHeader: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(AppTheme.neonCyan)
                .frame(width: 3, height: 16)
                .clipShape(RoundedRectangle(cornerRadius: 1.5))
                .shadow(color: AppTheme.neonCyan.opacity(0.8), radius: 4)
            Image(systemName: "bolt.fill")
                .font(.footnote)
                .foregroundStyle(AppTheme.neonCyan)
            Text(language.text("patch.menu_title"))
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(.primary)
                .textCase(.uppercase)
                .tracking(0.6)
            Spacer()
            if isSyncing {
                HStack(spacing: 6) {
                    PulsingDot(color: AppTheme.neonCyan, size: 6)
                    Text(language.text("patch.menu_auto_badge"))
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(AppTheme.neonCyan)
                }
            } else {
                Text(language.text("patch.menu_auto_badge"))
                    .font(.caption2.weight(.bold))
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.neonCyan)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(AppTheme.neonCyan.opacity(0.14), in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(AppTheme.neonCyan.opacity(0.55), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.neonCyan.opacity(0.4), radius: 6)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    private var header: some View {
        VStack(spacing: 8) {
            gameIconView
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [AppTheme.neonCyan.opacity(0.7), AppTheme.neonMagenta.opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: AppTheme.neonCyan.opacity(0.4), radius: 14, y: 6)

            Text(game.name)
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)

            if !game.bundleID.isEmpty {
                Text(game.bundleID)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
        .padding(.bottom, 18)
    }

    @ViewBuilder
    private var gameIconView: some View {
        if let url = game.iconURL {
            CachedAsyncImage(url: url) {
                gameIconPlaceholder
            }
        } else {
            gameIconPlaceholder
        }
    }

    private var gameIconPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: game.bannerColor) ?? AppTheme.neonCyan,
                    AppTheme.neonMagenta.opacity(0.5),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "app.fill")
                .resizable()
                .scaledToFit()
                .padding(20)
                .foregroundStyle(.white)
        }
    }

    @ViewBuilder
    private func itemRow(_ item: PatchLibraryItem, colorIndex: Int) -> some View {
        toggleRow(item, colorIndex: colorIndex)
    }

    private func toggleRow(_ item: PatchLibraryItem, colorIndex: Int) -> some View {
        let rowColor = AppTheme.rowColor(colorIndex)

        return HStack(spacing: 12) {
            Image(systemName: PatchIconCatalog.symbol(for: item.id))
                .font(.title3)
                .foregroundStyle(rowColor)
                .frame(width: 38, height: 38)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [rowColor.opacity(0.25), rowColor.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(rowColor.opacity(0.5), lineWidth: 1)
                )
                .shadow(color: rowColor.opacity(0.35), radius: 6)
            VStack(alignment: .leading, spacing: 3) {
                Text(displayName(for: item))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                NeonShimmerBar(count: item.project?.rules.count ?? 1, tint: rowColor)
                    .padding(.top, 2)
            }
            Spacer()
            if togglingProjectID == item.id {
                ProgressView()
                    .tint(rowColor)
            } else {
                Toggle("", isOn: projectToggleBinding(for: item))
                    .labelsHidden()
                    .neonToggleTint(rowColor)
                    .disabled(!hasValidKey)
            }
        }
        .padding(.vertical, 10)
        .opacity(hasValidKey ? 1.0 : 0.5)
    }

    private func projectToggleBinding(for item: PatchLibraryItem) -> Binding<Bool> {
        Binding(
            get: { projectStates[item.id] ?? false },
            set: { setProjectState($0, item: item) }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            if isSyncing {
                ProgressView()
                    .tint(AppTheme.neonCyan)
            } else {
                Image(systemName: "shippingbox")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(AppTheme.neonCyan)
                    .shadow(color: AppTheme.neonCyan.opacity(0.5), radius: 8)
                Text(language.text("patch.empty_title"))
                    .font(.headline)
                Text(language.text("patch.game_empty_message"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 64)
    }

    /// Downloads only this game's patches from the hub straight into the local library, so
    /// they show up here without any manual tap. Also removes local copies whose server entry
    /// disappeared (deleted on the web, or reassigned to a different game) — a pull-to-refresh
    /// should mirror the server exactly, not just ever grow. The gameId <-> local packageID and
    /// serverID <-> local packageID mappings are recorded locally since the encrypted .3105
    /// format itself carries no game association.
    private func sync() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        guard let remoteItems = try? await PatchHubService.fetchPatches() else { return }
        let remoteForGame = remoteItems.filter { $0.gameId == game.id }
        let remoteIDsForGame = Set(remoteForGame.map(\.id))

        var imported = importedOnlineIDs
        var assignments = gameAssignments
        var remoteMap = remoteToLocalMap
        var patchNames = remotePatchNames
        var didChange = false

        for (serverID, localID) in remoteMap where assignments[localID] == game.id && !remoteIDsForGame.contains(serverID) {
            if let localUUID = UUID(uuidString: localID),
               let staleItem = store.items.first(where: { $0.id == localUUID }) {
                store.delete(staleItem)
            }
            assignments.removeValue(forKey: localID)
            remoteMap.removeValue(forKey: serverID)
            imported.remove(serverID)
            patchNames.removeValue(forKey: localID)
            patchNames.removeValue(forKey: serverID)
            didChange = true
        }

        // Luôn cập nhật tên dự án từ server cho các patch hiện có
        for remoteItem in remoteForGame {
            let sName = remoteItem.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !sName.isEmpty {
                if let localID = remoteMap[remoteItem.id], patchNames[localID] != sName {
                    patchNames[localID] = sName
                    didChange = true
                }
                if patchNames[remoteItem.id] != sName {
                    patchNames[remoteItem.id] = sName
                    didChange = true
                }
            }
        }

        let pending = remoteForGame.filter { !imported.contains($0.id) }
        for item in pending {
            do {
                let fileURL = try await PatchHubService.downloadPatch(item)
                let packageIDString: String? = await Task.detached(priority: .utility) {
                    do {
                        let data = try PatchProjectLibrary.readPackage(at: fileURL)
                        let summary = try PatchPackageCodec.inspect(data)
                        // Không giải mã khi tải về — giữ nguyên file mã hóa .3105
                        _ = try PatchProjectLibrary.save(data: data, projectName: item.name)
                        try? FileManager.default.removeItem(at: fileURL)
                        return summary.packageID.uuidString
                    } catch {
                        return nil
                    }
                }.value
                if let packageIDString {
                    imported.insert(item.id)
                    assignments[packageIDString] = game.id
                    remoteMap[item.id] = packageIDString
                    let sName = item.name.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !sName.isEmpty {
                        patchNames[packageIDString] = sName
                        patchNames[item.id] = sName
                    }
                    didChange = true
                }
            } catch {
                continue
            }
        }

        importedOnlineIDsRaw = imported.joined(separator: ",")
        if let encoded = try? JSONEncoder().encode(assignments), let json = String(data: encoded, encoding: .utf8) {
            gameAssignmentsRaw = json
        }
        if let encoded = try? JSONEncoder().encode(remoteMap), let json = String(data: encoded, encoding: .utf8) {
            remoteToLocalMapRaw = json
        }
        if let encoded = try? JSONEncoder().encode(patchNames), let json = String(data: encoded, encoding: .utf8) {
            remotePatchNamesRaw = json
        }
        if didChange {
            store.reload()
        }
    }

    /// Khôi phục trạng thái bật/tắt của các chức năng từ bộ nhớ đã lưu
    /// mà không cần giải mã trước tất cả các file patch.
    private func loadProjectStates() async {
        let saved = activeProjectStates
        var result: [UUID: Bool] = [:]
        for item in items {
            result[item.id] = saved[item.id.uuidString] ?? false
        }
        projectStates = result
    }

    private func setProjectState(_ isOn: Bool, item: PatchLibraryItem) {
        guard togglingProjectID == nil else { return }

        // License gate: every toggle verifies the saved key with the server
        // before touching the filesystem. A revoked / expired / missing key
        // short-circuits and surfaces the activation sheet for the user.
        guard hasValidKey else {
            toast = ToastMessage(text: "Vui lòng nhập key để sử dụng")
            showKeySheet = true
            return
        }

        if appState.kernelExploitRunning {
            toast = ToastMessage(text: "Hệ thống đang kích hoạt quyền truy cập, vui lòng đợi giây lát...")
            return
        }

        if appState.kernelExploitApplicable && !appState.exploitStatus.isSuccess && !appState.exploitStatus.isFailed {
            appState.runKernelExploitIfNeeded()
            toast = ToastMessage(text: "Đang kích hoạt quyền hệ thống, vui lòng thử lại...")
            return
        }

        togglingProjectID = item.id
        Task.detached(priority: .userInitiated) {
            // Server-side verification first — admin can revoke the key in
            // real time and the next toggle will be blocked accordingly.
            do {
                _ = try await LicenseKeyManager.verifySavedKey()
            } catch let err as LicenseKeyError {
                let msg = err.errorDescription ?? "Key không hợp lệ"
                // Key bị admin revoke / hết hạn giữa lúc user đang patch:
                // revert MỌI rule đang ON trước khi đóng gate. Nếu chỉ là
                // lỗi mạng tạm thời (internalError / invalidResponse) thì
                // KHÔNG revert — patch trên disk vẫn hợp lệ, user chỉ cần
                // bật toggle lại sau khi mạng ổn.
                if !Self.isTransientKeyError(err) {
                    DevicePatchService.restoreAllAppliedPatches()
                }
                await MainActor.run {
                    togglingProjectID = nil
                    toast = ToastMessage(text: "Vui lòng nhập key để sử dụng")
                    showKeySheet = true
                }
                AppLog.shared.append("[license] verify failed before toggle: \(msg)")
                return
            } catch {
                await MainActor.run {
                    togglingProjectID = nil
                    toast = ToastMessage(text: "Lỗi xác thực key. Vui lòng thử lại")
                }
                return
            }

            // ON-DEMAND DECRYPTION: Chỉ giải mã file của đúng chức năng này khi bật/tắt
            let project: PatchProject
            do {
                let data = try PatchProjectLibrary.readPackage(at: item.packageURL)
                let decoded: DecodedPatchPackage
                if item.summary.isPasswordProtected {
                    decoded = try PatchPackageCodec.decode(data, password: PatchPackageCodec.defaultServerPassword)
                } else {
                    decoded = try PatchPackageCodec.decode(data, password: nil)
                }
                project = decoded.project
            } catch let error as PatchPackageError {
                await MainActor.run {
                    togglingProjectID = nil
                    store.alert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: error.localizationKey,
                        messageArgument: error.localizationArgument
                    )
                }
                return
            } catch {
                await MainActor.run {
                    togglingProjectID = nil
                    store.alert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: "patch.error.wrong_password"
                    )
                }
                return
            }

            let toggleableRules = project.rules.filter(\.canToggle)
            guard !toggleableRules.isEmpty else {
                await MainActor.run { togglingProjectID = nil }
                return
            }

            var failure: PatchPackageError?
            for rule in toggleableRules {
                do {
                    try DevicePatchService.setRuleState(isOn, rule: rule)
                } catch let error as PatchPackageError {
                    failure = error
                } catch {
                    failure = .applyFailed
                }
            }
            // Re-read actual on-device state rather than assume success, since a partial
            // failure partway through the loop would otherwise show a state that never
            // really landed on every file.
            let actualState = toggleableRules.allSatisfy { DevicePatchService.currentRuleState(for: $0) == true }
            if actualState && isOn {
                await DevicePatchService.writeGameSessionToken(targetBundleID: game.bundleID)
            } else if !isOn {
                DevicePatchService.deleteGameSessionToken(targetBundleID: game.bundleID)
            }
            // Capture `failure` into a local before hopping to the main actor, so the
            // closure doesn't reference the mutable `var` from the detached task context
            // (which would warn under Swift 6 concurrency rules).
            let capturedFailure = failure
            await MainActor.run {
                togglingProjectID = nil
                projectStates[item.id] = actualState
                saveProjectState(id: item.id, isOn: actualState)
                if let capturedFailure {
                    store.alert = PatchStoreAlert(
                        titleKey: "common.failed",
                        messageKey: capturedFailure.localizationKey,
                        messageArgument: capturedFailure.localizationArgument
                    )
                } else if actualState == isOn {
                    let name = displayName(for: item)
                    let key = isOn ? "patch.toggle_on_success" : "patch.toggle_off_success"
                    toast = ToastMessage(text: language.text(key, name))
                }
                // Show log on failure (chỉ tự động hiện khi mode = "dev")
                if capturedFailure != nil && PatchLogConfig.isEnabled {
                    showPatchLog = true
                }
            }
        }
    }

    // MARK: - Patch Log Overlay

    private var patchLogOverlay: some View {
        VStack(spacing: 0) {
            HStack {
                Text("PATCH LOG")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(AppTheme.neonCyan)
                Spacer()
                Button {
                    var text = ""
                    text += "3105 Log\n"
                    text += "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))\n"
                    text += "Generated: \(Date())\n\n"
                    text += appLog.entries.joined(separator: "\n")
                    UIPasteboard.general.string = text
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.neonCyan)
                }
                Button {
                    appLog.entries.removeAll()
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                Button {
                    showPatchLog = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.9))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(appLog.entries.enumerated()), id: \.offset) { index, entry in
                            Text(entry)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .id(index)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .background(Color.black.opacity(0.95))
                .onChange(of: appLog.entries.count) { count in
                    if count > 0 {
                        withAnimation {
                            proxy.scrollTo(count - 1, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 280)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(AppTheme.neonMagenta.opacity(0.4), lineWidth: 1)
        )
        .shadow(color: AppTheme.neonMagenta.opacity(0.3), radius: 10)
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}

// MARK: - Key error classification
extension GamePatchesView {
    /// Phân biệt lỗi "key thật sự không hợp lệ" (cần revert patch) với
    /// lỗi tạm thời (mất mạng / server lỗi). Lỗi tạm thời KHÔNG revert —
    /// patch trên disk vẫn còn hiệu lực nếu lần toggle trước thành công,
    /// chỉ là round-trip verify bị fail. Nếu revert nhầm, user sẽ bị tắt
    /// chức năng dù key vẫn còn hạn — tệ hơn cả trước khi sửa.
    nonisolated fileprivate static func isTransientKeyError(_ error: LicenseKeyError) -> Bool {
        switch error {
        case .internalError, .missingKey, .invalidResponse:
            return true
        case .keyNotFound, .revoked, .expired, .notActivated,
             .deviceLimitReached, .deviceNotBound,
             .buildMissing, .buildRevoked, .buildUnknown:
            return false
        }
    }
}
