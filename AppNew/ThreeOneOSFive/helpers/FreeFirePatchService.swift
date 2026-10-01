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

    static var selectedTarget: FreeFireTarget {
        get {
            let val = UserDefaults.standard.string(forKey: targetKey) ?? FreeFireTarget.freeFireTH.rawValue
            return FreeFireTarget(rawValue: val) ?? .freeFireTH
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: targetKey)
        }
    }

    /// Check if Assembly-CSharp-patch.bytes is injected in the specified game container
    static func isInjected(target: FreeFireTarget = selectedTarget) -> Bool {
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: target.rawValue) else {
            return false
        }
        let ifixPath = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents/IFix/Assembly-CSharp-patch.bytes").path
        let altPath = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents/Assembly-CSharp-patch.bytes").path
        return FileManager.default.fileExists(atPath: ifixPath) || FileManager.default.fileExists(atPath: altPath)
    }

    /// Locate the patch bytes file from the app bundle or local resources
    static func patchSourceURL() -> URL? {
        // 1. Bundle main resource
        if let url = Bundle.main.url(forResource: "Assembly-CSharp-patch", withExtension: "bytes") {
            return url
        }
        // 2. Direct inside main bundle directory
        let bundleDirect = Bundle.main.bundleURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
        if FileManager.default.fileExists(atPath: bundleDirect.path) {
            return bundleDirect
        }
        // 3. Document directory of proxy app
        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let docFile = docs.appendingPathComponent("Assembly-CSharp-patch.bytes")
            if FileManager.default.fileExists(atPath: docFile.path) {
                return docFile
            }
        }
        // 4. Shared downloads
        let dl = URL(fileURLWithPath: "/var/mobile/Downloads/Assembly-CSharp-patch.bytes")
        if FileManager.default.fileExists(atPath: dl.path) {
            return dl
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
            "no_recoil": state.noRecoil ? 1 : 0,
            "aim_fov": Int(state.silentFOV),
            "headshot_rate": rateIndex,
            "color": state.espSelectedColorId,
            "line_bottom": 0
        ]
    }

    /// Sync the current configuration to the game container
    static func syncConfig(target: FreeFireTarget = selectedTarget, state: CheatMenuState = CheatMenuState.shared) {
        let payload = makeConfigPayload(state: state)
        guard let jsonData = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]) else {
            return
        }

        // 1. Write to Game Data Container Documents
        if let containerPath = ContainerStore.resolveAppContainerPath(bundleID: target.rawValue) {
            let docsURL = URL(fileURLWithPath: containerPath).appendingPathComponent("Documents")
            try? FileManager.default.createDirectory(at: docsURL, withIntermediateDirectories: true)
            let configURL = docsURL.appendingPathComponent("menu_config.json")
            try? jsonData.write(to: configURL, options: .atomic)
            AppLog.shared.append("[CONFIG] 🔄 Đã đồng bộ cấu hình -> \(target.displayName)")
        }

        // 2. Also write to Downloads & Shared locations
        let dlURL = URL(fileURLWithPath: "/var/mobile/Downloads/menu_config.json")
        try? jsonData.write(to: dlURL, options: .atomic)

        if let proxyDocs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let proxyCfg = proxyDocs.appendingPathComponent("menu_config.json")
            try? jsonData.write(to: proxyCfg, options: .atomic)
        }
    }

    /// Inject patch file and initial config into the selected game
    static func inject(target: FreeFireTarget = selectedTarget) async throws {
        guard let sourceURL = patchSourceURL(), let patchData = try? Data(contentsOf: sourceURL) else {
            AppLog.shared.append("[INJECT] ❌ Không tìm thấy Assembly-CSharp-patch.bytes trong Bundle")
            throw NSError(
                domain: "FreeFirePatch",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy file Assembly-CSharp-patch.bytes trong IPA!"]
            )
        }

        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: target.rawValue),
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

        // Write Assembly-CSharp-patch.bytes into Documents/IFix/ and Documents/
        let targetPatch1 = ifixURL.appendingPathComponent("Assembly-CSharp-patch.bytes")
        let targetPatch2 = docsURL.appendingPathComponent("Assembly-CSharp-patch.bytes")

        try patchData.write(to: targetPatch1, options: .atomic)
        try? patchData.write(to: targetPatch2, options: .atomic)

        // Write menu_config.json
        syncConfig(target: target)

        AppLog.shared.append("[INJECT] ✅ Đã Inject thành công vào \(target.displayName)")
    }

    /// Uninject: delete the patch bytes and config from game container
    static func uninject(target: FreeFireTarget = selectedTarget) {
        guard let containerPath = ContainerStore.resolveAppContainerPath(bundleID: target.rawValue) else {
            AppLog.shared.append("[UNINJECT] ⚠️ Không tìm thấy container \(target.displayName)")
            return
        }

        let containerURL = URL(fileURLWithPath: containerPath, isDirectory: true)
        let docsURL = containerURL.appendingPathComponent("Documents", isDirectory: true)
        let ifixURL = docsURL.appendingPathComponent("IFix", isDirectory: true)

        let pathsToDelete = [
            ifixURL.appendingPathComponent("Assembly-CSharp-patch.bytes"),
            docsURL.appendingPathComponent("Assembly-CSharp-patch.bytes"),
            docsURL.appendingPathComponent("menu_config.json")
        ]

        for p in pathsToDelete {
            if FileManager.default.fileExists(atPath: p.path) {
                try? FileManager.default.removeItem(at: p)
            }
        }

        // Also clean up download config
        let dlConfig = URL(fileURLWithPath: "/var/mobile/Downloads/menu_config.json")
        if FileManager.default.fileExists(atPath: dlConfig.path) {
            try? FileManager.default.removeItem(at: dlConfig)
        }

        AppLog.shared.append("[UNINJECT] 🗑️ Đã xóa file patch (Uninject) khỏi \(target.displayName)")
    }
}
