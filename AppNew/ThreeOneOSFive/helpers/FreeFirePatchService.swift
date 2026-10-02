import Foundation
import UIKit

// MARK: - Target Game Bundle Identifier
enum FreeFireTarget: String, CaseIterable, Identifiable {
    case freeFireTH = "com.dts.freefireth"
    case freeFireMAX = "com.dts.freefiremax"

    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .freeFireTH: return "Free Fire Thường"
        case .freeFireMAX: return "Free Fire MAX"
        }
    }
}

// MARK: - FreeFire Patch Service
enum FreeFirePatchService {
    private static let targetKey = "cheat.selectedTarget"
    private static var cachedContainerPaths: [String: String] = [:]

    static var selectedTarget: FreeFireTarget {
        get {
            let val = UserDefaults.standard.string(forKey: targetKey) ?? FreeFireTarget.freeFireTH.rawValue
            return FreeFireTarget(rawValue: val) ?? .freeFireTH
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: targetKey)
        }
    }

    /// Scan /var/containers/Bundle/Application/ for FreeFire.app / FreeFireMAX.app
    /// Succeeds when Sandbox Escape (Kernel Exploit) is active.
    static func findBundleAppURL(target: FreeFireTarget) -> URL? {
        let bundleBase = "/var/containers/Bundle/Application"
        guard let bundleUUIDs = try? FileManager.default.contentsOfDirectory(atPath: bundleBase) else {
            return nil
        }
        for uuid in bundleUUIDs {
            let bundleDir = "\(bundleBase)/\(uuid)"
            guard let contents = try? FileManager.default.contentsOfDirectory(atPath: bundleDir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let appPath = "\(bundleDir)/\(item)"
                let infoPlist = "\(appPath)/Info.plist"
                if let plistData = FileManager.default.contents(atPath: infoPlist),
                   let plist = try? PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any],
                   let bid = plist["CFBundleIdentifier"] as? String,
                   bid == target.rawValue {
                    return URL(fileURLWithPath: appPath, isDirectory: true)
                }
            }
        }
        return nil
    }

    /// Container path resolver using MHA-C2 with fallback to Kernel Exploit metadata scan
    static func getOrResolveContainerPath(bundleID: String) -> String? {
        if let cached = cachedContainerPaths[bundleID], !cached.isEmpty {
            if FileManager.default.fileExists(atPath: cached) {
                return cached
            }
            cachedContainerPaths.removeValue(forKey: bundleID)
        }
        if let resolved = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
           ContainerStore.isApplicationContainerPath(resolved) {
            cachedContainerPaths[bundleID] = resolved
            return resolved
        }
        return nil
    }

    /// Check if Assembly-CSharp-patch.bytes is injected in the specified game container (Data or Bundle)
    static func isInjected(target: FreeFireTarget = selectedTarget) -> Bool {
        if let containerPath = getOrResolveContainerPath(bundleID: target.rawValue) {
            let altPath = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents/Assembly-CSharp-patch.bytes").path
            if FileManager.default.fileExists(atPath: altPath) {
                return true
            }
        }
        if let appURL = findBundleAppURL(target: target) {
            let p = appURL.appendingPathComponent("Data/Raw/Assembly-CSharp-patch.bytes").path
            if FileManager.default.fileExists(atPath: p) {
                return true
            }
        }
        return false
    }

    /// Load patch data: first checks in-memory embedded decrypted bytes (anti-rip),
    /// with fallback to external file in Downloads/Documents if developer provides one.
    static func loadPatchData() -> Data? {
        // 1. External override in Downloads (for quick dev testing)
        let dl = URL(fileURLWithPath: "/var/mobile/Downloads/Assembly-CSharp-patch.bytes")
        if let data = try? Data(contentsOf: dl), !data.isEmpty {
            return data
        }
        // 2. External override in proxy Documents
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docFile = docs.appendingPathComponent("Assembly-CSharp-patch.bytes")
            if let data = try? Data(contentsOf: docFile), !data.isEmpty {
                return data
            }
        }
        // 3. Embedded encrypted Mach-O binary data (completely invisible in IPA package)
        if let embedded = EmbeddedPatchData.loadPatchBytes(), !embedded.isEmpty {
            return embedded
        }
        // 4. Legacy bundle resource fallback if present
        if let url = Bundle.main.url(forResource: "Assembly-CSharp-patch", withExtension: "bytes"),
           let data = try? Data(contentsOf: url), !data.isEmpty {
            return data
        }
        let bundleDirect = Bundle.main.bundleURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
        if let data = try? Data(contentsOf: bundleDirect), !data.isEmpty {
            return data
        }
        return nil
    }

    /// Generate menu_config.json dictionary from current CheatMenuState
    static func makeConfigPayload(state: CheatMenuState = CheatMenuState.shared) -> [String: Any] {
        let rateIndex: Int
        if state.headshotRate <= 10.0 { rateIndex = 0 }
        else if state.headshotRate <= 35.0 { rateIndex = 1 }
        else if state.headshotRate <= 60.0 { rateIndex = 2 }
        else if state.headshotRate <= 85.0 { rateIndex = 3 }
        else { rateIndex = 4 }

        return [
            "box_esp": state.boxESP ? 1 : 0,
            "line_esp": state.lineESP ? 1 : 0,
            "health_bar": state.healthBar ? 1 : 0,
            "name_tag": state.nameTag ? 1 : 0,
            "distance_tag": state.distanceTag ? 1 : 0,
            "skeleton_esp": state.skeletonESP ? 1 : 0,
            "aim_silent": (state.aimSilent && !state.aimBot) ? 1 : 0,
            "aim_bot": (state.aimBot && !state.aimSilent) ? 1 : 0,
            "aim_target": state.aimBotTarget == .head ? 1 : 0,
            "aim_bot_target": state.aimBotTarget.rawValue,
            "no_recoil": state.noRecoil ? 1 : 0,
            "draw_fov": state.drawFOV ? 1 : 0,
            "aim_fov": Int(state.silentFOV),
            "headshot_rate": rateIndex,
            "color": state.espSelectedColorId,
            "box_color": state.boxColorId,
            "line_color": state.lineColorId,
            "skeleton_color": state.skeletonColorId,
            "box_r": Int(state.boxR),
            "box_g": Int(state.boxG),
            "box_b": Int(state.boxB),
            "box_thickness": state.boxThickness,
            "line_r": Int(state.lineR),
            "line_g": Int(state.lineG),
            "line_b": Int(state.lineB),
            "line_thickness": state.lineThickness,
            "health_r": Int(state.healthR),
            "health_g": Int(state.healthG),
            "health_b": Int(state.healthB),
            "health_thickness": state.healthThickness,
            "tag_r": Int(state.tagR),
            "tag_g": Int(state.tagG),
            "tag_b": Int(state.tagB),
            "tag_thickness": state.tagThickness,
            "buff_damage": state.buffDamage ? 1 : 0,
            "fast_fire": state.fastFire ? 1 : 0,
            "wide_view": state.wideView ? 1 : 0,
            "cam_distance": Int(state.camDistance),
            "speed_run": state.speedRun ? 1 : 0,
            "fast_parachute": state.fastParachute ? 1 : 0,
            "line_bottom": 0
        ]
    }

    // 16-byte XOR key matching the in-game patch decryption
    private static let configCipherKey: [UInt8] = [
        75, 158, 51, 127, 26, 136, 210, 101, 12, 241, 84, 155, 39, 234, 99, 24
    ]

    /// Encrypts configuration JSON into an unreadable cipher string (anti-crack / anti-reverse)
    static func encryptConfigData(_ rawJsonData: Data) -> Data {
        var bytes = [UInt8](rawJsonData)
        let kCount = configCipherKey.count
        for i in 0..<bytes.count {
            bytes[i] ^= configCipherKey[i % kCount]
        }
        let b64 = Data(bytes).base64EncodedString()
        return b64.data(using: .utf8) ?? rawJsonData
    }

    private static var lastSyncLogTime: TimeInterval = 0

    /// Sync the current configuration to all game containers and multi-channel IPC
    static func syncConfig(target: FreeFireTarget = selectedTarget, state: CheatMenuState = CheatMenuState.shared, forceLog: Bool = false) {
        let payload = makeConfigPayload(state: state)
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: []) else {
            return
        }

        let encryptedData = encryptConfigData(jsonData)
        var syncedTargets: [String] = []

        // Multi-tier 0: BUNDLE container (Kernel Exploit - Highest Priority)
        for t in FreeFireTarget.allCases {
            if let appURL = findBundleAppURL(target: t) {
                let dataRaw = appURL.appendingPathComponent("Data/Raw/menu_config.json")
                let dataDir = appURL.appendingPathComponent("Data/menu_config.json")
                let appRoot = appURL.appendingPathComponent("menu_config.json")
                for u in [dataRaw, dataDir, appRoot] {
                    let folder = u.deletingLastPathComponent()
                    if !FileManager.default.fileExists(atPath: folder.path) {
                        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    }
                    try? encryptedData.write(to: u, options: .atomic)
                }
            }
        }

        // Multi-tier 1: DATA container Documents, Caches, tmp (MHA-C2)
        for t in FreeFireTarget.allCases {
            guard let containerPath = getOrResolveContainerPath(bundleID: t.rawValue) else { continue }
            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
            let docsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
            let cachesURL = containerURL.appendingPathComponent("Library/Caches", isDirectory: true)
            let tmpURL = containerURL.appendingPathComponent("tmp", isDirectory: true)

            for dir in [docsURL, cachesURL, tmpURL] {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let cfgFile = dir.appendingPathComponent("menu_config.json")
                try? encryptedData.write(to: cfgFile, options: .atomic)
            }
            syncedTargets.append(t.displayName)
        }

        // Multi-tier 2: App Group (group.com.proxyvip.shared)
        if let agURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.proxyvip.shared") {
            let agCfg = agURL.appendingPathComponent("menu_config.json")
            try? encryptedData.write(to: agCfg, options: .atomic)
        }

        // Multi-tier 3: Shared / Downloads locations
        let commonPaths = [
            "/var/mobile/Downloads/menu_config.json",
            "/tmp/menu_config.json",
            "/private/var/tmp/menu_config.json"
        ]
        for p in commonPaths {
            try? encryptedData.write(to: URL(fileURLWithPath: p), options: .atomic)
        }

        // Multi-tier 4: Proxy Documents
        if let proxyDocs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let proxyCfg = proxyDocs.appendingPathComponent("menu_config.json")
            try? encryptedData.write(to: proxyCfg, options: .atomic)
        }

        if forceLog {
            let targetNames = syncedTargets.isEmpty ? target.displayName : syncedTargets.joined(separator: ", ")
            AppLog.shared.append("[CONFIG] 🔒 FOV: \(Int(state.silentFOV))px -> \(targetNames)")
        }
    }

    /// Locate localConfig.json data: loads from EmbeddedPatchData in memory (no file in IPA),
    /// with fallback to external file if developer overrides.
    static func localConfigSourceData() -> Data {
        // 1. External override in Downloads
        let dl = URL(fileURLWithPath: "/var/mobile/Downloads/localConfig.json")
        if let data = try? Data(contentsOf: dl), !data.isEmpty {
            return data
        }
        // 2. Embedded in-memory payload (invisible in IPA)
        return EmbeddedPatchData.loadLocalConfigBytes()
    }

    /// Inject patch file and initial config into the selected game using Multi-Tier Kernel Exploit + MHA-C2
    static func inject(target: FreeFireTarget = selectedTarget) async throws {
        guard let patchData = loadPatchData(), !patchData.isEmpty else {
            AppLog.shared.append("[INJECT] ❌ Không thể giải mã dữ liệu patch từ bộ nhớ nhị phân!")
            throw NSError(
                domain: "FreeFirePatch",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Không thể giải mã dữ liệu patch nhúng trong ứng dụng!"]
            )
        }

        let localData = localConfigSourceData()
        let payload = makeConfigPayload(state: CheatMenuState.shared)
        let jsonData = (try? JSONSerialization.data(withJSONObject: payload, options: [])) ?? Data()
        let encryptedConfig = encryptConfigData(jsonData)

        var didInjectAny = false

        // --- TIER 0: BUNDLE CONTAINER (Kernel Exploit - Highest Priority) ---
        if let appURL = findBundleAppURL(target: target) {
            let dataRawURL = appURL.appendingPathComponent("Data/Raw", isDirectory: true)
            let dataURL = appURL.appendingPathComponent("Data", isDirectory: true)

            for dir in [dataRawURL, dataURL, appURL] {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let patchURL = dir.appendingPathComponent("Assembly-CSharp-patch.bytes")
                let cfgURL = dir.appendingPathComponent("menu_config.json")
                let localURL = dir.appendingPathComponent("localConfig.json")

                if (try? patchData.write(to: patchURL, options: .atomic)) != nil {
                    didInjectAny = true
                }
                try? encryptedConfig.write(to: cfgURL, options: .atomic)
                try? localData.write(to: localURL, options: .atomic)
            }
            AppLog.shared.append("[INJECT] ⚡ Kernel Exploit: Đã ghi module vào Bundle Container (\(appURL.lastPathComponent)/Data/Raw)")
        }

        // --- TIER 1: DATA CONTAINER (MHA-C2 - ContainerStore) ---
        if let containerPath = getOrResolveContainerPath(bundleID: target.rawValue),
           ContainerStore.isApplicationContainerPath(containerPath) {
            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
            let docsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
            let cachesURL = containerURL.appendingPathComponent("Library/Caches", isDirectory: true)
            let tmpURL = containerURL.appendingPathComponent("tmp", isDirectory: true)

            for dir in [docsURL, cachesURL, tmpURL] {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let patchFile = dir.appendingPathComponent("Assembly-CSharp-patch.bytes")
                let cfgFile = dir.appendingPathComponent("menu_config.json")
                let localFile = dir.appendingPathComponent("localConfig.json")

                if (try? patchData.write(to: patchFile, options: .atomic)) != nil {
                    didInjectAny = true
                }
                try? encryptedConfig.write(to: cfgFile, options: .atomic)
                try? localData.write(to: localFile, options: .atomic)
            }
            AppLog.shared.append("[INJECT] 🛡️ MHA-C2: Đã ghi module vào Documents/ (\(target.displayName))")
        }

        // --- TIER 2: APP GROUP (group.com.proxyvip.shared) ---
        if let agURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.proxyvip.shared") {
            try? patchData.write(to: agURL.appendingPathComponent("Assembly-CSharp-patch.bytes"), options: .atomic)
            try? encryptedConfig.write(to: agURL.appendingPathComponent("menu_config.json"), options: .atomic)
            try? localData.write(to: agURL.appendingPathComponent("localConfig.json"), options: .atomic)
        }

        // --- TIER 3: DOWNLOADS (/var/mobile/Downloads/) ---
        let dlPatch = URL(fileURLWithPath: "/var/mobile/Downloads/Assembly-CSharp-patch.bytes")
        let dlCfg = URL(fileURLWithPath: "/var/mobile/Downloads/menu_config.json")
        let dlLocal = URL(fileURLWithPath: "/var/mobile/Downloads/localConfig.json")
        try? patchData.write(to: dlPatch, options: .atomic)
        try? encryptedConfig.write(to: dlCfg, options: .atomic)
        try? localData.write(to: dlLocal, options: .atomic)

        // --- TIER 4: PROXY DOCUMENTS ---
        if let proxyDocs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? patchData.write(to: proxyDocs.appendingPathComponent("Assembly-CSharp-patch.bytes"), options: .atomic)
            try? encryptedConfig.write(to: proxyDocs.appendingPathComponent("menu_config.json"), options: .atomic)
            try? localData.write(to: proxyDocs.appendingPathComponent("localConfig.json"), options: .atomic)
        }

        guard didInjectAny else {
            AppLog.shared.append("[INJECT] ❌ Không thể can thiệp container của \(target.displayName) qua cả MHA-C2 và Kernel Exploit")
            throw NSError(
                domain: "FreeFirePatch",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy game \(target.displayName) trên thiết bị! Vui lòng cài đặt và mở game 1 lần trước."]
            )
        }

        AppLog.shared.append("[INJECT] ✅ Hoàn tất nạp module cheat vào \(target.displayName)")
    }

    /// Uninject: delete the patch bytes and config from all tiers
    static func uninject(target: FreeFireTarget = selectedTarget) {
        // Tier 0: Bundle Container
        if let appURL = findBundleAppURL(target: target) {
            let files = [
                appURL.appendingPathComponent("Data/Raw/Assembly-CSharp-patch.bytes"),
                appURL.appendingPathComponent("Data/Raw/menu_config.json"),
                appURL.appendingPathComponent("Data/Raw/localConfig.json"),
                appURL.appendingPathComponent("Data/Assembly-CSharp-patch.bytes"),
                appURL.appendingPathComponent("Data/menu_config.json"),
                appURL.appendingPathComponent("Data/localConfig.json"),
                appURL.appendingPathComponent("Assembly-CSharp-patch.bytes"),
                appURL.appendingPathComponent("menu_config.json"),
                appURL.appendingPathComponent("localConfig.json")
            ]
            for f in files {
                try? FileManager.default.removeItem(at: f)
            }
        }

        // Tier 1: Data Container Documents, Caches, tmp
        if let containerPath = getOrResolveContainerPath(bundleID: target.rawValue) {
            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
            let dirs = [
                containerURL.appendingPathComponent("Documents", isDirectory: true),
                containerURL.appendingPathComponent("Library/Caches", isDirectory: true),
                containerURL.appendingPathComponent("tmp", isDirectory: true)
            ]
            for dir in dirs {
                let pathsToDelete = [
                    dir.appendingPathComponent("Assembly-CSharp-patch.bytes"),
                    dir.appendingPathComponent("menu_config.json"),
                    dir.appendingPathComponent("localConfig.json")
                ]
                for p in pathsToDelete {
                    try? FileManager.default.removeItem(at: p)
                }
            }

            // Clean legacy IFix if exists
            let ifixURL = containerURL.appendingPathComponent("Documents/IFix", isDirectory: true)
            try? FileManager.default.removeItem(at: ifixURL)
        }

        // Tier 2: App Group
        if let agURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.proxyvip.shared") {
            try? FileManager.default.removeItem(at: agURL.appendingPathComponent("Assembly-CSharp-patch.bytes"))
            try? FileManager.default.removeItem(at: agURL.appendingPathComponent("menu_config.json"))
            try? FileManager.default.removeItem(at: agURL.appendingPathComponent("localConfig.json"))
        }

        // Tier 3: Downloads
        for f in ["Assembly-CSharp-patch.bytes", "menu_config.json", "localConfig.json"] {
            try? FileManager.default.removeItem(atPath: "/var/mobile/Downloads/\(f)")
        }

        AppLog.shared.append("[UNINJECT] 🗑️ Đã xóa toàn bộ file patch & config khỏi \(target.displayName)")
    }
}
