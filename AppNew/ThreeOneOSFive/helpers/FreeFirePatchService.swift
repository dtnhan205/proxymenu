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

    /// Fast cached container path resolver to prevent freezing main thread during slider drag
    static func getOrResolveContainerPath(bundleID: String) -> String? {
        if let cached = cachedContainerPaths[bundleID], FileManager.default.fileExists(atPath: cached) {
            return cached
        }
        let udKey = "cheat.cachedContainerPath." + bundleID
        if let saved = UserDefaults.standard.string(forKey: udKey), FileManager.default.fileExists(atPath: saved) {
            cachedContainerPaths[bundleID] = saved
            return saved
        }
        if let resolved = ContainerStore.resolveAppContainerPath(bundleID: bundleID) {
            cachedContainerPaths[bundleID] = resolved
            UserDefaults.standard.set(resolved, forKey: udKey)
            return resolved
        }
        return nil
    }

    /// Check if Assembly-CSharp-patch.bytes is injected in the specified game container
    static func isInjected(target: FreeFireTarget = selectedTarget) -> Bool {
        guard let containerPath = getOrResolveContainerPath(bundleID: target.rawValue) else {
            return false
        }
        let ifixPath = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents/IFix/Assembly-CSharp-patch.bytes").path
        let altPath = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents/Assembly-CSharp-patch.bytes").path
        return FileManager.default.fileExists(atPath: ifixPath) || FileManager.default.fileExists(atPath: altPath)
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
            "aim_silent": state.aimSilent ? 1 : 0,
            "aim_bot": state.aimBot ? 1 : 0,
            "aim_target": state.aimBotTarget == .head ? 1 : 0,
            "aim_bot_target": state.aimBotTarget.rawValue,
            "no_recoil": state.noRecoil ? 1 : 0,
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
        let fovInt = Int(state.silentFOV)
        let b64Str = String(data: encryptedData, encoding: .utf8) ?? ""

        // Multi-channel 1: Instant system clipboard IPC (Zero permission, 0ms latency across sandboxes)
        UIPasteboard.general.string = "INNOVA_FOV:\(fovInt)|INNOVA_CFG:\(b64Str)"

        var syncedTargets: [String] = []

        // Multi-channel 2: Direct file writes to all discovered container locations
        for t in FreeFireTarget.allCases {
            guard let containerPath = getOrResolveContainerPath(bundleID: t.rawValue) else { continue }
            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
            let docsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
            let ifixURL = docsURL.appendingPathComponent("IFix", isDirectory: true)
            let cachesURL = containerURL.appendingPathComponent("Library/Caches", isDirectory: true)
            let tmpURL = containerURL.appendingPathComponent("tmp", isDirectory: true)

            let targetDirs = [docsURL, ifixURL, cachesURL, tmpURL]
            for dir in targetDirs {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let cfgFile = dir.appendingPathComponent("menu_config.json")
                try? encryptedData.write(to: cfgFile)
            }
            syncedTargets.append(t.displayName)
        }

        // Multi-channel 3: Shared / Downloads locations
        let commonPaths = [
            "/var/mobile/Downloads/menu_config.json",
            "/tmp/menu_config.json",
            "/private/var/tmp/menu_config.json"
        ]
        for p in commonPaths {
            try? encryptedData.write(to: URL(fileURLWithPath: p))
        }

        if let proxyDocs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let proxyCfg = proxyDocs.appendingPathComponent("menu_config.json")
            try? encryptedData.write(to: proxyCfg)
        }

        let now = CACurrentMediaTime()
        if forceLog || (now - lastSyncLogTime > 2.0) {
            lastSyncLogTime = now
            let targetNames = syncedTargets.isEmpty ? target.displayName : syncedTargets.joined(separator: ", ")
            AppLog.shared.append("[CONFIG] 🔒 FOV: \(fovInt)px -> \(targetNames)")
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

    /// Inject patch file and initial config into the selected game
    static func inject(target: FreeFireTarget = selectedTarget) async throws {
        guard let patchData = loadPatchData(), !patchData.isEmpty else {
            AppLog.shared.append("[INJECT] ❌ Không thể giải mã dữ liệu patch từ bộ nhớ nhị phân!")
            throw NSError(
                domain: "FreeFirePatch",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Không thể giải mã dữ liệu patch nhúng trong ứng dụng!"]
            )
        }

        guard let containerPath = getOrResolveContainerPath(bundleID: target.rawValue),
              ContainerStore.isApplicationContainerPath(containerPath) else {
            AppLog.shared.append("[INJECT] ❌ Không tìm thấy container của \(target.displayName)")
            throw NSError(
                domain: "FreeFirePatch",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy game \(target.displayName) trên thiết bị! Vui lòng cài đặt và mở game 1 lần trước."]
            )
        }

        let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
        let docsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        let ifixURL = docsURL.appendingPathComponent("IFix", isDirectory: true)

        try FileManager.default.createDirectory(at: ifixURL, withIntermediateDirectories: true)

        // 1. Write Assembly-CSharp-patch.bytes into Documents/IFix/ and Documents/
        let targetPatch1 = ifixURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
        let targetPatch2 = docsURL.appendingPathComponent("Assembly-CSharp-patch.bytes")

        try patchData.write(to: targetPatch1, options: .atomic)
        try? patchData.write(to: targetPatch2, options: .atomic)

        // 2. Write localConfig.json into Documents/ and Documents/IFix/ (enables IFix testCodePatch)
        let localData = localConfigSourceData()
        let targetLocal1 = docsURL.appendingPathComponent("localConfig.json")
        let targetLocal2 = ifixURL.appendingPathComponent("localConfig.json")

        try? localData.write(to: targetLocal1, options: .atomic)
        try? localData.write(to: targetLocal2, options: .atomic)

        // 3. Write menu_config.json
        syncConfig(target: target, forceLog: true)

        AppLog.shared.append("[INJECT] ✅ Đã Inject thành công (Assembly-CSharp-patch.bytes & localConfig.json) vào \(target.displayName)")
    }

    /// Uninject: delete the patch bytes and config from game container
    static func uninject(target: FreeFireTarget = selectedTarget) {
        guard let containerPath = getOrResolveContainerPath(bundleID: target.rawValue) else {
            AppLog.shared.append("[UNINJECT] ⚠️ Không tìm thấy container \(target.displayName)")
            return
        }

        let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
        let docsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        let ifixURL = docsURL.appendingPathComponent("IFix", isDirectory: true)

        let pathsToDelete = [
            ifixURL.appendingPathComponent("Assembly-CSharp-patch.bytes"),
            docsURL.appendingPathComponent("Assembly-CSharp-patch.bytes"),
            docsURL.appendingPathComponent("menu_config.json"),
            docsURL.appendingPathComponent("localConfig.json"),
            ifixURL.appendingPathComponent("localConfig.json")
        ]

        for p in pathsToDelete {
            if FileManager.default.fileExists(atPath: p.path) {
                try? FileManager.default.removeItem(at: p)
            }
        }

        // Also clean up download config
        let dlFiles = [
            URL(fileURLWithPath: "/var/mobile/Downloads/menu_config.json"),
            URL(fileURLWithPath: "/var/mobile/Downloads/localConfig.json")
        ]
        for dl in dlFiles {
            if FileManager.default.fileExists(atPath: dl.path) {
                try? FileManager.default.removeItem(at: dl)
            }
        }

        AppLog.shared.append("[UNINJECT] 🗑️ Đã xóa toàn bộ file patch & localConfig.json khỏi \(target.displayName)")
    }
}
