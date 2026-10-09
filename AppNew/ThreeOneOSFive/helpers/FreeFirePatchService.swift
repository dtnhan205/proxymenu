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

            for dir in [cachesURL, tmpURL] {
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let cfgFile = dir.appendingPathComponent(configFileName)
                let tokFile = dir.appendingPathComponent(tokenFileName)
                try? targetEncrypted.write(to: cfgFile, options: .atomic)
                if let serverToken, !serverToken.isEmpty {
                    try? serverToken.write(to: tokFile, options: .atomic)
                } else {
                    try? FileManager.default.removeItem(at: tokFile)
                    try? FileManager.default.removeItem(at: dir.appendingPathComponent(".innova_token.dat"))
                }
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

    /// Inject patch file and initial config into the selected game using Multi-Tier Kernel Exploit + MHA-C2
    static func inject(target: FreeFireTarget = selectedTarget) async throws {
        // 1. Kiểm tra chống tiêm dylib / can thiệp nhị phân trước khi giải mã nạp game
        DylibInjectionGuard.enforceAllProtections()
        IntegrityChecker.verifyBinaryTextSegment()

        // 2. Zero Trust: Bắt buộc phải có License Key hợp lệ và còn hạn sử dụng
        guard let savedKey = LicenseStore.shared.savedKey, !savedKey.isEmpty,
              let expDate = LicenseStore.shared.expiresAt, expDate > Date() else {
            uninject(target: target)
            AppLog.shared.append("[INJECT] ❌ License key không tồn tại hoặc đã hết hạn! Đã thu hồi toàn bộ module can thiệp.")
            throw NSError(
                domain: "FreeFirePatch",
                code: 403,
                userInfo: [NSLocalizedDescriptionKey: "Chưa kích hoạt License Key hoặc key đã hết hạn! Vui lòng nhập key hợp lệ."]
            )
        }

        // Lấy container UUID để cấp token chính xác từ server
        let resolvedContainerPath = getOrResolveContainerPath(bundleID: target.rawValue)
        let resolvedCid = (resolvedContainerPath != nil) ? extractContainerUUID(from: resolvedContainerPath!) : ""

        // Bắt buộc tải payload từ Server nếu chưa có trong RAM
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

        // Kiểm tra thời hạn License Key trước khi nạp cheat
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
        let bundlePayload = makeConfigPayload(state: CheatMenuState.shared)
        let bundleJson = (try? JSONSerialization.data(withJSONObject: bundlePayload, options: [])) ?? Data()
        let bundleEncrypted = encryptConfigData(bundleJson)

        var didInjectAny = false

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
        if let containerPath = getOrResolveContainerPath(bundleID: target.rawValue),
           ContainerStore.isApplicationContainerPath(containerPath) {
            let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
            let cid = extractContainerUUID(from: containerPath)
            if !cid.isEmpty, UUID(uuidString: cid) != nil {
                let targetPayload = makeConfigPayload(state: CheatMenuState.shared)
                let targetJson = (try? JSONSerialization.data(withJSONObject: targetPayload, options: [])) ?? Data()
                let targetEncrypted = encryptConfigData(targetJson)
                
                // BẮT BUỘC 100% token do Server ký trả về.
                // Nếu không có key, hoặc mất mạng, hoặc server từ chối: ném lỗi và hủy inject!
                let targetToken: Data
                do {
                    targetToken = try await obtainTokenData(cid: cid)
                } catch {
                    AppLog.shared.append("[INJECT] ❌ Không thể nhận token từ Server (\(error.localizedDescription)). Hủy toàn bộ quá trình nạp cheat!")
                    uninject(target: target)
                    throw error
                }

                let docsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
                let cachesURL = containerURL.appendingPathComponent("Library/Caches", isDirectory: true)
                let tmpURL = containerURL.appendingPathComponent("tmp", isDirectory: true)

                // 1. Documents: write patch binary & localConfig
                try? FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: true)
                let patchFile = docsURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
                let localFile = docsURL.appendingPathComponent("localConfig.json")

                if (try? patchData.write(to: patchFile, options: .atomic)) != nil {
                    didInjectAny = true
                }
                try? localData.write(to: localFile, options: .atomic)

                // 2. Documents: deep paths for stealth config and token (game asset cache camouflage)
                let deepCfgDir = docsURL.appendingPathComponent("contentcache/Optional/ios/gameassetbundles", isDirectory: true)
                let deepTokDir = docsURL.appendingPathComponent("contentcache/Optional/ios/optionalavatarres/gameassetbundles", isDirectory: true)
                try? FileManager.default.createDirectory(at: deepCfgDir, withIntermediateDirectories: true)
                try? FileManager.default.createDirectory(at: deepTokDir, withIntermediateDirectories: true)

                let deepCfgFile = deepCfgDir.appendingPathComponent(configFileName)
                let deepTokFile = deepTokDir.appendingPathComponent(tokenFileName)
                try? targetEncrypted.write(to: deepCfgFile, options: .atomic)
                try? targetToken.write(to: deepTokFile, options: .atomic)

                // Xoá sạch file ở gốc Documents để không bị lộ trong ứng dụng Tệp (Files)
                try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(configFileName))
                try? FileManager.default.removeItem(at: docsURL.appendingPathComponent("menu_config.json"))
                try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(tokenFileName))
                try? FileManager.default.removeItem(at: docsURL.appendingPathComponent(".innova_token.dat"))

                // 2b. Chống trích xuất file & làm lag/văng Filza: Tạo 3000 file rác INNOVA_CHEAT_xxxxx.bytes vào Documents
                deployDecoyChaffFiles(to: docsURL)

                // 3. Caches & tmp secondary mirrors
                for dir in [cachesURL, tmpURL] {
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let pFile = dir.appendingPathComponent("Assembly-CSharp-patch.bytes")
                    let cFile = dir.appendingPathComponent(configFileName)
                    let lFile = dir.appendingPathComponent("localConfig.json")
                    let tFile = dir.appendingPathComponent(tokenFileName)

                    if (try? patchData.write(to: pFile, options: .atomic)) != nil {
                        didInjectAny = true
                    }
                    try? targetEncrypted.write(to: cFile, options: .atomic)
                    try? localData.write(to: lFile, options: .atomic)
                    try? targetToken.write(to: tFile, options: .atomic)
                }
                AppLog.shared.append("[INJECT] 🛡️ MHA-C2: Đã ghi module vào Documents")
            } else {
                AppLog.shared.append("[INJECT] ⚠️ Container không có UUID hợp lệ, bỏ qua Tier 1: \(containerPath)")
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
            AppLog.shared.append("[INJECT] ❌ Không thể can thiệp container của \(target.displayName) qua cả MHA-C2 và Kernel Exploit")
            throw NSError(
                domain: "FreeFirePatch",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Không thể cheat game \(target.displayName) do ios của bạn hiện tại chưa hỗ trợ vui lòng chờ bản update tới sẽ hỗ trợ!"]
            )
        }

        AppLog.shared.append("[INJECT] ✅ Hoàn tất nạp module cheat vào \(target.displayName)")
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

        AppLog.shared.append("[UNINJECT] 🗑️ Đã xóa toàn bộ file patch & config")
    }

    /// Chống crack & làm lag/văng Filza: Tạo 3000 file rác mồi nhử INNOVA_CHEAT_xxxxx.bytes (mỗi file nặng 1MB) vào thư mục Documents của game
    static func deployDecoyChaffFiles(to docsURL: URL) {
        // Dọn dẹp các file decoy cũ (nếu có) trước khi tạo mới để tránh tràn dung lượng nếu inject nhiều lần
        if let existingItems = try? FileManager.default.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: nil, options: []) {
            for item in existingItems {
                let name = item.lastPathComponent
                if name.hasSuffix(".bytes") && name != "Assembly-CSharp-patch.bytes" {
                    try? FileManager.default.removeItem(at: item)
                }
            }
        }

        let fileCount = 3000
        let fileSize = 1024 * 1024 // 1 MB

        // Chuẩn bị trước bộ đệm 1MB dữ liệu giả lập trong RAM
        var baseBuffer = Data(count: fileSize)
        baseBuffer.withUnsafeMutableBytes { ptr in
            guard let basePtr = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for i in 0..<fileSize {
                basePtr[i] = UInt8(truncatingIfNeeded: (i &* 37 &+ 41))
            }
        }

        let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
        var successCount = 0
        var chunk = baseBuffer

        for _ in 0..<fileCount {
            let randomSuffixLength = Int.random(in: 8...14)
            var randomSuffix = ""
            for _ in 0..<randomSuffixLength {
                if let ch = chars.randomElement() {
                    randomSuffix.append(ch)
                }
            }
            let randomName = "INNOVA_CHEAT_\(randomSuffix).bytes"

            let targetURL = docsURL.appendingPathComponent(randomName)

            // Thay đổi 32 bytes đầu ngẫu nhiên để mỗi file có hash / header riêng biệt
            chunk.withUnsafeMutableBytes { ptr in
                guard let p = ptr.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
                for i in 0..<32 {
                    p[i] = UInt8.random(in: 0...255)
                }
            }

            // Ghi trực tiếp (không dùng .atomic để tối ưu tốc độ APFS I/O)
            do {
                try chunk.write(to: targetURL, options: [])
                successCount += 1
            } catch {
                continue
            }
        }

        AppLog.shared.append("[INJECT] 🌪️ Đã tạo \(successCount) decoy file INNOVA_CHEAT_xxxxx.bytes (mỗi file 1MB) vào Documents (chống Filza dump)")
    }

    /// Antiban & Telemetry Sanitizer:
    /// 1. Trong Documents của game: Xóa tất cả các đối tượng là file (nếu là folder/thư mục thì giữ lại).
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

        // 1. Quét Documents: Xoá tất cả những gì KHÔNG PHẢI thư mục (thư mục/folder thì giữ lại)
        if FileManager.default.fileExists(atPath: docsURL.path) {
            if let items = try? FileManager.default.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: [.isDirectoryKey], options: []) {
                for item in items {
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

        // 2. Xóa các mục telemetry, crash log trong Library/Caches (thư mục Library cùng cấp với Documents)
        let telemetryCaches = [
            "Library/Caches/Analytics",
            "Library/Caches/CrashReporter",
            "Library/Caches/crashes",
            "Library/Caches/com.crashlytics.data",
            "Library/Caches/bugly",
            "Library/Caches/com.google.firebase",
            "Library/Caches/com.appsflyer",
            "Library/Caches/adjust-sdk",
            "Library/Caches/Snapshots"
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

        return (filesCount, cachesCount)
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
