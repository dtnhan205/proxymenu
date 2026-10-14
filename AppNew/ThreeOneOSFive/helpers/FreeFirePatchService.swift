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

    /// Container path resolver using Airlift FFI, MHA-C2, and LocalDevVPN
    static func getOrResolveContainerPath(bundleID: String) -> String? {
        if let cached = cachedContainerPaths[bundleID], !cached.isEmpty {
            if FileManager.default.fileExists(atPath: cached) || cached.contains("/Containers/Data/Application/") {
                return cached
            }
            cachedContainerPaths.removeValue(forKey: bundleID)
        }

        // ƯU TIÊN 1: Nếu đã có Pairing File từ Developer Mode (Airlift / RPPairing), truy vấn qua RSD Installation Proxy
        if RemotePairingAdvertiser.shared.hasExistingPairing {
            let pairingPath = RemotePairingAdvertiser.shared.pairingFilePath
            if let airliftPath = AirliftBridge.findAppContainerSync(bundleID: bundleID, pairingPath: pairingPath),
               !airliftPath.isEmpty {
                cachedContainerPaths[bundleID] = airliftPath
                return airliftPath
            }
        }

        // ƯU TIÊN 2: ContainerStore (MHA-C2 / Kernel Exploit)
        if let resolved = ContainerStore.resolveAppContainerPath(bundleID: bundleID),
           ContainerStore.isApplicationContainerPath(resolved) {
            cachedContainerPaths[bundleID] = resolved
            return resolved
        }

        // ƯU TIÊN 3: Cầu nối LocalDevVPN
        if LocalDevVPNBridge.isBridgeSupportedOS {
            if let vpnResolved = LocalDevVPNBridge.resolveContainerPath(bundleID: bundleID) {
                cachedContainerPaths[bundleID] = vpnResolved
                return vpnResolved
            }
        }
        return nil
    }

    /// Check if Assembly-CSharp-patch.bytes is injected in the specified game container (Data or Bundle)
    static func isInjected(target: FreeFireTarget = selectedTarget) -> Bool {
        if UserDefaults.standard.bool(forKey: "innova.isInjected.\(target.rawValue)") {
            return true
        }
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
        // Fallback kiểm tra qua LocalDevVPN
        if LocalDevVPNBridge.isBridgeSupportedOS {
            if LocalDevVPNBridge.isInjected(target: target) {
                return true
            }
        }
        return false
    }

    // Khóa bí mật 32-byte dùng để giải mã stream bytes từ server (phải khớp với INNOVA_PAYLOAD_CIPHER_SECRET trên server)
    private static let innovaPayloadCipherSecret: [UInt8] = [
        0x7E, 0x4B, 0x91, 0x2A, 0xC5, 0x88, 0x1F, 0xD3,
        0x64, 0xFA, 0x0E, 0xB7, 0x39, 0x52, 0x8D, 0xCE,
        0x9A, 0x15, 0x6C, 0xF4, 0x2B, 0xE0, 0x73, 0x89,
        0xD1, 0x3F, 0x56, 0xAA, 0x08, 0x7B, 0xC4, 0x92
    ]

    /// Bộ nhớ RAM đệm chứa dữ liệu patch và config nhận từ server
    private static var inMemoryServerPatchData: Data?
    private static var inMemoryServerConfigData: Data?
    private static var inMemoryServerTokenData: [String: Data] = [:]

    /// Xóa sạch toàn bộ dữ liệu nhạy cảm trong RAM ngay lập tức khi phát hiện can thiệp
    static func wipeSensitiveMemory() {
        inMemoryServerPatchData = nil
        inMemoryServerConfigData = nil
        inMemoryServerTokenData.removeAll()
        purgeLegacyLocalCache()
    }

    /// Giải mã payload nhị phân nhận từ server trong RAM
    static func decryptServerPayload(base64String: String, deviceSerial: String) -> Data? {
        guard let encryptedData = Data(base64Encoded: base64String) else { return nil }
        var bytes = [UInt8](encryptedData)
        let devBytes = [UInt8](deviceSerial.utf8)
        var derivedKey = [UInt8](repeating: 0, count: 32)
        for i in 0..<32 {
            let devByte: UInt8 = (i < devBytes.count) ? devBytes[i] : 0x55
            derivedKey[i] = innovaPayloadCipherSecret[i] ^ devByte
        }
        for i in 0..<bytes.count {
            bytes[i] ^= derivedKey[i % 32]
        }
        return Data(bytes)
    }

    /// Tải và giải mã payload Assembly-CSharp-patch.bytes và localConfig.json từ server (On-Demand)
    @discardableResult
    static func downloadAndPreparePayload(targetContainerId: String? = nil, forceRefresh: Bool = false) async throws -> Data {
        if !forceRefresh, let existing = inMemoryServerPatchData, !existing.isEmpty {
            return existing
        }

        guard let savedKey = LicenseStore.shared.savedKey, !savedKey.isEmpty else {
            AppLog.shared.append("[PAYLOAD] ❌ Chưa có key bản quyền để tải payload!")
            throw NSError(
                domain: "FreeFirePatch",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Chưa kích hoạt License Key để tải dữ liệu game!"]
            )
        }

        let devSerial = DeviceIdentity.serial()
        AppLog.shared.append("[PAYLOAD] ⬇️ Đang tải Assembly-CSharp-patch.bytes…")

        let resp = try await PatchHubService.fetchInnovaPayload(key: savedKey, deviceSerial: devSerial, containerId: targetContainerId)
        guard let b64 = resp.payloadBase64, !b64.isEmpty else {
            AppLog.shared.append("[PAYLOAD] ❌ Máy chủ không trả về dữ liệu payload!")
            throw NSError(
                domain: "FreeFirePatch",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Không thể lấy dữ liệu patch từ máy chủ!"]
            )
        }

        guard let decrypted = decryptServerPayload(base64String: b64, deviceSerial: devSerial), !decrypted.isEmpty else {
            AppLog.shared.append("[PAYLOAD] ❌ Lỗi giải mã payload!")
            throw NSError(
                domain: "FreeFirePatch",
                code: 502,
                userInfo: [NSLocalizedDescriptionKey: "Giải mã dữ liệu patch từ máy chủ thất bại!"]
            )
        }

        inMemoryServerPatchData = decrypted
        if let cfgRaw = resp.configRaw, let cfgData = cfgRaw.data(using: .utf8) {
            inMemoryServerConfigData = cfgData
        }

        if let cid = targetContainerId, let tokB64 = resp.tokenBase64, let tokData = tokB64.data(using: .utf8) {
            inMemoryServerTokenData[cid] = tokData
            AppLog.shared.append("[TOKEN] 🛡️ Đã nhận token ký trực tiếp")
        }

        // Xóa mọi file cache cũ trên đĩa nếu có
        purgeLegacyLocalCache()

        AppLog.shared.append("[PAYLOAD] ✅ Đã tải & giải mã thành công!")
        return decrypted
    }

    /// Lấy token .innova_token.dat: BẮT BUỘC 100% DO SERVER TRẢ VỀ (PatchHubService.fetchInnovaToken)
    /// Tuyệt đối KHÔNG tự ký hay sinh token nội bộ.
    /// Nếu không có key, hoặc mất mạng, hoặc server từ chối:
    /// -> KHÔNG CÓ TOKEN NÀO ĐƯỢC SINH RA. Xóa sạch token cache trong RAM và ném lỗi.
    static func obtainTokenData(cid: String) async throws -> Data {
        if let cached = inMemoryServerTokenData[cid], !cached.isEmpty {
            return cached
        }
        guard let savedKey = LicenseStore.shared.savedKey, !savedKey.isEmpty else {
            inMemoryServerTokenData.removeValue(forKey: cid)
            AppLog.shared.append("[TOKEN] ❌ Chưa có key bản quyền! Không thể cấp token.")
            throw NSError(
                domain: "FreeFirePatch",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Chưa kích hoạt License Key để cấp token game!"]
            )
        }
        guard let expDate = LicenseStore.shared.expiresAt, expDate > Date() else {
            inMemoryServerTokenData.removeValue(forKey: cid)
            AppLog.shared.append("[TOKEN] ❌ Key bản quyền đã hết hạn! Không thể cấp token.")
            throw NSError(
                domain: "FreeFirePatch",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Key bản quyền đã hết hạn! Vui lòng gia hạn key."]
            )
        }

        let devSerial = DeviceIdentity.serial()
        do {
            let tokenBase64 = try await PatchHubService.fetchInnovaToken(key: savedKey, deviceSerial: devSerial, containerId: cid)
            guard let tokenData = tokenBase64.data(using: .utf8), !tokenData.isEmpty else {
                inMemoryServerTokenData.removeValue(forKey: cid)
                AppLog.shared.append("[TOKEN] ❌ Dữ liệu token từ Server rỗng hoặc không hợp lệ!")
                throw NSError(
                    domain: "FreeFirePatch",
                    code: 502,
                    userInfo: [NSLocalizedDescriptionKey: "Máy chủ trả về token không hợp lệ!"]
                )
            }
            inMemoryServerTokenData[cid] = tokenData
            AppLog.shared.append("[TOKEN] 🛡️ Server đã ký & cấp token")
            return tokenData
        } catch {
            inMemoryServerTokenData.removeValue(forKey: cid)
            AppLog.shared.append("[TOKEN] ❌ Lỗi lấy token")
            throw error
        }
    }

    /// Xóa sạch mọi file cache đệm cũ còn sót lại trong Application Support
    static func purgeLegacyLocalCache() {
        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let patchURL = appSupport.appendingPathComponent(".innova_patch.cache")
        let configURL = appSupport.appendingPathComponent(".innova_config.cache")
        try? FileManager.default.removeItem(at: patchURL)
        try? FileManager.default.removeItem(at: configURL)
    }

    /// Load patch data: CHỈ lấy dữ liệu đã tải từ Server trong RAM (Zero disk storage)
    static func loadPatchData() -> Data? {
        if let serverData = inMemoryServerPatchData, !serverData.isEmpty {
            return serverData
        }
        return nil
    }

    // Slot placeholder for on-the-fly binary stamping (Method 2)
    private static let stampedDeviceSlotPlaceholder = "INNOVA_DEV_SLOT_0000000000000000"

    // Disguised config & token file names matching real game asset bundle caches (~3D)
    static let configFileName: String = "optionalab_666.nL~2Bwky7XlQH6YAn8NejPUuelS7g~3D"
    static let tokenFileName: String = "optionalab_avatar_66.aR1cpCxniZkakOa0D5JS~2FD0CYNc~3D"

    /// Resolve remaining expiration epoch seconds from LicenseStore (Zero Trust)
    static func resolveLicenseExpirationTimestamp() -> Int {
        guard let savedKey = LicenseStore.shared.savedKey, !savedKey.isEmpty else {
            return 0
        }
        guard let expDate = LicenseStore.shared.expiresAt else {
            return 0
        }
        let now = Date()
        guard expDate > now else {
            return 0
        }
        return Int(expDate.timeIntervalSince1970)
    }

    /// Extract container UUID from path strictly (Zero permissive fallbacks)
    static func extractContainerUUID(from path: String) -> String {
        let clean = (path as NSString).standardizingPath.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        let last = (clean as NSString).lastPathComponent
        if UUID(uuidString: last) != nil {
            return last
        }
        let components = clean.components(separatedBy: "/")
        if let appIdx = components.firstIndex(of: "Application"), appIdx + 1 < components.count {
            let candidate = components[appIdx + 1]
            if UUID(uuidString: candidate) != nil {
                return candidate
            }
        }
        return ""
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
            "aim_target": state.aimBotTarget.intValue,
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
            "back_jump": state.backJump ? 1 : 0,
            "high_jump": state.highJump ? 1 : 0,
            "fast_rotation": state.fastRotation ? 1 : 0,
            "chams_outline": state.chamsOutline ? 1 : 0,
            "fast_swap": state.fastSwap ? 1 : 0,
            "no_grass": state.noGrass ? 1 : 0,
            "no_fog": state.noFog ? 1 : 0,
            "fast_loot": state.fastLoot ? 1 : 0,
            "fast_crouch": state.fastCrouch ? 1 : 0,
            "super_emote": state.superEmote ? 1 : 0,
            "fast_reload": state.fastReload ? 1 : 0,
            "unlock_fps": state.unlockFps ? 1 : 0,
            "spin_bot": state.spinBot ? 1 : 0,
            "spin_speed": Int(state.spinSpeed),
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

    /// Sync the current configuration to all game containers and multi-channel IPC
    static func syncConfig(target: FreeFireTarget = selectedTarget, state: CheatMenuState = CheatMenuState.shared, forceLog: Bool = false) {
        // Zero Trust: Bắt buộc phải có Key hợp lệ và còn hạn sử dụng
        guard let savedKey = LicenseStore.shared.savedKey, !savedKey.isEmpty,
              let expDate = LicenseStore.shared.expiresAt, expDate > Date() else {
            NSLog("[FreeFirePatch] ❌ Phát hiện không có license hoặc key hết hạn khi syncConfig -> Lập tức thu hồi và xóa sạch cấu hình khỏi game!")
            uninject(target: target)
            return
        }

        var syncedTargets: [String] = []

        // Multi-tier 0: BUNDLE container (Kernel Exploit - Highest Priority)
        let bundlePayload = makeConfigPayload(state: state)
        let bundleJson = (try? JSONSerialization.data(withJSONObject: bundlePayload, options: [])) ?? Data()
        let bundleEncrypted = encryptConfigData(bundleJson)

        for t in FreeFireTarget.allCases {
            if let appURL = findBundleAppURL(target: t) {
                let dataRaw = appURL.appendingPathComponent("Data/Raw/\(configFileName)")
                let dataDir = appURL.appendingPathComponent("Data/\(configFileName)")
                let appRoot = appURL.appendingPathComponent(configFileName)

                for u in [dataRaw, dataDir, appRoot] {
                    let folder = u.deletingLastPathComponent()
                    if !FileManager.default.fileExists(atPath: folder.path) {
                        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                    }
                    try? bundleEncrypted.write(to: u, options: .atomic)
                }
            }
        }

        // Multi-tier 1: DATA container Documents, Caches, tmp (MHA-C2)
        for t in FreeFireTarget.allCases {
            guard let containerPath = getOrResolveContainerPath(bundleID: t.rawValue) else { continue }
            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
            let cid = extractContainerUUID(from: containerPath)
            guard !cid.isEmpty, UUID(uuidString: cid) != nil else {
                continue
            }
            let targetPayload = makeConfigPayload(state: state)
            let targetJson = (try? JSONSerialization.data(withJSONObject: targetPayload, options: [])) ?? Data()
            let targetEncrypted = encryptConfigData(targetJson)
            
            // ZERO TRUST: Chỉ ghi token nếu ĐÃ ĐƯỢC SERVER CẤP trong RAM. Tuyệt đối KHÔNG tự sinh token!
            // Nếu không có token hợp lệ trong RAM -> Xóa sạch file token trên đĩa!
            let serverToken = inMemoryServerTokenData[cid]

            let docsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
            let cachesURL = containerURL.appendingPathComponent("Library/Caches", isDirectory: true)
            let tmpURL = containerURL.appendingPathComponent("tmp", isDirectory: true)

            // Deep stealth storage inside Documents (game asset cache camouflage)
            let deepCfgDir = docsURL.appendingPathComponent("contentcache/Optional/ios/gameassetbundles", isDirectory: true)
            let deepTokDir = docsURL.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles", isDirectory: true)
            try? FileManager.default.createDirectory(at: deepCfgDir, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: deepTokDir, withIntermediateDirectories: true)

            let deepCfgFile = deepCfgDir.appendingPathComponent(configFileName)
            let deepTokFile = deepTokDir.appendingPathComponent(tokenFileName)
            try? targetEncrypted.write(to: deepCfgFile, options: .atomic)

            if let serverToken, !serverToken.isEmpty {
                try? serverToken.write(to: deepTokFile, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: deepTokFile)
                try? FileManager.default.removeItem(at: deepTokDir.appendingPathComponent(".innova_token.dat"))
            }

            // Xoá sạch file ở gốc Documents để không bị lộ trong ứng dụng Tệp (Files)
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(configFileName))
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent("menu_config.json"))
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(tokenFileName))
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(".innova_token.dat"))

            // Tuyệt đối KHÔNG inject / ghi file cấu hình vào Library/Caches hay tmp
            // Dọn dẹp sạch mọi file cấu hình / token trong Caches và tmp nếu từng tồn tại:
            for cleanDir in [cachesURL, tmpURL] {
                try? FileManager.default.removeItem(at: cleanDir.appendingPathComponent(configFileName))
                try? FileManager.default.removeItem(at: cleanDir.appendingPathComponent("menu_config.json"))
                try? FileManager.default.removeItem(at: cleanDir.appendingPathComponent(tokenFileName))
                try? FileManager.default.removeItem(at: cleanDir.appendingPathComponent(".innova_token.dat"))
            }
            syncedTargets.append(t.displayName)
        }

        // Multi-tier 2: App Group (group.com.proxyvip.shared)
        if let agURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.proxyvip.shared") {
            let agCfg = agURL.appendingPathComponent(configFileName)
            try? bundleEncrypted.write(to: agCfg, options: .atomic)
        }

        // Multi-tier 3: Shared / Downloads locations
        let commonPaths = [
            "/var/mobile/Downloads/\(configFileName)",
            "/tmp/\(configFileName)",
            "/private/var/tmp/\(configFileName)"
        ]
        for p in commonPaths {
            try? bundleEncrypted.write(to: URL(fileURLWithPath: p), options: .atomic)
        }

        // Multi-tier 4: Proxy Application Support (Private, không lộ ra Tệp)
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            let proxyCfg = appSupport.appendingPathComponent(configFileName)
            try? bundleEncrypted.write(to: proxyCfg, options: .atomic)
        }

        // Multi-tier 5: iOS 18.7.x / 27 LocalDevVPN (chỉ chạy duy nhất khi trên iOS 18.7.x / 27)
        if LocalDevVPNBridge.isBridgeSupportedOS {
            _ = LocalDevVPNBridge.syncConfig(target: target, configData: bundleEncrypted)
        }

        if forceLog {
            let targetNames = syncedTargets.isEmpty ? target.displayName : syncedTargets.joined(separator: ", ")
            AppLog.shared.append("[CONFIG] 🔒 FOV: \(Int(state.silentFOV))px -> \(targetNames)")
        }
    }

    /// Locate localConfig.json data: CHỈ lấy từ Server trong RAM
    static func localConfigSourceData() -> Data {
        if let serverCfg = inMemoryServerConfigData, !serverCfg.isEmpty {
            return serverCfg
        }
        return "{\"testCodePatch\":true,\"resetGuest\":true}".data(using: .utf8) ?? Data()
    }

    /// Inject patch file and initial config into the selected game using Multi-Tier Kernel Exploit, Airlift FFI, and LocalDevVPN
    static func inject(target: FreeFireTarget = selectedTarget) async throws {
        AppLog.shared.append("[INJECT] ════════════════════════════════════════")
        AppLog.shared.append("[INJECT] 🚀 BẮT ĐẦU NẠP CHEAT VÀO \(target.displayName.uppercased())")
        AppLog.shared.append("[INJECT] ════════════════════════════════════════")
        RemotePairingAdvertiser.shared.log("🚀 [INJECT] Bắt đầu nạp module cheat vào \(target.displayName)")

        // 1. Kiểm tra thiết bị và phiên bản
        let devSerial = DeviceIdentity.serial()
        let osVersion = "\(AppInfo.osVersion) (\(AppInfo.osBuild))"
        AppLog.shared.append("[INJECT] 📱 Thiết bị: \(AppInfo.displayMachineName) · iOS \(osVersion) · HWID: \(devSerial.prefix(8))…")

        // 2. Kiểm tra chống tiêm dylib / can thiệp nhị phân trước khi giải mã nạp game
        DylibInjectionGuard.enforceAllProtections()
        IntegrityChecker.verifyBinaryTextSegment()
        AppLog.shared.append("[INJECT] 🛡️ Bảo vệ nhị phân: AN TOÀN")

        // 3. Zero Trust: Bắt buộc phải có License Key hợp lệ và còn hạn sử dụng
        guard let savedKey = LicenseStore.shared.savedKey, !savedKey.isEmpty,
              let expDate = LicenseStore.shared.expiresAt, expDate > Date() else {
            uninject(target: target)
            AppLog.shared.append("[INJECT] ❌ License key không tồn tại hoặc đã hết hạn! Đã thu hồi toàn bộ module can thiệp.")
            RemotePairingAdvertiser.shared.log("❌ [INJECT] License Key không hợp lệ hoặc đã hết hạn!")
            throw NSError(
                domain: "FreeFirePatch",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Chưa kích hoạt License Key hoặc key đã hết hạn! Vui lòng nhập key hợp lệ."]
            )
        }
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm"
        AppLog.shared.append("[INJECT] 🔑 License Key: \(savedKey.prefix(6))… · Hạn: \(df.string(from: expDate))")

        // 4. Kiểm tra file pairing và kết nối mạng
        let hasPairing = RemotePairingAdvertiser.shared.hasExistingPairing
        let pairingPath = RemotePairingAdvertiser.shared.pairingFilePath
        let pairingSize = (try? FileManager.default.attributesOfItem(atPath: pairingPath)[.size] as? Int) ?? 0
        let vpn = LocalDevVPNBridge.detectVPNInterface()
        let wifiIP = RemotePairingAdvertiser.getWiFiAddress() ?? "Không có"
        let booksInstalled = UIApplication.shared.canOpenURL(URL(string: "ibooks://")!)

        AppLog.shared.append("[INJECT] 📁 Pairing Record: \(hasPairing ? "✅ CÓ SẴN (\(pairingSize) bytes)" : "⚠️ Chưa có file pairing")")
        AppLog.shared.append("[INJECT] 📚 Apple Books: \(booksInstalled ? "✅ Đã cài đặt" : "⚠️ CHƯA CÀI ĐẶT (AirTraffic yêu cầu có app Sách)")")
        AppLog.shared.append("[INJECT] 🌐 LocalDevVPN: \(vpn.active ? "✅ ĐANG BẬT (\(vpn.deviceIP))" : "ℹ️ Chưa bật (Khuyên bật)")")
        AppLog.shared.append("[INJECT] 📶 Wi-Fi IP: \(wifiIP)")
        RemotePairingAdvertiser.shared.log("📁 [INJECT] Pairing: \(hasPairing ? "OK (\(pairingSize)B)" : "Chưa có") · Books: \(booksInstalled ? "OK" : "Thiếu") · VPN: \(vpn.active ? "BẬT" : "TẮT")")

        if hasPairing && !vpn.active {
            AppLog.shared.append("[INJECT] 💡 MẸO: Nếu RSD tunnel bị lỗi kết nối, hãy mở app LocalDevVPN và bấm Connect để mở cổng 49152!")
            RemotePairingAdvertiser.shared.log("💡 [MẸO] Mở LocalDevVPN để thông cổng RSD 10.7.0.1:49152")
        }

        // 5. Tìm container UUID để cấp token chính xác từ server
        AppLog.shared.append("[INJECT] 🔍 Đang dò tìm container của \(target.displayName) (\(target.rawValue))…")
        RemotePairingAdvertiser.shared.log("🔍 [INJECT] Dò tìm container của \(target.displayName)...")
        var resolvedContainerPath: String? = nil

        // Thử tìm qua cache hoặc system database trước
        if let cached = cachedContainerPaths[target.rawValue], !cached.isEmpty {
            resolvedContainerPath = cached
            AppLog.shared.append("[INJECT] ⚡ Container tìm thấy từ cache: \(cached)")
        }

        // Nếu chưa có, thử dò qua RSD InstallationProxy
        if (resolvedContainerPath == nil || resolvedContainerPath?.isEmpty == true) && hasPairing {
            AppLog.shared.append("[INJECT] 📡 Dò tìm container qua Developer Mode RSD tunnel…")
            RemotePairingAdvertiser.shared.log("📡 [INJECT] Quét container qua RSD tunnel...")
            do {
                let rsdPath = try await AirliftBridge.findAppContainer(bundleID: target.rawValue, pairingPath: pairingPath)
                if !rsdPath.isEmpty {
                    resolvedContainerPath = rsdPath
                    cachedContainerPaths[target.rawValue] = rsdPath
                    AppLog.shared.append("[INJECT] ✅ Container tìm thấy qua RSD: \(rsdPath)")
                    RemotePairingAdvertiser.shared.log("✅ [INJECT] Tìm thấy container: \(rsdPath)")
                }
            } catch {
                AppLog.shared.append("[INJECT] ⚠️ RSD dò tìm container thất bại: \(error.localizedDescription)")
                RemotePairingAdvertiser.shared.log("⚠️ [INJECT] RSD lookup: \(error.localizedDescription)")
            }
        }

        // Fallback: Thử qua Local ContainerStore & LocalDevVPNBridge
        if resolvedContainerPath == nil || resolvedContainerPath?.isEmpty == true {
            AppLog.shared.append("[INJECT] 🔎 Thử dò qua Local ContainerStore & System Metadata…")
            if let storePath = ContainerStore.resolveAppContainerPath(bundleID: target.rawValue), !storePath.isEmpty {
                resolvedContainerPath = storePath
                cachedContainerPaths[target.rawValue] = storePath
                AppLog.shared.append("[INJECT] ✅ Container tìm thấy qua ContainerStore: \(storePath)")
            } else if let vpnPath = LocalDevVPNBridge.resolveContainerPath(bundleID: target.rawValue), !vpnPath.isEmpty {
                resolvedContainerPath = vpnPath
                cachedContainerPaths[target.rawValue] = vpnPath
                AppLog.shared.append("[INJECT] ✅ Container tìm thấy qua VPN Bridge: \(vpnPath)")
            }
        }

        // Fallback: Thử kiểm tra target thay thế (MAX <-> TH)
        if resolvedContainerPath == nil || resolvedContainerPath?.isEmpty == true {
            let altTarget = (target == .freeFireTH) ? FreeFireTarget.freeFireMAX : FreeFireTarget.freeFireTH
            AppLog.shared.append("[INJECT] ℹ️ Thử kiểm tra phiên bản game thay thế: \(altTarget.displayName)…")
            if hasPairing {
                if let altPath = try? await AirliftBridge.findAppContainer(bundleID: altTarget.rawValue, pairingPath: pairingPath), !altPath.isEmpty {
                    resolvedContainerPath = altPath
                    cachedContainerPaths[target.rawValue] = altPath
                    AppLog.shared.append("[INJECT] 🎮 Phát hiện game đang cài là \(altTarget.displayName): \(altPath)")
                    RemotePairingAdvertiser.shared.log("🎮 [INJECT] Tìm thấy \(altTarget.displayName)")
                }
            }
            if resolvedContainerPath == nil {
                if let altStore = ContainerStore.resolveAppContainerPath(bundleID: altTarget.rawValue), !altStore.isEmpty {
                    resolvedContainerPath = altStore
                    cachedContainerPaths[target.rawValue] = altStore
                    AppLog.shared.append("[INJECT] 🎮 Phát hiện container \(altTarget.displayName) qua System: \(altStore)")
                }
            }
        }

        if let container = resolvedContainerPath, !container.isEmpty {
            AppLog.shared.append("[INJECT] 📂 Container sử dụng: \(container)")
            RemotePairingAdvertiser.shared.log("📂 [INJECT] Container: \(container)")
        } else {
            AppLog.shared.append("[INJECT] ⚠️ Chưa thể xác định container của \(target.displayName). Hãy chắc chắn bạn đã mở game ít nhất 1 lần!")
            RemotePairingAdvertiser.shared.log("⚠️ [INJECT] Chưa thấy container game! Hãy mở game 1 lần")
        }
        let resolvedCid = (resolvedContainerPath != nil) ? extractContainerUUID(from: resolvedContainerPath!) : ""

        // 6. Bắt buộc tải payload từ Server nếu chưa có trong RAM
        if inMemoryServerPatchData == nil || inMemoryServerPatchData?.isEmpty == true {
            AppLog.shared.append("[INJECT] ⬇️ Đang tải dữ liệu patch từ Server...")
            _ = try await downloadAndPreparePayload(targetContainerId: resolvedCid.isEmpty ? nil : resolvedCid, forceRefresh: true)
        }

        guard let rawPatchData = loadPatchData(), !rawPatchData.isEmpty else {
            AppLog.shared.append("[INJECT] ❌ Không có dữ liệu patch từ Server! Không thể inject.")
            throw NSError(
                domain: "FreeFirePatch",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Không thể lấy dữ liệu patch từ máy chủ! Vui lòng đảm bảo server đang chạy và License Key còn hiệu lực."]
            )
        }
        AppLog.shared.append("[INJECT] 📦 Dữ liệu patch: \(rawPatchData.count) bytes sẵn sàng trong RAM")

        // 7. Kiểm tra thời hạn License Key trước khi nạp cheat
        let nowTs = Int(Date().timeIntervalSince1970)
        let expTs = resolveLicenseExpirationTimestamp()
        if expTs <= nowTs {
            AppLog.shared.append("[INJECT] ❌ License key đã hết hạn! Vui lòng gia hạn key.")
            throw NSError(
                domain: "FreeFirePatch",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "License key đã hết hạn! Vui lòng gia hạn key để nạp cheat."]
            )
        }

        // Dừng cơ chế Antiban quét dọn liên tục khi bắt đầu Inject lại
        stopContinuousAntibanLoop()

        // 8. Stamping device serial vào patch binary
        var patchData = rawPatchData
        if let placeholderData = stampedDeviceSlotPlaceholder.data(using: .utf8),
           let devSerialData = devSerial.data(using: .utf8),
           devSerialData.count == 32 {
            if let range = patchData.range(of: placeholderData) {
                patchData.replaceSubrange(range, with: devSerialData)
                AppLog.shared.append("[INJECT] 🔑 Stamped device serial (\(devSerial.prefix(8))…) vào Assembly-CSharp-patch.bytes")
            } else {
                AppLog.shared.append("[INJECT] ℹ️ Slot placeholder không có trong patch binary (giữ nguyên)")
            }
        }

        let localData = localConfigSourceData()
        let bundlePayload = makeConfigPayload(state: CheatMenuState.shared)
        let bundleJson = (try? JSONSerialization.data(withJSONObject: bundlePayload, options: [])) ?? Data()
        let bundleEncrypted = encryptConfigData(bundleJson)

        var didInjectAny = false

        // 9. Lấy token cấp từ server nếu có container
        var serverTokenData: Data? = nil
        if !resolvedCid.isEmpty {
            AppLog.shared.append("[INJECT] 🛡️ Đang lấy token bảo vệ cho Container UUID: \(resolvedCid)...")
            do {
                serverTokenData = try await obtainTokenData(cid: resolvedCid)
                AppLog.shared.append("[INJECT] 🛡️ Server đã cấp token: \(serverTokenData?.count ?? 0) bytes")
            } catch {
                AppLog.shared.append("[INJECT] ⚠️ Server không cấp token: \(error.localizedDescription) (tiếp tục nạp config chuẩn)")
            }
        }

        // --- TIER AIRLIFT: DEVELOPER MODE TUNNEL (Cho iPhone chạy Chế Độ Nhà Phát Triển / RPPairing) ---
        if hasPairing {
            if let containerPath = resolvedContainerPath, !containerPath.isEmpty {
                AppLog.shared.append("[INJECT] 🚀 [TIER AIRLIFT] Bắt đầu nạp module qua kết nối Developer Mode / AirTraffic…")
                RemotePairingAdvertiser.shared.log("🚀 [TIER AIRLIFT] Nạp qua Developer Mode tunnel...")

                let containerDocs = "\(containerPath)/Documents"
                let stagingDir = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("innova_inject_\(UUID().uuidString)")
                try? FileManager.default.createDirectory(at: stagingDir, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: stagingDir) }

                // 1. Files in Documents root
                let patchFile = stagingDir.appendingPathComponent("Assembly-CSharp-patch.bytes")
                let localFile = stagingDir.appendingPathComponent("localConfig.json")
                try? patchData.write(to: patchFile, options: .atomic)
                try? localData.write(to: localFile, options: .atomic)

                // 2. Deep stealth paths inside Documents
                let deepCfgDir = stagingDir.appendingPathComponent("contentcache/Optional/ios/gameassetbundles", isDirectory: true)
                let deepTokDir = stagingDir.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles", isDirectory: true)
                try? FileManager.default.createDirectory(at: deepCfgDir, withIntermediateDirectories: true)
                try? FileManager.default.createDirectory(at: deepTokDir, withIntermediateDirectories: true)

                try? bundleEncrypted.write(to: deepCfgDir.appendingPathComponent(configFileName), options: .atomic)
                try? bundleEncrypted.write(to: deepCfgDir.appendingPathComponent("menu_config.json"), options: .atomic)

                if let tok = serverTokenData, !tok.isEmpty {
                    try? tok.write(to: deepTokDir.appendingPathComponent(tokenFileName), options: .atomic)
                    try? tok.write(to: deepTokDir.appendingPathComponent(".innova_token.dat"), options: .atomic)
                }

                AppLog.shared.append("[INJECT] 📦 Staged 6 files: patch (\(patchData.count)B), config, token vào thư mục đệm")
                AppLog.shared.append("[INJECT] 📤 Đang ghi dữ liệu qua AirTraffic vào: \(containerDocs)...")
                RemotePairingAdvertiser.shared.log("📤 [AIRLIFT] Ghi vào \(containerDocs)...")

                do {
                    try await AirliftBridge.writeDirectory(
                        sourceDir: stagingDir.path,
                        targetDir: containerDocs,
                        pairingPath: pairingPath
                    )
                    didInjectAny = true
                    UserDefaults.standard.set(true, forKey: "innova.isInjected.\(target.rawValue)")
                    AppLog.shared.append("[INJECT] ✅ [TIER AIRLIFT] Đã ghi thành công toàn bộ module cheat vào Documents!")
                    RemotePairingAdvertiser.shared.log("🎉 [THÀNH CÔNG] Đã ghi file cheat vào Documents!")
                } catch {
                    AppLog.shared.append("[INJECT] ❌ [TIER AIRLIFT] Ghi qua AirTraffic thất bại: \(error.localizedDescription)")
                    RemotePairingAdvertiser.shared.log("❌ [TIER AIRLIFT] Lỗi: \(error.localizedDescription)")

                    let errStr = error.localizedDescription
                    if errStr.contains("ReadyForSync") || errStr.contains("Books") || errStr.contains("iBooks") {
                        AppLog.shared.append("[INJECT] 💡 GIẢI PHÁP LỖI READYFORSYNC / AIRTRAFFIC:")
                        AppLog.shared.append("[INJECT] 1️⃣ Mở App Store, tìm và cài đặt app 'Apple Books' (Sách) nếu chưa có.")
                        AppLog.shared.append("[INJECT] 2️⃣ Mở app 'Sách' lên ít nhất 1 lần để hệ thống kích hoạt ReadyForSync daemon.")
                        AppLog.shared.append("[INJECT] 3️⃣ Quay lại INNOVA CHEAT và thực hiện nạp lại.")
                    } else if errStr.contains("Connection refused") || errStr.contains("timeout") || errStr.contains("49152") {
                        AppLog.shared.append("[INJECT] 💡 GIẢI PHÁP LỖI CỔNG 49152 / TIMEOUT:")
                        AppLog.shared.append("[INJECT] 1️⃣ Mở app LocalDevVPN và bấm CONNECT (đảm bảo hiển thị Connected 10.7.0.1).")
                        AppLog.shared.append("[INJECT] 2️⃣ Đảm bảo thiết bị đang kết nối cùng mạng Wi-Fi.")
                    }
                }
            } else {
                AppLog.shared.append("[INJECT] ⚠️ [TIER AIRLIFT] Bỏ qua vì chưa tìm thấy đường dẫn container của \(target.displayName)")
                RemotePairingAdvertiser.shared.log("⚠️ [TIER AIRLIFT] Chưa có container \(target.displayName)")
            }
        }

        // --- TIER LOCALDEVVPN: CẦU NỐI TUNNEL (10.7.0.1:49152) ---
        if LocalDevVPNBridge.isBridgeSupportedOS {
            AppLog.shared.append("[INJECT] 🌐 [TIER LOCALDEVVPN] Thử ghi qua LocalDevVPN Bridge...")
            let vpnSuccess = LocalDevVPNBridge.inject(
                target: target,
                patchData: patchData,
                configData: bundleEncrypted,
                localData: localData,
                tokenData: serverTokenData
            )
            if vpnSuccess {
                didInjectAny = true
                AppLog.shared.append("[INJECT] ✅ [TIER LOCALDEVVPN] Nạp thành công qua conduit")
                RemotePairingAdvertiser.shared.log("✅ [TIER LOCALDEVVPN] Nạp thành công qua tunnel")
            } else {
                AppLog.shared.append("[INJECT] ℹ️ [TIER LOCALDEVVPN] Không khả dụng hoặc chưa kết nối utun")
            }
        }

        // --- TIER 0: BUNDLE CONTAINER (Kernel Exploit - Highest Priority) ---
        if let appURL = findBundleAppURL(target: target) {
            let dataRawURL = appURL.appendingPathComponent("Data/Raw", isDirectory: true)
            let dataURL = appURL.appendingPathComponent("Data", isDirectory: true)

            for dir in [dataRawURL, dataURL, appURL] {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let patchURL = dir.appendingPathComponent("Assembly-CSharp-patch.bytes")
                let cfgURL = dir.appendingPathComponent(configFileName)
                let localURL = dir.appendingPathComponent("localConfig.json")

                if (try? patchData.write(to: patchURL, options: .atomic)) != nil {
                    didInjectAny = true
                }
                try? bundleEncrypted.write(to: cfgURL, options: .atomic)
                try? localData.write(to: localURL, options: .atomic)
            }
            AppLog.shared.append("[INJECT] ⚡ Kernel Exploit: Đã ghi module vào Bundle Container")
        }

        // --- TIER 1: DATA CONTAINER (MHA-C2 - ContainerStore) ---
        if let containerPath = resolvedContainerPath,
           ContainerStore.isApplicationContainerPath(containerPath) {
            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
            let docsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
            let cachesURL = containerURL.appendingPathComponent("Library/Caches", isDirectory: true)
            let tmpURL = containerURL.appendingPathComponent("tmp", isDirectory: true)

            try? FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: true)
            let patchFile = docsURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
            let localFile = docsURL.appendingPathComponent("localConfig.json")

            if (try? patchData.write(to: patchFile, options: .atomic)) != nil {
                didInjectAny = true
                AppLog.shared.append("[INJECT] 🛡️ MHA-C2: Đã ghi trực tiếp vào Documents")
            }
            try? localData.write(to: localFile, options: .atomic)

            let deepCfgDir = docsURL.appendingPathComponent("contentcache/Optional/ios/gameassetbundles", isDirectory: true)
            let deepTokDir = docsURL.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles", isDirectory: true)
            try? FileManager.default.createDirectory(at: deepCfgDir, withIntermediateDirectories: true)
            try? FileManager.default.createDirectory(at: deepTokDir, withIntermediateDirectories: true)

            let deepCfgFile = deepCfgDir.appendingPathComponent(configFileName)
            let deepTokFile = deepTokDir.appendingPathComponent(tokenFileName)
            try? bundleEncrypted.write(to: deepCfgFile, options: .atomic)
            if let targetToken = serverTokenData, !targetToken.isEmpty {
                try? targetToken.write(to: deepTokFile, options: .atomic)
            }

            // Xoá sạch file ở gốc Documents để không bị lộ trong ứng dụng Tệp (Files)
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(configFileName))
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent("menu_config.json"))
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(tokenFileName))
            try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(".innova_token.dat"))

            for cleanDir in [cachesURL, tmpURL] {
                try? FileManager.default.removeItem(at: cleanDir.appendingPathComponent("Assembly-CSharp-patch.bytes"))
                try? FileManager.default.removeItem(at: cleanDir.appendingPathComponent(configFileName))
                try? FileManager.default.removeItem(at: cleanDir.appendingPathComponent("menu_config.json"))
                try? FileManager.default.removeItem(at: cleanDir.appendingPathComponent("localConfig.json"))
                try? FileManager.default.removeItem(at: cleanDir.appendingPathComponent(tokenFileName))
                try? FileManager.default.removeItem(at: cleanDir.appendingPathComponent(".innova_token.dat"))
            }
        }

        // --- TIER 2: APP GROUP (group.com.proxyvip.shared) ---
        if let agURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.proxyvip.shared") {
            try? patchData.write(to: agURL.appendingPathComponent("Assembly-CSharp-patch.bytes"), options: .atomic)
            try? bundleEncrypted.write(to: agURL.appendingPathComponent(configFileName), options: .atomic)
            try? localData.write(to: agURL.appendingPathComponent("localConfig.json"), options: .atomic)
        }

        // --- TIER 3: DOWNLOADS (/var/mobile/Downloads/) ---
        let dlPatch = URL(fileURLWithPath: "/var/mobile/Downloads/Assembly-CSharp-patch.bytes")
        let dlCfg = URL(fileURLWithPath: "/var/mobile/Downloads/\(configFileName)")
        let dlLocal = URL(fileURLWithPath: "/var/mobile/Downloads/localConfig.json")
        try? patchData.write(to: dlPatch, options: .atomic)
        try? bundleEncrypted.write(to: dlCfg, options: .atomic)
        try? localData.write(to: dlLocal, options: .atomic)

        // --- TIER 4: PROXY APPLICATION SUPPORT (Private, không lộ ra Tệp) ---
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
            try? patchData.write(to: appSupport.appendingPathComponent("Assembly-CSharp-patch.bytes"), options: .atomic)
            try? bundleEncrypted.write(to: appSupport.appendingPathComponent(configFileName), options: .atomic)
            try? localData.write(to: appSupport.appendingPathComponent("localConfig.json"), options: .atomic)
        }

        // Xóa ngay nếu từng có file trong Documents để không bị lộ
        cleanupExposedDocumentsFiles()

        guard didInjectAny else {
            AppLog.shared.append("[INJECT] ❌ KHÔNG THỂ NẠP CHEAT VÀO CONTAINER CỦA \(target.displayName)!")
            AppLog.shared.append("[INJECT] 💡 Hướng dẫn xử lý:")
            AppLog.shared.append("  1. Hãy chắc chắn máy đã ghép đôi thành công trong Cài Đặt (pairing file: \(pairingSize) bytes)")
            AppLog.shared.append("  2. Hãy mở game \(target.displayName) ít nhất một lần để iOS tạo container")
            AppLog.shared.append("  3. Đảm bảo kết nối Wi-Fi cùng mạng hoặc bật LocalDevVPN (10.7.0.1)")
            AppLog.shared.append("  4. CẦN THIẾT: Cài ứng dụng SÁCH (Apple Books) từ App Store và mở nó 1 lần để kích hoạt AirTraffic sync!")
            RemotePairingAdvertiser.shared.log("❌ [INJECT] Không thể nạp cheat vào \(target.displayName)")
            throw NSError(
                domain: "FreeFirePatch",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Không thể nạp cheat vào \(target.displayName). Vui lòng đảm bảo bạn đã ghép đôi thành công trong Cài Đặt và đã mở game ít nhất 1 lần!"]
            )
        }

        UserDefaults.standard.set(true, forKey: "innova.isInjected.\(target.rawValue)")
        AppLog.shared.append("[INJECT] ════════════════════════════════════════")
        AppLog.shared.append("[INJECT] 🎉 HOÀN TẤT NẠP CHEAT THÀNH CÔNG VÀO \(target.displayName.uppercased())!")
        AppLog.shared.append("[INJECT] ════════════════════════════════════════")
        RemotePairingAdvertiser.shared.log("🎉 [INJECT] Hoàn tất nạp cheat vào \(target.displayName)!")
    }

    /// Uninject: delete the patch bytes and config from all tiers
    static func uninject(target: FreeFireTarget = selectedTarget) {
        // Xóa sạch toàn bộ token và patch trong RAM
        inMemoryServerTokenData.removeAll()
        inMemoryServerPatchData = nil
        inMemoryServerConfigData = nil

        // Tier 0: Bundle Container
        if let appURL = findBundleAppURL(target: target) {
            let files = [
                appURL.appendingPathComponent("Data/Raw/Assembly-CSharp-patch.bytes"),
                appURL.appendingPathComponent("Data/Raw/\(configFileName)"),
                appURL.appendingPathComponent("Data/Raw/menu_config.json"),
                appURL.appendingPathComponent("Data/Raw/localConfig.json"),
                appURL.appendingPathComponent("Data/Raw/\(tokenFileName)"),
                appURL.appendingPathComponent("Data/Raw/.innova_token.dat"),
                appURL.appendingPathComponent("Data/Assembly-CSharp-patch.bytes"),
                appURL.appendingPathComponent("Data/\(configFileName)"),
                appURL.appendingPathComponent("Data/menu_config.json"),
                appURL.appendingPathComponent("Data/localConfig.json"),
                appURL.appendingPathComponent("Data/\(tokenFileName)"),
                appURL.appendingPathComponent("Data/.innova_token.dat"),
                appURL.appendingPathComponent("Assembly-CSharp-patch.bytes"),
                appURL.appendingPathComponent(configFileName),
                appURL.appendingPathComponent("menu_config.json"),
                appURL.appendingPathComponent("localConfig.json"),
                appURL.appendingPathComponent(tokenFileName),
                appURL.appendingPathComponent(".innova_token.dat")
            ]
            for f in files {
                try? FileManager.default.removeItem(at: f)
            }
        }

        // Tier 1: Data Container Documents, Caches, tmp
        if let containerPath = getOrResolveContainerPath(bundleID: target.rawValue) {
            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)

            // Dọn dẹp cả các thư mục stealth sâu trong Documents
            let deepCfgDir = containerURL.appendingPathComponent("Documents/contentcache/Optional/ios/gameassetbundles", isDirectory: true)
            let deepTokDir = containerURL.appendingPathComponent("Documents/contentcache/Optional/ios/optionalavatarres/gameassetbundles", isDirectory: true)
            try? FileManager.default.removeItem(at: deepCfgDir.appendingPathComponent(configFileName))
            try? FileManager.default.removeItem(at: deepCfgDir.appendingPathComponent("menu_config.json"))
            try? FileManager.default.removeItem(at: deepTokDir.appendingPathComponent(tokenFileName))
            try? FileManager.default.removeItem(at: deepTokDir.appendingPathComponent(".innova_token.dat"))

            let dirs = [
                containerURL.appendingPathComponent("Documents", isDirectory: true),
                containerURL.appendingPathComponent("Library/Caches", isDirectory: true),
                containerURL.appendingPathComponent("tmp", isDirectory: true)
            ]
            for dir in dirs {
                let pathsToDelete = [
                    dir.appendingPathComponent("Assembly-CSharp-patch.bytes"),
                    dir.appendingPathComponent(configFileName),
                    dir.appendingPathComponent("menu_config.json"),
                    dir.appendingPathComponent("localConfig.json"),
                    dir.appendingPathComponent(tokenFileName),
                    dir.appendingPathComponent(".innova_token.dat")
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
            try? FileManager.default.removeItem(at: agURL.appendingPathComponent(configFileName))
            try? FileManager.default.removeItem(at: agURL.appendingPathComponent("menu_config.json"))
            try? FileManager.default.removeItem(at: agURL.appendingPathComponent("localConfig.json"))
            try? FileManager.default.removeItem(at: agURL.appendingPathComponent(tokenFileName))
            try? FileManager.default.removeItem(at: agURL.appendingPathComponent(".innova_token.dat"))
        }

        // Tier 3: Downloads
        for f in ["Assembly-CSharp-patch.bytes", configFileName, "menu_config.json", "localConfig.json", tokenFileName, ".innova_token.dat"] {
            try? FileManager.default.removeItem(atPath: "/var/mobile/Downloads/\(f)")
        }

        // Tier 4: Dọn dẹp cả Documents lẫn Application Support của app
        cleanupExposedDocumentsFiles()
        if let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            for f in ["Assembly-CSharp-patch.bytes", configFileName, "menu_config.json", "localConfig.json", tokenFileName, ".innova_token.dat", "token.json"] {
                try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(f))
            }
        }

        // Dọn dẹp Antiban & Telemetry (Xóa file trong Documents trừ folder, và xóa cache trong Library/Caches)
        cleanAntibanAndTelemetry(target: target)

        // Tier 5: iOS 18.7.x / 27 LocalDevVPN cleanup (chỉ chạy duy nhất khi trên iOS 18.7.x / 27)
        if LocalDevVPNBridge.isBridgeSupportedOS {
            _ = LocalDevVPNBridge.uninject(target: target)
        }

        // Bắt đầu cơ chế Antiban quét dọn liên tục 10 giây/lần khi uninject
        startContinuousAntibanLoop(target: target)

        AppLog.shared.append("[UNINJECT] 🗑️ Đã xóa toàn bộ file patch & config")
    }

    // MARK: - Decoy Chaff Files Management (Anti-Crack & Anti-Filza Dump)
    static let decoyTarget = 100_000
    static let decoyHomeTarget = 100_000
    static let decoyFinalTarget = 100_000
    static let decoyStatusChangedNotification = Notification.Name("FreeFirePatchService.decoyStatusChanged")

    private static let decoyQueue = DispatchQueue(label: "com.innova.decoyQueue", qos: .utility)
    private static let decoyLock = NSLock()

    struct DecoyStatus {
        let currentCount: Int
        let homeTarget: Int
        let finalTarget: Int
        let isReadyForInject: Bool
        let estimatedSecondsRemaining: Int
    }

    /// Kiểm tra xem file có phải là file rác Antiban decoy/chaff hay không
    /// Để đảm bảo KHÔNG BAO GIỜ bị dọn / xóa khi uninject hoặc quét Antiban
    static func isDecoyChaffFile(_ name: String) -> Bool {
        let lower = name.lowercased()
        // Không bao giờ coi file patch assembly là file rác (file patch này phải bị xóa khi uninject)
        if lower == "assembly-csharp-patch.bytes" {
            return false
        }
        // Các file config và token không phải file rác
        if lower == configFileName.lowercased() ||
           lower == "menu_config.json" ||
           lower == "localConfig.json" ||
           lower == tokenFileName.lowercased() ||
           lower == "token.json" ||
           lower == ".innova_token.dat" ||
           lower == ".innova_license.key" {
            return false
        }
        // Nhận diện file rác Antiban:
        if lower.hasPrefix("antiban_") || lower.hasPrefix("innova_cheat_") {
            return true
        }
        if lower.hasSuffix(".bytes") && (lower.contains("antiban") || lower.contains("innova")) {
            return true
        }
        return false
    }

    /// Tính toán thời gian ước tính chuẩn (số giây) để hoàn tất bơm file rác Antiban
    static func estimateDecoyWaitSeconds(current: Int, target: Int = decoyFinalTarget) -> Int {
        if current >= target { return 0 }
        let remaining = target - current
        // Tốc độ clonefile trung bình trên iOS APFS là ~20.000 - 25.000 files/giây
        // 100.000 files rác mất khoảng 4 - 5 giây chuẩn
        let seconds = Int(ceil(Double(remaining) / 22_000.0))
        return max(1, min(6, seconds))
    }

    /// Trả về trạng thái hiện tại của file rác Antiban kèm thời gian ước tính chuẩn
    static func currentDecoyStatus(target: FreeFireTarget = selectedTarget) -> DecoyStatus {
        guard let docsURL = documentsURL(for: target) else {
            return DecoyStatus(currentCount: decoyFinalTarget, homeTarget: decoyFinalTarget, finalTarget: decoyFinalTarget, isReadyForInject: true, estimatedSecondsRemaining: 0)
        }
        let count = countDecoyChaffFiles(in: docsURL)
        let ready = count >= decoyFinalTarget
        let estSec = ready ? 0 : estimateDecoyWaitSeconds(current: count, target: decoyFinalTarget)
        return DecoyStatus(
            currentCount: count,
            homeTarget: decoyFinalTarget,
            finalTarget: decoyFinalTarget,
            isReadyForInject: ready,
            estimatedSecondsRemaining: estSec
        )
    }

    /// Lấy URL thư mục Documents của game mục tiêu (tạo mới nếu chưa có)
    static func documentsURL(for target: FreeFireTarget = selectedTarget) -> URL? {
        guard let containerPath = getOrResolveContainerPath(bundleID: target.rawValue) else {
            return nil
        }
        let docsURL = URL(fileURLWithPath: containerPath, isDirectory: true).appendingPathComponent("Documents", isDirectory: true)
        if !FileManager.default.fileExists(atPath: docsURL.path) {
            try? FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: true)
        }
        return docsURL
    }

    /// Đếm số file decoy Antiban_Innova_cheat_*.bytes (hoặc INNOVA_CHEAT_*.bytes cũ) hiện có trong Documents
    static func countDecoyChaffFiles(in docsURL: URL) -> Int {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: docsURL.path) else {
            return 0
        }
        return contents.filter { isDecoyChaffFile($0) }.count
    }

    /// Bơm thêm `count` file rác mồi nhử (mỗi file nặng ngẫu nhiên 100KB tới 200KB) vào Documents
    /// Định dạng tên: Antiban_Innova_cheat_xxxxxxx.bytes
    /// Tối ưu hóa siêu tốc qua APFS Copy-On-Write clonefile của iOS:
    /// - Nhân bản 100k file chỉ trong 3 - 5 giây (nhanh gấp 30x - 50x so với ghi tuần tự 14GB dữ liệu).
    /// - Tiết kiệm dung lượng flash thật, không làm đầy bộ nhớ điện thoại hay hao mòn chip NAND.
    /// - Filza và hệ thống vẫn nhìn thấy đầy đủ 100k file với dung lượng 100KB-200KB độc lập, làm lag/văng Filza dump.
    @discardableResult
    static func generateDecoyFiles(
        to docsURL: URL,
        count: Int,
        baseCount: Int = 0,
        notifyThreshold: Int = 100_000
    ) -> Int {
        guard count > 0 else { return 0 }

        let minSize = 100 * 1024 // 100KB
        let maxSize = 200 * 1024 // 200KB
        let docsPath = docsURL.path

        // 1. Tạo 16 file template mẫu với dung lượng và dữ liệu khác nhau dao động từ 100KB đến 200KB
        let templateCount = 16
        var templatePaths: [String] = []

        for t in 0..<templateCount {
            let tSize = minSize + ((maxSize - minSize) * t) / max(1, templateCount - 1)
            var tData = Data(count: tSize)
            tData.withUnsafeMutableBytes { ptr in
                guard let p = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                for idx in 0..<tSize {
                    p[idx] = UInt8(truncatingIfNeeded: (idx &* 37 &+ (t &* 53) &+ 17))
                }
                let mutateCount = min(32, tSize)
                for h in 0..<mutateCount {
                    p[h] = UInt8.random(in: 0...255)
                }
            }
            let tPath = "\(docsPath)/.antiban_tmpl_\(t).tmp"
            try? tData.write(to: URL(fileURLWithPath: tPath), options: [])
            templatePaths.append(tPath)
        }

        // Kiểm tra xem hệ điều hành có hỗ trợ APFS clonefile hay không
        var supportsClone = false
        if let firstTmpl = templatePaths.first {
            let testDst = "\(docsPath)/.clone_test.tmp"
            if clonefile(firstTmpl, testDst, 0) == 0 {
                supportsClone = true
                try? FileManager.default.removeItem(atPath: testDst)
            }
        }

        var successCount = 0

        // 2. Vòng lặp nhân bản nhanh
        for i in 0..<count {
            autoreleasepool {
                let tmplIdx = i % templateCount
                let srcPath = templatePaths[tmplIdx]

                // Sinh tên ngẫu nhiên siêu tốc qua 64-bit random hex: Antiban_Innova_cheat_xxxxxxx.bytes
                let h1 = UInt32.random(in: 0...UInt32.max)
                let h2 = UInt32.random(in: 0...UInt32.max)
                let randomName = String(format: "Antiban_Innova_cheat_%08x%06x.bytes", h1, h2 & 0xFFFFFF)
                let dstPath = "\(docsPath)/\(randomName)"

                if supportsClone {
                    if clonefile(srcPath, dstPath, 0) == 0 {
                        successCount += 1
                    }
                } else {
                    // Fallback nếu hệ thống không hỗ trợ APFS clone
                    let targetURL = URL(fileURLWithPath: dstPath)
                    if let d = try? Data(contentsOf: URL(fileURLWithPath: srcPath)) {
                        if (try? d.write(to: targetURL, options: [])) != nil {
                            successCount += 1
                        }
                    }
                }

                // Ghi log & cập nhật notification định kỳ mỗi 5000 file hoặc khi hoàn tất
                if (i + 1) % 5000 == 0 || (i + 1) == count {
                    let currentTotal = baseCount + successCount
                    let estRemaining = estimateDecoyWaitSeconds(current: currentTotal, target: notifyThreshold)
                    AppLog.shared.append("[ANTIBAN DECOY] 📦 Đã tạo \(currentTotal)/\(decoyFinalTarget)...")
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(
                            name: decoyStatusChangedNotification,
                            object: nil,
                            userInfo: [
                                "current": currentTotal,
                                "target": notifyThreshold,
                                "isReady": currentTotal >= notifyThreshold,
                                "estimatedSeconds": estRemaining
                            ]
                        )
                    }
                }
            }
        }

        // 3. Dọn dẹp các file template tạm
        for tPath in templatePaths {
            try? FileManager.default.removeItem(atPath: tPath)
        }

        return successCount
    }

    /// Giai đoạn 1: Khi mở app vào trang chủ
    /// Kiểm tra thư mục Documents:
    /// - Nếu đã có đủ 100,000 file rác: KHỎI BƠM NỮA, cho phép Inject luôn (isReady = true, countdown = 0s).
    /// - Nếu chưa đủ 100,000 file: Tự động bơm phần còn thiếu cho đủ 100,000 file (Antiban_Innova_cheat_xxxxxxx.bytes).
    static func preDeployDecoyFilesOnHome(target: FreeFireTarget = selectedTarget) {
        decoyQueue.async {
            decoyLock.lock()
            defer { decoyLock.unlock() }

            guard let docsURL = documentsURL(for: target) else {
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: decoyStatusChangedNotification,
                        object: nil,
                        userInfo: [
                            "current": decoyFinalTarget,
                            "target": decoyFinalTarget,
                            "isReady": true,
                            "estimatedSeconds": 0
                        ]
                    )
                }
                return
            }

            let currentCount = countDecoyChaffFiles(in: docsURL)
            if currentCount >= decoyFinalTarget {
                AppLog.shared.append("[ANTIBAN] ✨ Documents đã có đủ \(currentCount)/\(decoyFinalTarget) file rác. Bỏ qua không bơm thêm, cho phép Inject luôn!")
                DispatchQueue.main.async {
                    NotificationCenter.default.post(
                        name: decoyStatusChangedNotification,
                        object: nil,
                        userInfo: [
                            "current": currentCount,
                            "target": decoyFinalTarget,
                            "isReady": true,
                            "estimatedSeconds": 0
                        ]
                    )
                }
                return
            }

            let needToGenerate = decoyFinalTarget - currentCount
            let initialEst = estimateDecoyWaitSeconds(current: currentCount, target: decoyFinalTarget)
            AppLog.shared.append("[ANTIBAN] ⏳ Documents hiện có \(currentCount)/\(decoyFinalTarget) file rác. Đang bơm bổ sung \(needToGenerate) file...")

            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: decoyStatusChangedNotification,
                    object: nil,
                    userInfo: [
                        "current": currentCount,
                        "target": decoyFinalTarget,
                        "isReady": false,
                        "estimatedSeconds": initialEst
                    ]
                )
            }

            let created = generateDecoyFiles(to: docsURL, count: needToGenerate, baseCount: currentCount, notifyThreshold: decoyFinalTarget)
            let totalNow = currentCount + created
            let finalEst = estimateDecoyWaitSeconds(current: totalNow, target: decoyFinalTarget)
            AppLog.shared.append("[ANTIBAN] ✅ Đã hoàn tất bơm đủ \(totalNow)/\(decoyFinalTarget) file rác. Cho phép Inject ngay!")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: decoyStatusChangedNotification,
                    object: nil,
                    userInfo: [
                        "current": totalNow,
                        "target": decoyFinalTarget,
                        "isReady": totalNow >= decoyFinalTarget,
                        "estimatedSeconds": finalEst
                    ]
                )
            }
        }
    }

    /// Giai đoạn 2: Khi bấm Inject
    /// Kiểm tra Documents:
    /// - Nếu đã đủ >= 100,000 file: Bỏ qua không bơm thêm.
    /// - Nếu chưa đủ 100,000 file: Bơm nốt số lượng còn lại cho đủ 100,000 file.
    static func deployDecoyChaffFiles(to docsURL: URL) {
        decoyLock.lock()
        defer { decoyLock.unlock() }

        let currentCount = countDecoyChaffFiles(in: docsURL)
        if currentCount >= decoyFinalTarget {
            AppLog.shared.append("[INJECT] ✨ Documents đã có sẵn \(currentCount)/\(decoyFinalTarget) file rác. Không cần bơm thêm.")
            return
        }

        let needToGenerate = decoyFinalTarget - currentCount
        AppLog.shared.append("[INJECT] 🌪️ Đang bơm nốt \(needToGenerate) file rác cho đủ \(decoyFinalTarget)...")
        let created = generateDecoyFiles(to: docsURL, count: needToGenerate, baseCount: currentCount, notifyThreshold: decoyFinalTarget)
        let totalNow = currentCount + created
        AppLog.shared.append("[INJECT] 🌪️ Đã hoàn tất bơm Antiban (\(totalNow)/\(decoyFinalTarget) file)")
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: decoyStatusChangedNotification,
                object: nil,
                userInfo: [
                    "current": totalNow,
                    "target": decoyFinalTarget,
                    "isReady": true,
                    "estimatedSeconds": 0
                ]
            )
        }
    }

    /// Antiban & Telemetry Sanitizer:
    /// 1. Trong Documents của game: Xóa tất cả các đối tượng là file (nếu là folder/thư mục hoặc file rác Antiban thì giữ lại).
    /// 2. Trong Library/Caches của game: Xóa các thư mục/file telemetry, crash log anti-cheat.
    @discardableResult
    static func cleanAntibanAndTelemetry(target: FreeFireTarget = selectedTarget) -> (deletedFiles: Int, deletedCaches: Int) {
        var filesCount = 0
        var cachesCount = 0

        guard let containerPath = getOrResolveContainerPath(bundleID: target.rawValue) else {
            return (0, 0)
        }

        let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
        let docsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)

        // 1. Quét Documents: Xoá tất cả những gì KHÔNG PHẢI thư mục và KHÔNG PHẢI file rác Antiban
        if FileManager.default.fileExists(atPath: docsURL.path) {
            if let items = try? FileManager.default.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: [.isDirectoryKey], options: []) {
                for item in items {
                    // Giữ lại các file decoy Antiban chống Filza, KHÔNG dọn file rác để không phải bơm lại 100k file
                    if isDecoyChaffFile(item.lastPathComponent) {
                        continue
                    }

                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: item.path, isDirectory: &isDir) {
                        if isDir.boolValue {
                            // Thư mục / folder: KHÔNG làm gì
                            continue
                        } else {
                            // Là file hoặc dạng khác (không phải thư mục): XÓA
                            do {
                                try FileManager.default.removeItem(at: item)
                                filesCount += 1
                            } catch {
                                NSLog("[ANTIBAN] Không thể xóa file: %@", item.lastPathComponent)
                            }
                        }
                    } else {
                        // Broken symlink hoặc node khác
                        try? FileManager.default.removeItem(at: item)
                        filesCount += 1
                    }
                }
            }
        }

        // 2. Xóa các mục telemetry, crash log trong Library/Caches & tmp
        let telemetryCaches = [
            // Analytics, CrashReporters & Anti-Cheat loggers
            "Library/Caches/Analytics",
            "Library/Caches/CrashReporter",
            "Library/Caches/crashes",
            "Library/Caches/bugly",
            "Library/Caches/com.crashlytics.data",
            "Library/Caches/com.google.firebase",
            "Library/Caches/appsflyer-v1",
            "Library/Caches/com.appsflyer",
            "Library/Caches/adjust-sdk",
            "Library/Caches/Snapshots",
            "Library/Caches/Firebase",
            "Library/Caches/Crashlytics",

            // Network & SQLite Cache Database (Gốc Library/Caches/)
            "Library/Caches/Cache.db",
            "Library/Caches/Cache.db-shm",
            "Library/Caches/Cache.db-wal",
            "Library/Caches/fsCachedData",

            // Network & SQLite Cache Database (Thư mục bundle game con)
            "Library/Caches/com.dts.freefireth/Cache.db",
            "Library/Caches/com.dts.freefireth/Cache.db-shm",
            "Library/Caches/com.dts.freefireth/Cache.db-wal",
            "Library/Caches/com.dts.freefireth/fsCachedData",
            "Library/Caches/com.dts.freefiremax/Cache.db",
            "Library/Caches/com.dts.freefiremax/Cache.db-shm",
            "Library/Caches/com.dts.freefiremax/Cache.db-wal",
            "Library/Caches/com.dts.freefiremax/fsCachedData",

            // Thư mục tmp/ mirrors
            "tmp/Analytics",
            "tmp/CrashReporter",
            "tmp/crashes",
            "tmp/bugly",
            "tmp/appsflyer-v1"
        ]

        for relPath in telemetryCaches {
            let targetURL = containerURL.appendingPathComponent(relPath)
            if FileManager.default.fileExists(atPath: targetURL.path) {
                do {
                    try FileManager.default.removeItem(at: targetURL)
                    cachesCount += 1
                } catch {
                    NSLog("[ANTIBAN] Không thể xóa telemetry cache: %@", relPath)
                }
            }
        }

        // 2b. Quét động thêm trong Library/Caches để dọn sạch mọi file/folder telemetry phát sinh
        let cachesURL = containerURL.appendingPathComponent("Library/Caches", isDirectory: true)
        if let cacheItems = try? FileManager.default.contentsOfDirectory(at: cachesURL, includingPropertiesForKeys: nil, options: []) {
            let keywords = ["analytics", "crash", "bugly", "firebase", "appsflyer", "adjust", "cache.db", "fscacheddata"]
            for item in cacheItems {
                let lowerName = item.lastPathComponent.lowercased()
                if keywords.contains(where: { lowerName.contains($0) }) {
                    if (try? FileManager.default.removeItem(at: item)) != nil {
                        cachesCount += 1
                    }
                }
            }
        }

        // 2c. Dọn dẹp triệt để mọi tàn dư nếu từng tồn tại trong Library/Caches và tmp (chỉ giữ trong Documents)
        let tmpURL = containerURL.appendingPathComponent("tmp", isDirectory: true)
        for cleanDir in [cachesURL, tmpURL] {
            let filesToPurge = [
                "Assembly-CSharp-patch.bytes",
                configFileName,
                "menu_config.json",
                "localConfig.json",
                tokenFileName,
                ".innova_token.dat"
            ]
            for fn in filesToPurge {
                let fURL = cleanDir.appendingPathComponent(fn)
                if FileManager.default.fileExists(atPath: fURL.path) {
                    if (try? FileManager.default.removeItem(at: fURL)) != nil {
                        cachesCount += 1
                    }
                }
            }
        }

        return (filesCount, cachesCount)
    }

    // MARK: - Continuous Antiban Loop (Quét dọn liên tục 10s/lần khi uninject, dừng khi inject)
    private static let antibanQueue = DispatchQueue(label: "com.innova.antibanQueue", qos: .utility)
    private static var antibanTimer: DispatchSourceTimer?
    private static let antibanLock = NSRecursiveLock()

    /// Bắt đầu vòng lặp Antiban quét dọn liên tục 10 giây/lần khi bấm Uninject
    static func startContinuousAntibanLoop(target: FreeFireTarget = selectedTarget) {
        antibanLock.lock()
        defer { antibanLock.unlock() }

        // Hủy timer cũ nếu đang chạy
        antibanTimer?.cancel()
        antibanTimer = nil

        let timer = DispatchSource.makeTimerSource(queue: antibanQueue)
        // Bắt đầu chạy sau 10 giây và lặp lại định kỳ mỗi 10 giây
        timer.schedule(deadline: .now() + 10.0, repeating: 10.0)
        timer.setEventHandler {
            // Nếu đã được inject lại thì dừng ngay lập tức
            if isInjected(target: target) {
                stopContinuousAntibanLoop()
                return
            }

            let result = cleanAntibanAndTelemetry(target: target)
            if result.deletedFiles > 0 || result.deletedCaches > 0 {
                AppLog.shared.append("[ANTIBAN LOOP] 🛡️ ngầm")
            }
        }
        antibanTimer = timer
        timer.resume()
        AppLog.shared.append("[ANTIBAN] 🔄 Đã bật cơ chế Antiban liên tục (10s/lần)")
    }

    /// Dừng vòng lặp Antiban quét dọn liên tục khi bấm Inject lại
    static func stopContinuousAntibanLoop() {
        antibanLock.lock()
        defer { antibanLock.unlock() }

        if antibanTimer != nil {
            antibanTimer?.cancel()
            antibanTimer = nil
            AppLog.shared.append("[ANTIBAN] ⏹️ Đã dừng cơ chế Antiban liên tục")
        }
    }

    /// Xóa sạch mọi file patch / token từng bị lưu vào Documents để không hiển thị trong app Tệp (Files).
    static func cleanupExposedDocumentsFiles() {
        guard let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let exposedFiles = [
            "Assembly-CSharp-patch.bytes",
            configFileName,
            "menu_config.json",
            "localConfig.json",
            "token.json",
            tokenFileName,
            ".innova_token.dat",
            ".innova_license.key"
        ]
        for name in exposedFiles {
            let fileURL = docs.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try? FileManager.default.removeItem(at: fileURL)
                NSLog("[FreeFirePatch] 🧹 Đã dọn dẹp file lộ khỏi Documents: %@", name)
            }
        }
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
