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
    /// with fallback to external file in Downloads/Documents only if embedded is missing.
    static func loadPatchData() -> Data? {
        // 1. Embedded encrypted Mach-O binary data (Luôn ưu tiên bản patch mới nhất biên dịch cùng App)
        if let embedded = EmbeddedPatchData.loadPatchBytes(), !embedded.isEmpty {
            return embedded
        }
        // 2. External override in Downloads (chỉ dùng khi embedded rỗng)
        let dl = URL(fileURLWithPath: "/var/mobile/Downloads/Assembly-CSharp-patch.bytes")
        if let data = try? Data(contentsOf: dl), !data.isEmpty {
            return data
        }
        // 3. External override in proxy Documents
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docFile = docs.appendingPathComponent("Assembly-CSharp-patch.bytes")
            if let data = try? Data(contentsOf: docFile), !data.isEmpty {
                return data
            }
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

    // Slot placeholder for on-the-fly binary stamping (Method 2)
    private static let stampedDeviceSlotPlaceholder = "INNOVA_DEV_SLOT_0000000000000000"
    // Obfuscated secret salt for hardware signature token (Method 1)
    private static let authSaltBytes: [UInt8] = [
        0x33, 0x57, 0x8A, 0xCC, 0x0B, 0x6F, 0xC4, 0x74,
        0xC0, 0x38, 0x59, 0x8D, 0x6D, 0xE0, 0x57, 0xDE,
        0xC0, 0x0A, 0x6E, 0xA6, 0x3F, 0x5F, 0x90, 0x7C,
        0x0F, 0xE0, 0x32, 0x49, 0xDB, 0x69, 0x87
    ]
    private static let authSaltKey: [UInt8] = [
        0x7A, 0x19, 0xC4, 0x83, 0x5D, 0x2E, 0x9B, 0x47,
        0xF1, 0x08, 0x6C, 0xD2, 0x3E, 0xA5, 0x14, 0x8B,
        0x92, 0x4F, 0x31, 0xE7, 0x6A, 0x0B, 0xD8, 0x23,
        0x5C, 0xA1, 0x7E, 0x1D, 0x84, 0x3F, 0xB6
    ]
    private static var authSecretSalt: String {
        Obfuscated.decode(authSaltBytes, key: authSaltKey)
    }

    // Obfuscated token file name (".innova_token.dat")
    private static let tokenFileNameBytes: [UInt8] = [
        0xC6, 0xBA, 0x58, 0x77, 0x13, 0xD1, 0xEB, 0xB2,
        0xA4, 0x54, 0x75, 0x24, 0xCA, 0xA1, 0x96, 0xB4, 0x4C
    ]
    private static let tokenFileNameKey: [UInt8] = [
        0xE8, 0xD3, 0x36, 0x19, 0x7C, 0xA7, 0x8A, 0xED,
        0xD0, 0x3B, 0x1E, 0x41, 0xA4, 0x8F, 0xF2, 0xD5, 0x38
    ]
    static var tokenFileName: String {
        Obfuscated.decode(tokenFileNameBytes, key: tokenFileNameKey)
    }

    /// Compute hardware signature matching ESPLogic C# implementation
    static func computeHardwareSig(devId: String, cid: String) -> String {
        let combined = "\(devId):\(cid):\(authSecretSalt)"
        guard let bytes = combined.data(using: .utf8) else { return "" }

        var h0: UInt32 = 0x67452301
        var h1: UInt32 = 0xEFCDAB89
        var h2: UInt32 = 0x98BADCFE
        var h3: UInt32 = 0x10325476

        for (i, b) in bytes.enumerated() {
            let bVal = UInt32(b)
            let shift = UInt32(i % 24)
            h0 = (h0 ^ (bVal << shift)) &* 0x01000193
            h1 = (h1 &+ bVal) &* 0x85EBCA6B
            h2 = (h2 ^ (bVal &* 0x9E3779B9)) &+ (h0 >> 5)
            h3 = (h3 &+ (bVal ^ h1)) &* 0xC2B2AE35
        }

        return String(format: "%08x%08x%08x%08x", h0, h1, h2, h3)
    }

    /// Extract container UUID from path
    static func extractContainerUUID(from path: String) -> String {
        let url = URL(fileURLWithPath: path)
        return url.lastPathComponent
    }

    /// Generate standalone encrypted .innova_token.dat payload
    static func makeTokenData(cid: String) -> Data {
        let devId = DeviceIdentity.serial()
        let sig = computeHardwareSig(devId: devId, cid: cid)
        let tokenDict: [String: Any] = [
            "dev_id": devId,
            "cid": cid,
            "dev_sig": sig,
            "dev_status": "AUTHORIZED",
            "ts": Int(Date().timeIntervalSince1970)
        ]
        let jsonData = (try? JSONSerialization.data(withJSONObject: tokenDict, options: [])) ?? Data()
        return encryptConfigData(jsonData)
    }

    /// Generate menu_config.json dictionary from current CheatMenuState with hardware binding
    static func makeConfigPayload(state: CheatMenuState = CheatMenuState.shared, cid: String = "") -> [String: Any] {
        let rateIndex: Int
        if state.headshotRate <= 10.0 { rateIndex = 0 }
        else if state.headshotRate <= 35.0 { rateIndex = 1 }
        else if state.headshotRate <= 60.0 { rateIndex = 2 }
        else if state.headshotRate <= 85.0 { rateIndex = 3 }
        else { rateIndex = 4 }

        let devId = DeviceIdentity.serial()
        let sig = computeHardwareSig(devId: devId, cid: cid)

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
            "line_bottom": 0,
            "dev_id": devId,
            "cid": cid,
            "dev_sig": sig,
            "dev_status": "AUTHORIZED"
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

    /// Sync the current configuration to all game containers and multi-channel IPC
    static func syncConfig(target: FreeFireTarget = selectedTarget, state: CheatMenuState = CheatMenuState.shared, forceLog: Bool = false) {
        var syncedTargets: [String] = []

        // Multi-tier 0: BUNDLE container (Kernel Exploit - Highest Priority)
        let bundlePayload = makeConfigPayload(state: state, cid: "")
        let bundleJson = (try? JSONSerialization.data(withJSONObject: bundlePayload, options: [])) ?? Data()
        let bundleEncrypted = encryptConfigData(bundleJson)
        let bundleToken = makeTokenData(cid: "")

        for t in FreeFireTarget.allCases {
            if let appURL = findBundleAppURL(target: t) {
                let dataRaw = appURL.appendingPathComponent("Data/Raw/menu_config.json")
                let dataDir = appURL.appendingPathComponent("Data/menu_config.json")
                let appRoot = appURL.appendingPathComponent("menu_config.json")
                let tokenRaw = appURL.appendingPathComponent("Data/Raw/\(tokenFileName)")
                let tokenDir = appURL.appendingPathComponent("Data/\(tokenFileName)")
                let tokenRoot = appURL.appendingPathComponent(tokenFileName)

                for u in [dataRaw, dataDir, appRoot] {
                    let folder = u.deletingLastPathComponent()
                    if !FileManager.default.fileExists(atPath: folder.path) {
                        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    }
                    try? bundleEncrypted.write(to: u, options: .atomic)
                }
                for tu in [tokenRaw, tokenDir, tokenRoot] {
                    try? bundleToken.write(to: tu, options: .atomic)
                }
            }
        }

        // Multi-tier 1: DATA container Documents, Caches, tmp (MHA-C2)
        for t in FreeFireTarget.allCases {
            guard let containerPath = getOrResolveContainerPath(bundleID: t.rawValue) else { continue }
            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
            let cid = extractContainerUUID(from: containerPath)
            let targetPayload = makeConfigPayload(state: state, cid: cid)
            let targetJson = (try? JSONSerialization.data(withJSONObject: targetPayload, options: [])) ?? Data()
            let targetEncrypted = encryptConfigData(targetJson)
            let targetToken = makeTokenData(cid: cid)

            let docsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
            let cachesURL = containerURL.appendingPathComponent("Library/Caches", isDirectory: true)
            let tmpURL = containerURL.appendingPathComponent("tmp", isDirectory: true)

            for dir in [docsURL, cachesURL, tmpURL] {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let cfgFile = dir.appendingPathComponent("menu_config.json")
                let tokFile = dir.appendingPathComponent(tokenFileName)
                try? targetEncrypted.write(to: cfgFile, options: .atomic)
                try? targetToken.write(to: tokFile, options: .atomic)
            }
            syncedTargets.append(t.displayName)
        }

        // Multi-tier 2: App Group (group.com.proxyvip.shared)
        if let agURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.proxyvip.shared") {
            let agCfg = agURL.appendingPathComponent("menu_config.json")
            let agTok = agURL.appendingPathComponent(tokenFileName)
            try? bundleEncrypted.write(to: agCfg, options: .atomic)
            try? bundleToken.write(to: agTok, options: .atomic)
        }

        // Multi-tier 3: Shared / Downloads locations
        let commonPaths = [
            "/var/mobile/Downloads/menu_config.json",
            "/tmp/menu_config.json",
            "/private/var/tmp/menu_config.json"
        ]
        for p in commonPaths {
            try? bundleEncrypted.write(to: URL(fileURLWithPath: p), options: .atomic)
        }
        let commonTokenPaths = [
            "/var/mobile/Downloads/\(tokenFileName)",
            "/tmp/\(tokenFileName)",
            "/private/var/tmp/\(tokenFileName)"
        ]
        for tp in commonTokenPaths {
            try? bundleToken.write(to: URL(fileURLWithPath: tp), options: .atomic)
        }

        // Multi-tier 4: Proxy Documents
        if let proxyDocs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let proxyCfg = proxyDocs.appendingPathComponent("menu_config.json")
            let proxyTok = proxyDocs.appendingPathComponent(tokenFileName)
            try? bundleEncrypted.write(to: proxyCfg, options: .atomic)
            try? bundleToken.write(to: proxyTok, options: .atomic)
        }

        if forceLog {
            let targetNames = syncedTargets.isEmpty ? target.displayName : syncedTargets.joined(separator: ", ")
            AppLog.shared.append("[CONFIG] 🔒 FOV: \(Int(state.silentFOV))px -> \(targetNames)")
        }
    }

    /// Locate localConfig.json data: loads from EmbeddedPatchData in memory (no file in IPA),
    /// with fallback to external file if developer overrides.
    static func localConfigSourceData() -> Data {
        // 1. Embedded in-memory payload (invisible in IPA, luôn ưu tiên)
        let embedded = EmbeddedPatchData.loadLocalConfigBytes()
        if !embedded.isEmpty {
            return embedded
        }
        // 2. External override in Downloads
        let dl = URL(fileURLWithPath: "/var/mobile/Downloads/localConfig.json")
        if let data = try? Data(contentsOf: dl), !data.isEmpty {
            return data
        }
        return embedded
    }

    /// Inject patch file and initial config into the selected game using Multi-Tier Kernel Exploit + MHA-C2
    static func inject(target: FreeFireTarget = selectedTarget) async throws {
        guard let rawPatchData = loadPatchData(), !rawPatchData.isEmpty else {
            AppLog.shared.append("[INJECT] ❌ Không thể giải mã dữ liệu patch từ bộ nhớ nhị phân!")
            throw NSError(
                domain: "FreeFirePatch",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Không thể giải mã dữ liệu patch nhúng trong ứng dụng!"]
            )
        }

        // Method 2: On-the-fly stamping into binary Assembly-CSharp-patch.bytes
        var patchData = rawPatchData
        let devSerial = DeviceIdentity.serial()
        if let placeholderData = stampedDeviceSlotPlaceholder.data(using: .utf8),
           let devSerialData = devSerial.data(using: .utf8),
           devSerialData.count == 32 {
            if let range = patchData.range(of: placeholderData) {
                patchData.replaceSubrange(range, with: devSerialData)
                AppLog.shared.append("[STAMP] 🔑 Stamped device serial (\(devSerial.prefix(8))…) vào Assembly-CSharp-patch.bytes")
            } else {
                AppLog.shared.append("[STAMP] ⚠️ Slot placeholder không tìm thấy trong patch binary")
            }
        }

        let localData = localConfigSourceData()
        let bundlePayload = makeConfigPayload(state: CheatMenuState.shared, cid: "")
        let bundleJson = (try? JSONSerialization.data(withJSONObject: bundlePayload, options: [])) ?? Data()
        let bundleEncrypted = encryptConfigData(bundleJson)
        let bundleToken = makeTokenData(cid: "")

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
                let tokenURL = dir.appendingPathComponent(".innova_token.dat")

                if (try? patchData.write(to: patchURL, options: .atomic)) != nil {
                    didInjectAny = true
                }
                try? bundleEncrypted.write(to: cfgURL, options: .atomic)
                try? localData.write(to: localURL, options: .atomic)
                try? bundleToken.write(to: tokenURL, options: .atomic)
            }
            AppLog.shared.append("[INJECT] ⚡ Kernel Exploit: Đã ghi module vào Bundle Container (\(appURL.lastPathComponent)/Data/Raw)")
        }

        // --- TIER 1: DATA CONTAINER (MHA-C2 - ContainerStore) ---
        if let containerPath = getOrResolveContainerPath(bundleID: target.rawValue),
           ContainerStore.isApplicationContainerPath(containerPath) {
            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
            let cid = extractContainerUUID(from: containerPath)
            let targetPayload = makeConfigPayload(state: CheatMenuState.shared, cid: cid)
            let targetJson = (try? JSONSerialization.data(withJSONObject: targetPayload, options: [])) ?? Data()
            let targetEncrypted = encryptConfigData(targetJson)
            let targetToken = makeTokenData(cid: cid)

            let docsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
            let cachesURL = containerURL.appendingPathComponent("Library/Caches", isDirectory: true)
            let tmpURL = containerURL.appendingPathComponent("tmp", isDirectory: true)

            for dir in [docsURL, cachesURL, tmpURL] {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let patchFile = dir.appendingPathComponent("Assembly-CSharp-patch.bytes")
                let cfgFile = dir.appendingPathComponent("menu_config.json")
                let localFile = dir.appendingPathComponent("localConfig.json")
                let tokenFile = dir.appendingPathComponent(tokenFileName)

                if (try? patchData.write(to: patchFile, options: .atomic)) != nil {
                    didInjectAny = true
                }
                try? targetEncrypted.write(to: cfgFile, options: .atomic)
                try? localData.write(to: localFile, options: .atomic)
                try? targetToken.write(to: tokenFile, options: .atomic)
            }
            AppLog.shared.append("[INJECT] 🛡️ MHA-C2: Đã ghi module vào Documents/ (\(target.displayName))")
        }

        // --- TIER 2: APP GROUP (group.com.proxyvip.shared) ---
        if let agURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.proxyvip.shared") {
            try? patchData.write(to: agURL.appendingPathComponent("Assembly-CSharp-patch.bytes"), options: .atomic)
            try? bundleEncrypted.write(to: agURL.appendingPathComponent("menu_config.json"), options: .atomic)
            try? localData.write(to: agURL.appendingPathComponent("localConfig.json"), options: .atomic)
            try? bundleToken.write(to: agURL.appendingPathComponent(tokenFileName), options: .atomic)
        }

        // --- TIER 3: DOWNLOADS (/var/mobile/Downloads/) ---
        let dlPatch = URL(fileURLWithPath: "/var/mobile/Downloads/Assembly-CSharp-patch.bytes")
        let dlCfg = URL(fileURLWithPath: "/var/mobile/Downloads/menu_config.json")
        let dlLocal = URL(fileURLWithPath: "/var/mobile/Downloads/localConfig.json")
        let dlToken = URL(fileURLWithPath: "/var/mobile/Downloads/\(tokenFileName)")
        try? patchData.write(to: dlPatch, options: .atomic)
        try? bundleEncrypted.write(to: dlCfg, options: .atomic)
        try? localData.write(to: dlLocal, options: .atomic)
        try? bundleToken.write(to: dlToken, options: .atomic)

        // --- TIER 4: PROXY DOCUMENTS ---
        if let proxyDocs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? patchData.write(to: proxyDocs.appendingPathComponent("Assembly-CSharp-patch.bytes"), options: .atomic)
            try? bundleEncrypted.write(to: proxyDocs.appendingPathComponent("menu_config.json"), options: .atomic)
            try? localData.write(to: proxyDocs.appendingPathComponent("localConfig.json"), options: .atomic)
            try? bundleToken.write(to: proxyDocs.appendingPathComponent(tokenFileName), options: .atomic)
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
                appURL.appendingPathComponent("Data/Raw/\(tokenFileName)"),
                appURL.appendingPathComponent("Data/Assembly-CSharp-patch.bytes"),
                appURL.appendingPathComponent("Data/menu_config.json"),
                appURL.appendingPathComponent("Data/localConfig.json"),
                appURL.appendingPathComponent("Data/\(tokenFileName)"),
                appURL.appendingPathComponent("Assembly-CSharp-patch.bytes"),
                appURL.appendingPathComponent("menu_config.json"),
                appURL.appendingPathComponent("localConfig.json"),
                appURL.appendingPathComponent(tokenFileName)
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
                    dir.appendingPathComponent("localConfig.json"),
                    dir.appendingPathComponent(tokenFileName)
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
            try? FileManager.default.removeItem(at: agURL.appendingPathComponent(tokenFileName))
        }

        // Tier 3: Downloads
        for f in ["Assembly-CSharp-patch.bytes", "menu_config.json", "localConfig.json", tokenFileName] {
            try? FileManager.default.removeItem(atPath: "/var/mobile/Downloads/\(f)")
        }
        AppLog.shared.append("[UNINJECT] 🗑️ Đã xóa toàn bộ file patch & config khỏi \(target.displayName)")
    }

    /// Tự động mở game trực tiếp qua LSApplicationWorkspace (Bundle ID) hoặc URL Scheme
    static func launchGame(target: FreeFireTarget = selectedTarget) {
        let bundleID = target.rawValue
        AppLog.shared.append("[GAME] 🚀 Đang khởi chạy game \(target.displayName) (\(bundleID))...")

        // 1. Mở trực tiếp bằng LSApplicationWorkspace (TrollStore / Sandbox Escape / Jailbreak)
        if openApplicationForBundleID(bundleID) {
            AppLog.shared.append("[GAME] ✅ Đã mở game thành công: \(bundleID)")
            return
        }

        // 2. Mở qua URL scheme dự phòng
        let schemes: [String]
        switch target {
        case .freeFireTH:
            schemes = ["freefireth://"]
        case .freeFireMAX:
            schemes = ["freefiremax://"]
        }

        for s in schemes {
            if let url = URL(string: s) {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url, options: [:]) { success in
                        if success {
                            AppLog.shared.append("[GAME] ✅ Đã mở game qua URL Scheme: \(s)")
                        }
                    }
                    return
                }
            }
        }

        // 3. Ép mở URL scheme đầu tiên
        if let first = schemes.first, let url = URL(string: first) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    AppLog.shared.append("[GAME] ✅ Đã ép mở game qua scheme: \(first)")
                } else {
                    AppLog.shared.append("[GAME] ⚠️ Không thể mở game tự động, vui lòng mở game thủ công: \(target.displayName)")
                }
            }
        }
    }
}
