import SwiftUI

@main
struct ThreeOneOSFiveApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var patchDraftCoordinator = PatchDraftCoordinator()
    @StateObject private var supportToastModel = SupportStatusToastModel()
    @AppStorage(AppLanguage.storageKey) private var languageCode = AppLanguage.vietnamese.rawValue

    @Environment(\.scenePhase) private var scenePhase

    private var language: AppLanguage {
        AppLanguage(rawValue: languageCode) ?? .vietnamese
    }

    init() {
        setupLogCapture()
        // Kiểm tra toàn vẹn cơ bản khi khởi động (an toàn cho cả chứng chỉ cá nhân / ESign)
        IntegrityChecker.runStartupChecks()

        // Kết nối router log từ Rust Airlift / idevice vào nhật ký app
        al_log_init({ _, msg in
            guard let msg = msg else { return }
            let line = String(cString: msg)
            RemotePairingAdvertiser.shared.log(line)
        }, nil)

        // Ghi lại thông số chẩn đoán chi tiết vào log.txt để phân tích
        Task { @MainActor in
            AppLog.shared.append("[DIAGNOSTIC] ══════════════════════════════════════════════════════════")
            AppLog.shared.append("[DIAGNOSTIC] 📱 Thiết bị: \(AppInfo.hardwareDisplayName) (\(AppInfo.machineName))")
            AppLog.shared.append("[DIAGNOSTIC] 🍎 iOS: \(AppInfo.osVersion) · Build: \(AppInfo.osBuild)")
            let wifi = RemotePairingAdvertiser.getWiFiAddress() ?? "Không có (Đang tắt Wi-Fi / Dùng 4G)"
            AppLog.shared.append("[DIAGNOSTIC] 📶 Wi-Fi IP en0: \(wifi)")
            let hasPairing = RemotePairingAdvertiser.shared.hasExistingPairing
            let pairingPath = RemotePairingAdvertiser.shared.pairingFilePath
            let pairingSize = (try? FileManager.default.attributesOfItem(atPath: pairingPath)[.size] as? Int) ?? 0
            AppLog.shared.append("[DIAGNOSTIC] 📁 File Pairing: \(hasPairing ? "✅ CÓ SẴN (\(pairingSize) bytes) tại \(pairingPath)" : "⚠️ Chưa có file pairing")")
            let booksInstalled = UIApplication.shared.canOpenURL(URL(string: "ibooks://")!)
            AppLog.shared.append("[DIAGNOSTIC] 📚 Ứng dụng Sách (Apple Books): \(booksInstalled ? "✅ ĐÃ CÀI ĐẶT TRÊN MÁY" : "⚠️ CHƯA PHÁT HIỆN / CẦN CÀI TỪ APP STORE")")
            let vpn = LocalDevVPNBridge.detectVPNInterface()
            AppLog.shared.append("[DIAGNOSTIC] 🌐 LocalDevVPN (utun): \(vpn.active ? "✅ BẬT (\(vpn.deviceIP))" : "ℹ️ Chưa kết nối")")
            let grappaSym = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "ALGetGrappaToken")
            AppLog.shared.append("[DIAGNOSTIC] 🛡️ ALGetGrappaToken dynamic export: \(grappaSym != nil ? "✅ SẴN SÀNG CHO AIRTRAFFIC" : "⚠️ Chưa tìm thấy qua dlsym")")
            AppLog.shared.append("[DIAGNOSTIC] 💾 File log toàn bộ phiên: \(AppLog.logFileURL.path)")
            AppLog.shared.append("[DIAGNOSTIC] ══════════════════════════════════════════════════════════")
        }

        // Đảm bảo symbol ALGetGrappaToken không bị linker strip
        _ = ALGetGrappaToken(0, 0, 0, nil, 0, nil, nil, 0)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Nền ảnh phủ kín toàn bộ màn hình (kể cả safe area).
                // `.scaledToFill()` giữ tỉ lệ ảnh nhưng phóng to để che hết
                // màn hình → phần ảnh thừa sẽ tràn ra ngoài. Nếu KHÔNG clip,
                // ảnh sẽ vẽ ra ngoài frame và bị SwiftUI render ra ngoài viewport
                // ("tràn sang 2 bên"). `.clipped()` cắt phần thừa ngay tại frame.
                //
                // `.frame(... infinity)` đảm bảo ảnh LUÔN được cung cấp kích
                // thước màn hình (không dựa vào intrinsic content size) — fix
                // trường hợp ảnh quá nhỏ so với màn hình iPad lớn.
                //
                // ⚠️ `.ignoresSafeArea()` áp dụng NGOÀI `.frame(...)` để:
                //   1. Background ignore safe area → fill full screen pixel
                //   2. KHÔNG lan truyền ignore-safe-area lên RootView (giữ
                //      foreground trong safe area, không gây tràn layout).
                Color.clear
                    .ignoresSafeArea()
                    .overlay {
                        ZStack(alignment: .topLeading) {
                            Image("Background")
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()

                            Rectangle()
                                .fill(.ultraThinMaterial)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .opacity(0.35)

                            Color.black
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .opacity(0.20)
                        }
                    }

                RootView()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environmentObject(appState)
            .environmentObject(patchDraftCoordinator)
            .environmentObject(supportToastModel)
            .environment(\.appLanguage, language)
            .environment(\.locale, language.locale)
            .onAppear {
                appState.detectSupport()
            }
            .onChange(of: scenePhase) { phase in
                guard phase == .active else { return }
                appState.detectSupport()
            }
        }
    }
}

class AppState: ObservableObject {
    @Published var exploitStatus: ExploitStatus = .notStarted
    @Published var unsupportedMessage: String?
    @Published var kernelExploitRunning = false

    private var autoRunAttempted = false

    var kernelExploitApplicable: Bool {
        AppInfo.versionTuple.major >= 17 &&
        KernelExploit.isApplicable(
            major: AppInfo.versionTuple.major,
            minor: AppInfo.versionTuple.minor,
            patch: AppInfo.versionTuple.patch,
            build: AppInfo.osBuild
        )
    }

    var isSupported: Bool { unsupportedMessage == nil }

    /// Trigger hiển thị toast thông báo support status lên top-left banner.
    /// Được gọi từ RootView ngay sau khi unlock thành công.
    func announceSupportStatus(toastModel: SupportStatusToastModel) {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
        let payload = SupportStatusPayload(
            iosMajor: v.major,
            iosMinor: v.minor,
            iosPatch: v.patch,
            isSupported: supported
        )
        toastModel.present(payload)
    }

    func detectSupport() {
        let v = AppInfo.versionTuple
        let supported = ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
#if targetEnvironment(simulator)
        if ProcessInfo.processInfo.arguments.contains("--simulate-access") {
            exploitStatus = .success(method: "Simulator preview")
        }
#endif

        unsupportedMessage = supported ? nil : "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))"
        if let unsupportedMessage {
            exploitStatus = .unsupported(unsupportedMessage)
            return
        }

        // Đối với iOS 27 và iOS 18.7.2 - 18.7.10: Sử dụng LocalDevVPN tunnel, không chạy kexploit_opa334
        if LocalDevVPNBridge.isBridgeSupportedOS {
            let vpn = LocalDevVPNBridge.detectVPNInterface()
            if vpn.active {
                exploitStatus = .success(method: "LocalDevVPN (\(vpn.interfaceName))")
            } else {
                exploitStatus = .notStarted
            }
            return
        }

        guard kernelExploitApplicable else { return }

        refreshKernelExploitStatus()
        maybeAutoRunKernelExploit()
    }

    private func maybeAutoRunKernelExploit() {
        guard !kernelExploitRunning,
              !exploitStatus.isSuccess,
              !exploitStatus.isFailed,
              !autoRunAttempted else { return }
        autoRunAttempted = true
        log("app: starting kernel exploit automatically")
        runKernelExploitIfNeeded()
    }

    private func refreshKernelExploitStatus() {
        guard !kernelExploitRunning else { return }

        // iOS < 26: kernel R/W success persists (no sandbox probe)
        // iOS >= 26: verify full sandbox escape is still active
        if KernelExploit.requiresSandboxEscape {
            if KernelExploit.hasSandboxAccess() {
                if !exploitStatus.isSuccess {
                    exploitStatus = .success(method: "kexploit")
                    log("app: existing sandbox access is still active; skipping kernel exploit")
                }
            } else if exploitStatus.isSuccess {
                exploitStatus = .notStarted
                log("app: sandbox access is no longer active")
            }
        }
    }

    func runKernelExploitIfNeeded(force: Bool = false) {
        refreshKernelExploitStatus()
        guard !kernelExploitRunning else { return }
        if !force {
            guard !exploitStatus.isSuccess,
                  !exploitStatus.isFailed else { return }
        } else {
            guard !exploitStatus.isSuccess else {
                log("app: kernel exploit already active")
                return
            }
        }
        kernelExploitRunning = true
        exploitStatus = .notStarted
        log(force ? "app: running kernel exploit on background (retry)..." : "app: running kernel exploit on background...")
        DispatchQueue.global(qos: .userInitiated).async {
            let ok = KernelExploit.run()
            DispatchQueue.main.async {
                self.kernelExploitRunning = false
                if ok {
                    self.exploitStatus = .success(method: "kexploit")
                    if KernelExploit.requiresSandboxEscape {
                        log("app: kernel exploit success — sandbox access verified")
                    } else {
                        log("app: kernel exploit success — kernel access active")
                    }
                } else {
                    self.exploitStatus = .failed(method: "kexploit", code: -1)
                    log("app: kernel exploit failed — tap badge to retry, or continue using MHA-C2")
                }
            }
        }
    }
}
