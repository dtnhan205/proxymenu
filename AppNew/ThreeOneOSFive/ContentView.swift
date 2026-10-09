import SwiftUI
import UIKit

// MARK: - Cheat Tab Enum (AIM, ESP, MISC)
enum CheatTab: Int, CaseIterable {
    case aim = 0
    case esp = 1
    case misc = 2

    var title: String {
        switch self {
        case .aim: return "AIM"
        case .esp: return "ESP"
        case .misc: return "MISC"
        }
    }

    var icon: String {
        switch self {
        case .aim: return "scope"
        case .esp: return "eye.fill"
        case .misc: return "slider.horizontal.3"
        }
    }
}

// MARK: - AimBot Target Enum (Head vs Neck)
enum AimBotTarget: String, CaseIterable, Identifiable {
    case head = "head"
    case neck = "neck"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .head: return "Đầu (Head)"
        case .neck: return "Cổ (Neck)"
        }
    }

    var subtitle: String {
        switch self {
        case .head: return "Headshot tối đa"
        case .neck: return "Tự nhiên, an toàn"
        }
    }

    var icon: String {
        switch self {
        case .head: return "target"
        case .neck: return "person.crop.circle"
        }
    }
}

// MARK: - ESP Color Target (Toàn bộ hoặc từng loại ESP)
enum ESPColorTarget: Int, CaseIterable, Identifiable {
    case all = 0
    case box = 1
    case line = 2
    case health = 3
    case tag = 4

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .all: return "Tất Cả"
        case .box: return "Khung Box"
        case .line: return "Tia Line"
        case .health: return "Thanh Máu"
        case .tag: return "Tên & Cự Ly"
        }
    }

    var shortTitle: String {
        switch self {
        case .all: return "Tất Cả"
        case .box: return "Box"
        case .line: return "Line"
        case .health: return "Máu"
        case .tag: return "Tên/Cự Ly"
        }
    }

    var icon: String {
        switch self {
        case .all: return "paintpalette.fill"
        case .box: return "shippingbox.fill"
        case .line: return "line.diagonal"
        case .health: return "cross.case.fill"
        case .tag: return "tag.fill"
        }
    }
}

// MARK: - ESP Color Definition (10 Colors Palette)
struct CheatColorOption: Identifiable, Hashable {
    let id: Int
    let name: String
    let color: Color
    let hex: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: CheatColorOption, rhs: CheatColorOption) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Cheat State & Settings Persistence
final class CheatMenuState: ObservableObject {
    static let shared = CheatMenuState()

    private func syncIfInjected() {
        guard FreeFirePatchService.isInjected() else { return }
        guard let key = LicenseStore.shared.savedKey, !key.isEmpty else {
            FreeFirePatchService.uninject()
            return
        }
        if let exp = LicenseStore.shared.expiresAt, exp <= Date() {
            FreeFirePatchService.uninject()
            return
        }
        FreeFirePatchService.syncConfig(state: self)
    }

    // AIMING
    @Published var aimSilent: Bool {
        didSet {
            UserDefaults.standard.set(aimSilent, forKey: "cheat.aimSilent")
            AppLog.shared.append("[AIM] Aim Silent: \(aimSilent ? "ENABLED" : "DISABLED")")
            if aimSilent && aimBot {
                aimBot = false
            }
            syncIfInjected()
        }
    }
    @Published var drawFOV: Bool {
        didSet {
            UserDefaults.standard.set(drawFOV, forKey: "cheat.drawFOV")
            AppLog.shared.append("[AIM] Vòng FOV: \(drawFOV ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var silentFOV: Double {
        didSet {
            UserDefaults.standard.set(silentFOV, forKey: "cheat.silentFOV")
            syncIfInjected()
        }
    }
    @Published var headshotRate: Double {
        didSet {
            UserDefaults.standard.set(headshotRate, forKey: "cheat.headshotRate")
            syncIfInjected()
        }
    }
    @Published var aimBot: Bool {
        didSet {
            UserDefaults.standard.set(aimBot, forKey: "cheat.aimBot")
            AppLog.shared.append("[AIM] Aim Bot: \(aimBot ? "ENABLED" : "DISABLED")")
            if aimBot && aimSilent {
                aimSilent = false
            }
            syncIfInjected()
        }
    }
    @Published var aimBotTarget: AimBotTarget {
        didSet {
            UserDefaults.standard.set(aimBotTarget.rawValue, forKey: "cheat.aimBotTarget")
            AppLog.shared.append("[AIM] Aim Target: \(aimBotTarget.displayName)")
            syncIfInjected()
        }
    }
    @Published var aimLine: Bool {
        didSet {
            UserDefaults.standard.set(aimLine, forKey: "cheat.aimLine")
            AppLog.shared.append("[AIM] Aim Line: \(aimLine ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }

    // ESP
    @Published var boxESP: Bool {
        didSet {
            UserDefaults.standard.set(boxESP, forKey: "cheat.boxESP")
            AppLog.shared.append("[ESP] Box ESP: \(boxESP ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var lineESP: Bool {
        didSet {
            UserDefaults.standard.set(lineESP, forKey: "cheat.lineESP")
            AppLog.shared.append("[ESP] Line ESP: \(lineESP ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var healthBar: Bool {
        didSet {
            UserDefaults.standard.set(healthBar, forKey: "cheat.healthBar")
            AppLog.shared.append("[ESP] Health Bar: \(healthBar ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var nameTag: Bool {
        didSet {
            UserDefaults.standard.set(nameTag, forKey: "cheat.nameTag")
            AppLog.shared.append("[ESP] Name Tag: \(nameTag ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var distanceTag: Bool {
        didSet {
            UserDefaults.standard.set(distanceTag, forKey: "cheat.distanceTag")
            AppLog.shared.append("[ESP] Distance Tag: \(distanceTag ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var skeletonESP: Bool {
        didSet {
            UserDefaults.standard.set(skeletonESP, forKey: "cheat.skeletonESP")
            AppLog.shared.append("[ESP] Skeleton ESP: \(skeletonESP ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var espCount: Bool {
        didSet {
            UserDefaults.standard.set(espCount, forKey: "cheat.espCount")
            AppLog.shared.append("[ESP] ESP Count: \(espCount ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var espAlert: Bool {
        didSet {
            UserDefaults.standard.set(espAlert, forKey: "cheat.espAlert")
            AppLog.shared.append("[ESP] ESP Alert: \(espAlert ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }

    // ESP Colors for specific elements
    @Published var espColorEnabled: Bool {
        didSet {
            UserDefaults.standard.set(espColorEnabled, forKey: "cheat.espColorEnabled")
            syncIfInjected()
        }
    }
    @Published var espSelectedColorId: Int {
        didSet {
            UserDefaults.standard.set(espSelectedColorId, forKey: "cheat.espSelectedColorId")
            syncIfInjected()
        }
    }
    @Published var boxColorId: Int {
        didSet {
            UserDefaults.standard.set(boxColorId, forKey: "cheat.boxColorId")
            syncIfInjected()
        }
    }
    @Published var lineColorId: Int {
        didSet {
            UserDefaults.standard.set(lineColorId, forKey: "cheat.lineColorId")
            syncIfInjected()
        }
    }
    @Published var skeletonColorId: Int {
        didSet {
            UserDefaults.standard.set(skeletonColorId, forKey: "cheat.skeletonColorId")
            syncIfInjected()
        }
    }
    @Published var espLineThickness: Double {
        didSet {
            UserDefaults.standard.set(espLineThickness, forKey: "cheat.espLineThickness")
            syncIfInjected()
        }
    }

    // ESP RGB Colors & Thickness per element
    @Published var boxR: Double { didSet { UserDefaults.standard.set(boxR, forKey: "cheat.boxR"); syncIfInjected() } }
    @Published var boxG: Double { didSet { UserDefaults.standard.set(boxG, forKey: "cheat.boxG"); syncIfInjected() } }
    @Published var boxB: Double { didSet { UserDefaults.standard.set(boxB, forKey: "cheat.boxB"); syncIfInjected() } }
    @Published var boxThickness: Double { didSet { UserDefaults.standard.set(boxThickness, forKey: "cheat.boxThickness"); syncIfInjected() } }

    @Published var lineR: Double { didSet { UserDefaults.standard.set(lineR, forKey: "cheat.lineR"); syncIfInjected() } }
    @Published var lineG: Double { didSet { UserDefaults.standard.set(lineG, forKey: "cheat.lineG"); syncIfInjected() } }
    @Published var lineB: Double { didSet { UserDefaults.standard.set(lineB, forKey: "cheat.lineB"); syncIfInjected() } }
    @Published var lineThickness: Double { didSet { UserDefaults.standard.set(lineThickness, forKey: "cheat.lineThickness"); syncIfInjected() } }

    @Published var healthR: Double { didSet { UserDefaults.standard.set(healthR, forKey: "cheat.healthR"); syncIfInjected() } }
    @Published var healthG: Double { didSet { UserDefaults.standard.set(healthG, forKey: "cheat.healthG"); syncIfInjected() } }
    @Published var healthB: Double { didSet { UserDefaults.standard.set(healthB, forKey: "cheat.healthB"); syncIfInjected() } }
    @Published var healthThickness: Double { didSet { UserDefaults.standard.set(healthThickness, forKey: "cheat.healthThickness"); syncIfInjected() } }

    @Published var tagR: Double { didSet { UserDefaults.standard.set(tagR, forKey: "cheat.tagR"); syncIfInjected() } }
    @Published var tagG: Double { didSet { UserDefaults.standard.set(tagG, forKey: "cheat.tagG"); syncIfInjected() } }
    @Published var tagB: Double { didSet { UserDefaults.standard.set(tagB, forKey: "cheat.tagB"); syncIfInjected() } }
    @Published var tagThickness: Double { didSet { UserDefaults.standard.set(tagThickness, forKey: "cheat.tagThickness"); syncIfInjected() } }

    @Published var allR: Double { didSet { UserDefaults.standard.set(allR, forKey: "cheat.allR"); syncIfInjected() } }
    @Published var allG: Double { didSet { UserDefaults.standard.set(allG, forKey: "cheat.allG"); syncIfInjected() } }
    @Published var allB: Double { didSet { UserDefaults.standard.set(allB, forKey: "cheat.allB"); syncIfInjected() } }

    // COMBAT
    @Published var fastMedkit: Bool {
        didSet {
            UserDefaults.standard.set(fastMedkit, forKey: "cheat.fastMedkit")
            AppLog.shared.append("[COMBAT] Fast Medkit: \(fastMedkit ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var noRecoil: Bool {
        didSet {
            UserDefaults.standard.set(noRecoil, forKey: "cheat.noRecoil")
            AppLog.shared.append("[COMBAT] Đạn Thẳng (No Recoil): \(noRecoil ? "ENABLED (CẢNH BÁO LỖI DAME)" : "DISABLED")")
            syncIfInjected()
        }
    }

    @Published var buffDamage: Bool {
        didSet {
            UserDefaults.standard.set(buffDamage, forKey: "cheat.buffDamage")
            syncIfInjected()
        }
    }
    @Published var fastFire: Bool {
        didSet {
            UserDefaults.standard.set(fastFire, forKey: "cheat.fastFire")
            syncIfInjected()
        }
    }
    @Published var wideView: Bool {
        didSet {
            UserDefaults.standard.set(wideView, forKey: "cheat.wideView")
            syncIfInjected()
        }
    }
    @Published var camDistance: Double {
        didSet {
            UserDefaults.standard.set(camDistance, forKey: "cheat.camDistance")
            syncIfInjected()
        }
    }
    @Published var speedRun: Bool {
        didSet {
            UserDefaults.standard.set(speedRun, forKey: "cheat.speedRun")
            AppLog.shared.append("[SURVIVAL] Chạy Nhanh (Speed Run): \(speedRun ? "ENABLED (CẢNH BÁO LỖI DAME)" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var fastParachute: Bool {
        didSet {
            UserDefaults.standard.set(fastParachute, forKey: "cheat.fastParachute")
            syncIfInjected()
        }
    }
    @Published var backJump: Bool {
        didSet {
            UserDefaults.standard.set(backJump, forKey: "cheat.backJump")
            AppLog.shared.append("[SURVIVAL] BACKJUMP: \(backJump ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var highJump: Bool {
        didSet {
            UserDefaults.standard.set(highJump, forKey: "cheat.highJump")
            AppLog.shared.append("[SURVIVAL] NHẢY CAO (High Jump): \(highJump ? "ENABLED (1.2x)" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var fastRotation: Bool {
        didSet {
            UserDefaults.standard.set(fastRotation, forKey: "cheat.fastRotation")
            AppLog.shared.append("[SURVIVAL] ĐẢO NHƯ PC (Fast Rotation): \(fastRotation ? "ENABLED (9999.9°/s)" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var chamsOutline: Bool {
        didSet {
            UserDefaults.standard.set(chamsOutline, forKey: "cheat.chamsOutline")
            AppLog.shared.append("[ESP] VIỀN ĐỎ NHÂN VẬT (Chams Outline): \(chamsOutline ? "ENABLED (500m)" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var fastSwap: Bool {
        didSet {
            UserDefaults.standard.set(fastSwap, forKey: "cheat.fastSwap")
            AppLog.shared.append("[COMBAT] ĐỔI SÚNG NHANH (Fast Swap): \(fastSwap ? "ENABLED (0s Delay)" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var noGrass: Bool {
        didSet {
            UserDefaults.standard.set(noGrass, forKey: "cheat.noGrass")
            AppLog.shared.append("[SURVIVAL] KHỬ CỎ 100% (No Grass): \(noGrass ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var noFog: Bool {
        didSet {
            UserDefaults.standard.set(noFog, forKey: "cheat.noFog")
            AppLog.shared.append("[SURVIVAL] KHỬ SƯƠNG MÙ (No Fog): \(noFog ? "ENABLED (1000m)" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var fastLoot: Bool {
        didSet {
            UserDefaults.standard.set(fastLoot, forKey: "cheat.fastLoot")
            AppLog.shared.append("[SURVIVAL] LOOT ĐỒ NHANH (Fast Loot): \(fastLoot ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var fastCrouch: Bool {
        didSet {
            UserDefaults.standard.set(fastCrouch, forKey: "cheat.fastCrouch")
            AppLog.shared.append("[SURVIVAL] NGỒI DI CHUYỂN NHANH (Fast Crouch Run): \(fastCrouch ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var superEmote: Bool {
        didSet {
            UserDefaults.standard.set(superEmote, forKey: "cheat.superEmote")
            AppLog.shared.append("[SURVIVAL] ĐIỆU NHẢY BOOYAH (Super Emote): \(superEmote ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var fastReload: Bool {
        didSet {
            UserDefaults.standard.set(fastReload, forKey: "cheat.fastReload")
            AppLog.shared.append("[COMBAT] NẠP ĐẠN NHANH (Fast Reload): \(fastReload ? "ENABLED (0.05s)" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var unlockFps: Bool {
        didSet {
            UserDefaults.standard.set(unlockFps, forKey: "cheat.unlockFps")
            AppLog.shared.append("[SYSTEM] MỞ KHÓA 120/144 FPS (Ultra Smooth): \(unlockFps ? "ENABLED (144 FPS)" : "DISABLED (60 FPS)")")
            syncIfInjected()
        }
    }
    @Published var spinBot: Bool {
        didSet {
            UserDefaults.standard.set(spinBot, forKey: "cheat.spinBot")
            AppLog.shared.append("[VIP] SPIN BOT (Spinbot 360°): \(spinBot ? "ENABLED (\(Int(spinSpeed))°/s)" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var spinSpeed: Double {
        didSet {
            UserDefaults.standard.set(spinSpeed, forKey: "cheat.spinSpeed")
            syncIfInjected()
        }
    }

    // 7 Rich, Vibrant Gaming Color Palette
    let colorOptions: [CheatColorOption] = [
        CheatColorOption(id: 0, name: "Đỏ Neon (Crimson Red)", color: Color(red: 1.00, green: 0.16, blue: 0.24), hex: "#FF293E"),
        CheatColorOption(id: 1, name: "Xanh Cyan (Electric Blue)", color: Color(red: 0.00, green: 0.90, blue: 1.00), hex: "#00E5FF"),
        CheatColorOption(id: 2, name: "Xanh Lá (Matrix Green)", color: Color(red: 0.05, green: 0.92, blue: 0.42), hex: "#0DE061"),
        CheatColorOption(id: 3, name: "Vàng Kim (Cyber Gold)", color: Color(red: 1.00, green: 0.82, blue: 0.12), hex: "#FFD11F"),
        CheatColorOption(id: 4, name: "Cam Lửa (Flame Orange)", color: Color(red: 1.00, green: 0.48, blue: 0.00), hex: "#FF7A00"),
        CheatColorOption(id: 5, name: "Tím Neon (Neon Purple)", color: Color(red: 0.62, green: 0.00, blue: 1.00), hex: "#9D00FF"),
        CheatColorOption(id: 6, name: "Hồng Neon (Cyber Pink)", color: Color(red: 1.00, green: 0.18, blue: 0.58), hex: "#FF1493")
    ]

    func getColor(for id: Int) -> CheatColorOption {
        colorOptions.first(where: { $0.id == id }) ?? colorOptions[0]
    }

    var selectedColor: CheatColorOption {
        getColor(for: espSelectedColorId)
    }

    func getRGBForPresetId(_ id: Int) -> (Double, Double, Double) {
        switch id {
        case 0: return (255, 41, 62)    // Đỏ Neon
        case 1: return (0, 229, 255)    // Xanh Cyan
        case 2: return (13, 224, 97)    // Xanh Lá
        case 3: return (255, 209, 31)   // Vàng Kim
        case 4: return (255, 122, 0)    // Cam Lửa
        case 5: return (157, 0, 255)    // Tím Neon
        case 6: return (255, 20, 147)   // Hồng Neon
        default: return (0, 229, 255)
        }
    }

    func findClosestPresetId(r: Double, g: Double, b: Double) -> Int {
        var closest = 1
        var minDiff = Double.infinity
        for id in 0...6 {
            let pr = getRGBForPresetId(id)
            let diff = (r - pr.0)*(r - pr.0) + (g - pr.1)*(g - pr.1) + (b - pr.2)*(b - pr.2)
            if diff < minDiff {
                minDiff = diff
                closest = id
            }
        }
        return closest
    }

    func getRGB(for target: ESPColorTarget) -> (r: Double, g: Double, b: Double) {
        switch target {
        case .all: return (allR, allG, allB)
        case .box: return (boxR, boxG, boxB)
        case .line: return (lineR, lineG, lineB)
        case .health: return (healthR, healthG, healthB)
        case .tag: return (tagR, tagG, tagB)
        }
    }

    func getColor(for target: ESPColorTarget) -> Color {
        let rgb = getRGB(for: target)
        return Color(red: rgb.r / 255.0, green: rgb.g / 255.0, blue: rgb.b / 255.0)
    }

    func getHex(for target: ESPColorTarget) -> String {
        let rgb = getRGB(for: target)
        let r = Int(min(max(rgb.r, 0), 255))
        let g = Int(min(max(rgb.g, 0), 255))
        let b = Int(min(max(rgb.b, 0), 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    func setRGB(r: Double, g: Double, b: Double, for target: ESPColorTarget) {
        let cr = min(max(r, 0), 255)
        let cg = min(max(g, 0), 255)
        let cb = min(max(b, 0), 255)
        switch target {
        case .all:
            allR = cr; allG = cg; allB = cb
            boxR = cr; boxG = cg; boxB = cb
            lineR = cr; lineG = cg; lineB = cb
            healthR = cr; healthG = cg; healthB = cb
            tagR = cr; tagG = cg; tagB = cb
        case .box:
            boxR = cr; boxG = cg; boxB = cb
        case .line:
            lineR = cr; lineG = cg; lineB = cb
        case .health:
            healthR = cr; healthG = cg; healthB = cb
        case .tag:
            tagR = cr; tagG = cg; tagB = cb
        }
        let closest = findClosestPresetId(r: cr, g: cg, b: cb)
        espSelectedColorId = closest
        if target == .box || target == .all { boxColorId = closest }
        if target == .line || target == .all { lineColorId = closest }
    }

    func getThickness(for target: ESPColorTarget) -> Double {
        switch target {
        case .all: return boxThickness
        case .box: return boxThickness
        case .line: return lineThickness
        case .health: return healthThickness
        case .tag: return tagThickness
        }
    }

    func setThickness(_ val: Double, for target: ESPColorTarget) {
        let v = min(max(val, 1.0), 10.0)
        switch target {
        case .all:
            boxThickness = v
            lineThickness = v
            healthThickness = v
            tagThickness = v
            espLineThickness = v
        case .box:
            boxThickness = v
        case .line:
            lineThickness = v
            espLineThickness = v
        case .health:
            healthThickness = v
        case .tag:
            tagThickness = v
        }
    }

    func getColorId(for target: ESPColorTarget) -> Int {
        switch target {
        case .all: return espSelectedColorId
        case .box: return boxColorId
        case .line: return lineColorId
        case .health: return 2
        case .tag: return 3
        }
    }

    func setColorId(_ id: Int, for target: ESPColorTarget) {
        let rgb = getRGBForPresetId(id)
        setRGB(r: rgb.0, g: rgb.1, b: rgb.2, for: target)
    }

    init() {
        let ud = UserDefaults.standard
        let rawAimBot = ud.object(forKey: "cheat.aimBot") as? Bool ?? false
        var rawAimSilent = ud.object(forKey: "cheat.aimSilent") as? Bool ?? false

        if rawAimBot && rawAimSilent {
            rawAimSilent = false
            ud.set(false, forKey: "cheat.aimSilent")
        }

        self.aimSilent = rawAimSilent
        self.drawFOV = ud.object(forKey: "cheat.drawFOV") as? Bool ?? true
        self.silentFOV = ud.object(forKey: "cheat.silentFOV") as? Double ?? 180.0
        self.headshotRate = ud.object(forKey: "cheat.headshotRate") as? Double ?? 100.0
        self.aimBot = rawAimBot
        let targetStr = ud.string(forKey: "cheat.aimBotTarget") ?? "head"
        self.aimBotTarget = AimBotTarget(rawValue: targetStr) ?? .head
        self.aimLine = ud.object(forKey: "cheat.aimLine") as? Bool ?? false

        self.boxESP = ud.object(forKey: "cheat.boxESP") as? Bool ?? true
        self.lineESP = ud.object(forKey: "cheat.lineESP") as? Bool ?? true
        self.healthBar = ud.object(forKey: "cheat.healthBar") as? Bool ?? true
        self.nameTag = ud.object(forKey: "cheat.nameTag") as? Bool ?? false
        self.distanceTag = ud.object(forKey: "cheat.distanceTag") as? Bool ?? false
        self.skeletonESP = ud.object(forKey: "cheat.skeletonESP") as? Bool ?? false
        self.espCount = ud.object(forKey: "cheat.espCount") as? Bool ?? false
        self.espAlert = ud.object(forKey: "cheat.espAlert") as? Bool ?? false
        self.espColorEnabled = ud.object(forKey: "cheat.espColorEnabled") as? Bool ?? true

        self.espSelectedColorId = ud.object(forKey: "cheat.espSelectedColorId") as? Int ?? 1
        self.boxColorId = ud.object(forKey: "cheat.boxColorId") as? Int ?? 1
        self.lineColorId = ud.object(forKey: "cheat.lineColorId") as? Int ?? 1
        self.skeletonColorId = ud.object(forKey: "cheat.skeletonColorId") as? Int ?? 5
        self.espLineThickness = ud.object(forKey: "cheat.espLineThickness") as? Double ?? 2.5

        // RGB & Thickness Initializers
        self.boxR = ud.object(forKey: "cheat.boxR") as? Double ?? 0.0
        self.boxG = ud.object(forKey: "cheat.boxG") as? Double ?? 229.0
        self.boxB = ud.object(forKey: "cheat.boxB") as? Double ?? 255.0
        self.boxThickness = ud.object(forKey: "cheat.boxThickness") as? Double ?? 2.0

        self.lineR = ud.object(forKey: "cheat.lineR") as? Double ?? 0.0
        self.lineG = ud.object(forKey: "cheat.lineG") as? Double ?? 229.0
        self.lineB = ud.object(forKey: "cheat.lineB") as? Double ?? 255.0
        self.lineThickness = ud.object(forKey: "cheat.lineThickness") as? Double ?? 2.0

        self.healthR = ud.object(forKey: "cheat.healthR") as? Double ?? 13.0
        self.healthG = ud.object(forKey: "cheat.healthG") as? Double ?? 224.0
        self.healthB = ud.object(forKey: "cheat.healthB") as? Double ?? 97.0
        self.healthThickness = ud.object(forKey: "cheat.healthThickness") as? Double ?? 3.0

        self.tagR = ud.object(forKey: "cheat.tagR") as? Double ?? 255.0
        self.tagG = ud.object(forKey: "cheat.tagG") as? Double ?? 209.0
        self.tagB = ud.object(forKey: "cheat.tagB") as? Double ?? 31.0
        self.tagThickness = ud.object(forKey: "cheat.tagThickness") as? Double ?? 2.0

        self.allR = ud.object(forKey: "cheat.allR") as? Double ?? 0.0
        self.allG = ud.object(forKey: "cheat.allG") as? Double ?? 229.0
        self.allB = ud.object(forKey: "cheat.allB") as? Double ?? 255.0

        self.fastMedkit = ud.object(forKey: "cheat.fastMedkit") as? Bool ?? false
        self.noRecoil = ud.object(forKey: "cheat.noRecoil") as? Bool ?? false
        self.buffDamage = ud.object(forKey: "cheat.buffDamage") as? Bool ?? false
        self.fastFire = ud.object(forKey: "cheat.fastFire") as? Bool ?? false
        self.wideView = ud.object(forKey: "cheat.wideView") as? Bool ?? false
        self.camDistance = ud.object(forKey: "cheat.camDistance") as? Double ?? 85.0
        self.speedRun = ud.object(forKey: "cheat.speedRun") as? Bool ?? false
        self.fastParachute = ud.object(forKey: "cheat.fastParachute") as? Bool ?? false
        self.backJump = ud.object(forKey: "cheat.backJump") as? Bool ?? false
        self.highJump = ud.object(forKey: "cheat.highJump") as? Bool ?? false
        self.fastRotation = ud.object(forKey: "cheat.fastRotation") as? Bool ?? false
        self.chamsOutline = ud.object(forKey: "cheat.chamsOutline") as? Bool ?? false
        self.fastSwap = ud.object(forKey: "cheat.fastSwap") as? Bool ?? false
        self.noGrass = ud.object(forKey: "cheat.noGrass") as? Bool ?? false
        self.noFog = ud.object(forKey: "cheat.noFog") as? Bool ?? false
        self.fastLoot = ud.object(forKey: "cheat.fastLoot") as? Bool ?? false
        self.fastCrouch = ud.object(forKey: "cheat.fastCrouch") as? Bool ?? false
        self.superEmote = ud.object(forKey: "cheat.superEmote") as? Bool ?? false
        self.fastReload = ud.object(forKey: "cheat.fastReload") as? Bool ?? false
        self.unlockFps = ud.object(forKey: "cheat.unlockFps") as? Bool ?? false
        self.spinBot = ud.object(forKey: "cheat.spinBot") as? Bool ?? false
        self.spinSpeed = ud.object(forKey: "cheat.spinSpeed") as? Double ?? 1080.0
    }

    func resetToDefaults() {
        aimSilent = false
        drawFOV = true
        silentFOV = 180.0
        headshotRate = 100.0
        aimBot = false
        aimBotTarget = .head
        aimLine = false

        boxESP = true
        lineESP = true
        healthBar = true
        nameTag = false
        distanceTag = false
        skeletonESP = false
        espCount = false
        chamsOutline = false
        espAlert = false
        espColorEnabled = true
        espSelectedColorId = 1
        boxColorId = 1
        lineColorId = 1
        skeletonColorId = 5
        espLineThickness = 2.5

        boxR = 0.0
        boxG = 229.0
        boxB = 255.0
        boxThickness = 2.0

        lineR = 0.0
        lineG = 229.0
        lineB = 255.0
        lineThickness = 2.0

        healthR = 13.0
        healthG = 224.0
        healthB = 97.0
        healthThickness = 3.0

        tagR = 255.0
        tagG = 209.0
        tagB = 31.0
        tagThickness = 2.0

        allR = 0.0
        allG = 229.0
        allB = 255.0

        fastMedkit = false
        noRecoil = false
        buffDamage = false
        fastFire = false
        fastSwap = false
        wideView = false
        camDistance = 85.0
        speedRun = false
        fastParachute = false
        backJump = false
        highJump = false
        fastRotation = false
        noGrass = false
        noFog = false
        fastLoot = false
        fastCrouch = false
        superEmote = false
        fastReload = false
        unlockFps = false
        spinBot = false
        spinSpeed = 1080.0

        AppLog.shared.append("[CONFIG] Cheat settings reset to default values.")
        syncIfInjected()
    }
}

// MARK: - Cyber & Dark Sci-Fi Palette
private enum CyberTheme {
    static let bgVoid = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let bgPlate = Color(red: 0.075, green: 0.075, blue: 0.09)
    static let bgPlateElevated = Color(red: 0.105, green: 0.105, blue: 0.13)
    static let bgInput = Color(red: 0.05, green: 0.05, blue: 0.065)

    // Cyberpunk Crimson Energy
    static let crimsonNeon = Color(red: 1.00, green: 0.18, blue: 0.25)
    static let crimsonFlame = Color(red: 0.95, green: 0.32, blue: 0.12)
    static let crimsonDark = Color(red: 0.40, green: 0.05, blue: 0.10)
    static let crimsonRed = Color(red: 1.00, green: 0.18, blue: 0.25)
    static let flameOrange = Color(red: 0.95, green: 0.32, blue: 0.12)

    // Cyber High-Tech Accents
    static let cyberCyan = Color(red: 0.00, green: 0.88, blue: 0.98)
    static let mechaGold = Color(red: 1.00, green: 0.78, blue: 0.18)
    static let matrixGreen = Color(red: 0.00, green: 0.95, blue: 0.45)
    static let electricPurple = Color(red: 0.75, green: 0.35, blue: 1.00)

    static let cardBorderNormal = Color.white.opacity(0.09)
    static let divider = Color.white.opacity(0.07)
    static let textMuted = Color(white: 0.52)
    static let textSecondary = Color(white: 0.78)
}

// MARK: - 3D Cyber Card Container
struct CyberCard<Content: View>: View {
    var glowColor: Color = CyberTheme.crimsonNeon.opacity(0.08)
    var cornerRadius: CGFloat = 16
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            ZStack {
                // Background dark plate
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                CyberTheme.bgPlateElevated,
                                CyberTheme.bgPlate
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                // 3D Metallic Edge Highlight
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.20),
                                Color.white.opacity(0.05),
                                glowColor.opacity(0.6)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .clipped()
        .shadow(color: Color.black.opacity(0.55), radius: 8, x: 0, y: 4)
        .shadow(color: glowColor, radius: 10, x: 0, y: 0)
    }
}

// MARK: - Section Header with Equalizer Waveform
struct CyberSectionHeader: View {
    let title: String
    let subtitle: String
    let icon: String
    var accentColor: Color = CyberTheme.crimsonNeon

    var body: some View {
        HStack(spacing: 9) {
            ZStack {
                Circle()
                    .fill(accentColor.opacity(0.18))
                    .frame(width: 24, height: 24)
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(1.2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(CyberTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: 8)

            // Futuristic Waveform Bars
            HStack(spacing: 3) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(accentColor.opacity(0.9))
                    .frame(width: 3, height: 11)
                RoundedRectangle(cornerRadius: 1)
                    .fill(accentColor.opacity(0.6))
                    .frame(width: 3, height: 8)
                RoundedRectangle(cornerRadius: 1)
                    .fill(accentColor.opacity(0.35))
                    .frame(width: 3, height: 5)
            }
        }
        .padding(.horizontal, 4)
    }
}

// MARK: - Cyber 3D Toggle Style
struct CyberToggleStyle: ToggleStyle {
    var activeColor: Color = CyberTheme.crimsonNeon

    func makeBody(configuration: Configuration) -> some View {
        ZStack(alignment: configuration.isOn ? .trailing : .leading) {
            // Recessed Track
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(
                    configuration.isOn ?
                    LinearGradient(colors: [activeColor, activeColor.opacity(0.8)], startPoint: .leading, endPoint: .trailing) :
                    LinearGradient(colors: [Color(white: 0.14), Color(white: 0.10)], startPoint: .leading, endPoint: .trailing)
                )
                .frame(width: 48, height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(
                            configuration.isOn ?
                            Color.white.opacity(0.35) :
                            Color.white.opacity(0.12),
                            lineWidth: 1
                        )
                )
                .shadow(color: configuration.isOn ? activeColor.opacity(0.55) : Color.clear, radius: 6)

            // 3D Metallic Knob
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white, Color(white: 0.90)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 22, height: 22)
                .overlay(
                    Circle()
                        .strokeBorder(Color.black.opacity(0.15), lineWidth: 0.5)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 1.5)
                .padding(.horizontal, 3)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                configuration.isOn.toggle()
            }
        }
    }
}

// MARK: - Cyber Row View Component
struct CyberRowView: View {
    let iconName: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    var activeColor: Color = CyberTheme.crimsonNeon
    var tagColor: Color? = nil
    var colorAction: (() -> Void)? = nil
    var badgeText: String? = nil
    var badgeColor: Color = CyberTheme.crimsonNeon

    var body: some View {
        HStack(spacing: 12) {
            // Icon Box
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        isOn ?
                        LinearGradient(colors: [activeColor, activeColor.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 38, height: 38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(isOn ? Color.white.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: isOn ? activeColor.opacity(0.5) : Color.clear, radius: 6, x: 0, y: 0)

                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isOn ? .white : Color(white: 0.65))
            }
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: isOn)

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)

                    if let badge = badgeText {
                        HStack(spacing: 3) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 7.5, weight: .bold))
                            Text(badge)
                                .font(.system(size: 8.5, weight: .black, design: .monospaced))
                        }
                        .foregroundColor(badgeColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(badgeColor.opacity(0.18))
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .strokeBorder(badgeColor.opacity(0.45), lineWidth: 0.8)
                        )
                    }

                    if let tColor = tagColor, isOn {
                        if let action = colorAction {
                            Button(action: action) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .fill(tColor)
                                        .frame(width: 22, height: 20)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .strokeBorder(Color.white.opacity(0.5), lineWidth: 1)
                                        )
                                        .shadow(color: tColor.opacity(0.8), radius: 4)

                                    Image(systemName: "paintpalette.fill")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(Color.white.opacity(0.9))
                                }
                            }
                            .buttonStyle(.plain)
                        } else {
                            Circle()
                                .fill(tColor)
                                .frame(width: 8, height: 8)
                                .shadow(color: tColor.opacity(0.8), radius: 3)
                        }
                    }
                }

                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(CyberTheme.textMuted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            // Custom 3D Toggle
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(CyberToggleStyle(activeColor: activeColor))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Cyber Slider (Matching the exact look with colored ring & white center dot)
struct CyberSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1.0
    var activeColor: Color = CyberTheme.crimsonNeon

    var body: some View {
        GeometryReader { geo in
            let availableWidth = max(geo.size.width - 24, 1)
            let clampedVal = min(max(value, range.lowerBound), range.upperBound)
            let fraction = CGFloat((clampedVal - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbX = 12 + fraction * availableWidth

            ZStack(alignment: .leading) {
                // Recessed 3D Track Groove
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(Color.black.opacity(0.70))
                    .frame(height: 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 12)

                // Glowing Active Fill
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [activeColor.opacity(0.85), activeColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, fraction * availableWidth), height: 5)
                    .padding(.leading, 12)
                    .shadow(color: activeColor.opacity(0.55), radius: 5)

                // Circular Thumb with colored ring and crisp white inner dot
                ZStack {
                    Circle()
                        .fill(activeColor)
                        .frame(width: 18, height: 18)
                        .overlay(
                            Circle().strokeBorder(Color.white.opacity(0.35), lineWidth: 0.8)
                        )
                        .shadow(color: activeColor.opacity(0.8), radius: 5)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 6.5, height: 6.5)
                }
                .position(x: thumbX, y: geo.size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        let dragX = max(0, min(gesture.location.x - 12, availableWidth))
                        let newFraction = Double(dragX / availableWidth)
                        let rawVal = range.lowerBound + newFraction * (range.upperBound - range.lowerBound)
                        let stepped = (rawVal / step).rounded() * step
                        value = min(max(stepped, range.lowerBound), range.upperBound)
                    }
            )
        }
        .frame(height: 26)
    }
}

// MARK: - Chamfered Futuristic Shape for Main Action Button
struct ChamferedCardShape: Shape {
    var cutSize: CGFloat = 14

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + cutSize, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cutSize, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cutSize))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cutSize))
        path.addLine(to: CGPoint(x: rect.maxX - cutSize, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cutSize, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cutSize))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cutSize))
        path.closeSubpath()
        return path
    }
}

// MARK: - Settings Information Row View
struct SettingsInfoRow: View {
    let icon: String
    let label: String
    let value: String
    var valueColor: Color = .white
    var isMonospaced: Bool = false
    var copyAction: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(CyberTheme.crimsonNeon)
                .frame(width: 20)

            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(CyberTheme.textSecondary)

            Spacer()

            Text(value)
                .font(.system(size: 13, weight: .semibold, design: isMonospaced ? .monospaced : .default))
                .foregroundColor(valueColor)
                .lineLimit(1)
                .truncationMode(.middle)

            if let copy = copyAction {
                Button(action: copy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(CyberTheme.crimsonNeon)
                        .padding(5)
                        .background(CyberTheme.crimsonNeon.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 3)
    }
}

// MARK: - RGB Interactive Canvas Component (Touch & Drag Spectrum)
struct RGBSpectrumCanvas: View {
    @Binding var curR: Double
    @Binding var curG: Double
    @Binding var curB: Double
    @State private var cursorLoc: CGPoint = CGPoint(x: 150, y: 65)
    @State private var hasInitialized: Bool = false

    var body: some View {
        GeometryReader { geo in
            let w = max(geo.size.width, 10)
            let h = max(geo.size.height, 10)

            ZStack {
                // 1. Horizontal Rainbow Hue Gradient
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1, green: 0, blue: 0),
                                Color(red: 1, green: 1, blue: 0),
                                Color(red: 0, green: 1, blue: 0),
                                Color(red: 0, green: 1, blue: 1),
                                Color(red: 0, green: 0, blue: 1),
                                Color(red: 1, green: 0, blue: 1),
                                Color(red: 1, green: 0, blue: 0)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                // 2. Vertical Shade Overlay (White at top, Clear at mid, Black at bottom)
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.85),
                                Color.white.opacity(0.0),
                                Color.black.opacity(0.90)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )

                // 3. Crisp Cyber Border
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)

                // 4. Draggable Ring Cursor
                Circle()
                    .strokeBorder(Color.white, lineWidth: 2.5)
                    .background(Circle().fill(Color(red: min(max(curR, 0), 255) / 255.0, green: min(max(curG, 0), 255) / 255.0, blue: min(max(curB, 0), 255) / 255.0)))
                    .frame(width: 26, height: 26)
                    .shadow(color: Color.black.opacity(0.8), radius: 5)
                    .position(cursorLoc)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { val in
                        let clampedX = min(max(val.location.x, 0), w)
                        let clampedY = min(max(val.location.y, 0), h)
                        cursorLoc = CGPoint(x: clampedX, y: clampedY)

                        let normX = Double(clampedX / w)
                        let normY = Double(clampedY / h)
                        let sat: CGFloat = normY < 0.5 ? CGFloat(normY * 2.0) : 1.0
                        let bri: CGFloat = normY < 0.5 ? 1.0 : CGFloat(1.0 - (normY - 0.5) * 1.8)
                        let uiColor = UIColor(hue: CGFloat(normX), saturation: max(sat, 0.05), brightness: max(bri, 0.05), alpha: 1.0)
                        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                        if uiColor.getRed(&r, green: &g, blue: &b, alpha: &a) {
                            curR = Double(r * 255.0)
                            curG = Double(g * 255.0)
                            curB = Double(b * 255.0)
                        }
                    }
            )
            .onAppear {
                if !hasInitialized {
                    hasInitialized = true
                    cursorLoc = CGPoint(x: w * 0.5, y: h * 0.5)
                }
            }
        }
        .frame(height: 135)
    }
}

// MARK: - ESP RGB Color Picker Popup
struct ESPColorPickerPopup: View {
    @ObservedObject var cheatState: CheatMenuState
    let target: ESPColorTarget
    @Environment(\.dismiss) private var dismiss

    @State private var curR: Double = 0
    @State private var curG: Double = 229
    @State private var curB: Double = 255
    @State private var curThickness: Double = 2.0

    var currentColor: Color {
        Color(
            red: min(max(curR, 0), 255) / 255.0,
            green: min(max(curG, 0), 255) / 255.0,
            blue: min(max(curB, 0), 255) / 255.0
        )
    }

    var hexString: String {
        let r = Int(min(max(curR, 0), 255))
        let g = Int(min(max(curG, 0), 255))
        let b = Int(min(max(curB, 0), 255))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    var body: some View {
        NavigationView {
            ZStack {
                CyberTheme.bgVoid
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // 1. Live Preview & Target Info Card
                        HStack(spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(currentColor)
                                    .frame(width: 56, height: 56)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.5)
                                    )
                                    .shadow(color: currentColor.opacity(0.85), radius: 10)

                                Image(systemName: target.icon)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundColor(curR + curG + curB > 450 ? .black : .white)
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text("MỤC ÁP DỤNG: \(target.title.uppercased())")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .foregroundColor(CyberTheme.cyberCyan)
                                    .tracking(1.0)

                                Text(hexString)
                                    .font(.system(size: 18, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)

                                Text("RGB(\(Int(curR)), \(Int(curG)), \(Int(curB))) • Dày \(String(format: "%.1f", curThickness)) px")
                                    .font(.system(size: 11.5, weight: .medium, design: .monospaced))
                                    .foregroundColor(CyberTheme.textMuted)
                            }

                            Spacer()
                        }
                        .padding(12)
                        .background(Color(red: 0.08, green: 0.08, blue: 0.11))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.1), lineWidth: 1)
                        )

                        // 2. Interactive 2D Color Spectrum Box (Drag / Tap)
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "hand.draw.fill")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(CyberTheme.cyberCyan)
                                Text("CHẠM HOẶC KÉO TỚI MÀU THÍCH")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .foregroundColor(CyberTheme.textMuted)
                                    .tracking(0.5)
                                Spacer()
                            }

                            RGBSpectrumCanvas(curR: $curR, curG: $curG, curB: $curB)
                        }

                        // 3. Individual RGB Channel Sliders
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(CyberTheme.mechaGold)
                                Text("TÙY CHỈNH THÔNG SỐ RGB (0 - 255)")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .foregroundColor(CyberTheme.textMuted)
                                    .tracking(0.5)
                                Spacer()
                            }

                            // R Slider
                            VStack(spacing: 3) {
                                HStack {
                                    Text("R (Đỏ)")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(red: 1.0, green: 0.25, blue: 0.3))
                                    Spacer()
                                    Text("\(Int(curR))")
                                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                        .foregroundColor(Color(red: 1.0, green: 0.25, blue: 0.3))
                                }
                                CyberSlider(value: $curR, range: 0...255, step: 1, activeColor: Color(red: 1.0, green: 0.2, blue: 0.3))
                            }

                            // G Slider
                            VStack(spacing: 3) {
                                HStack {
                                    Text("G (Xanh Lá)")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(red: 0.1, green: 0.9, blue: 0.4))
                                    Spacer()
                                    Text("\(Int(curG))")
                                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                        .foregroundColor(Color(red: 0.1, green: 0.9, blue: 0.4))
                                }
                                CyberSlider(value: $curG, range: 0...255, step: 1, activeColor: Color(red: 0.1, green: 0.9, blue: 0.4))
                            }

                            // B Slider
                            VStack(spacing: 3) {
                                HStack {
                                    Text("B (Xanh Dương)")
                                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                                        .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                                    Spacer()
                                    Text("\(Int(curB))")
                                        .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                        .foregroundColor(Color(red: 0.0, green: 0.8, blue: 1.0))
                                }
                                CyberSlider(value: $curB, range: 0...255, step: 1, activeColor: Color(red: 0.0, green: 0.8, blue: 1.0))
                            }
                        }
                        .padding(12)
                        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // 4. Quick Preset Colors
                        VStack(alignment: .leading, spacing: 8) {
                            Text("BẢNG MÀU CHỌN NHANH (PRESETS)")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundColor(CyberTheme.textMuted)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(cheatState.colorOptions) { opt in
                                        Button {
                                            let impact = UIImpactFeedbackGenerator(style: .light)
                                            impact.impactOccurred()
                                            let rgb = cheatState.getRGBForPresetId(opt.id)
                                            curR = rgb.0
                                            curG = rgb.1
                                            curB = rgb.2
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(opt.color)
                                                    .frame(width: 34, height: 34)
                                                    .overlay(
                                                        Circle().strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                                                    )
                                                    .shadow(color: opt.color.opacity(0.6), radius: 4)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        // 5. Thickness Slider for this specific ESP target
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "line.horizontal.3")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(CyberTheme.cyberCyan)
                                Text("ĐỘ DÀY NÉT VẼ CHO \(target.title.uppercased())")
                                    .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                    .foregroundColor(CyberTheme.textMuted)
                                    .tracking(0.5)
                                Spacer()
                                Text(String(format: "%.1f px", curThickness))
                                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                    .foregroundColor(currentColor)
                            }

                            CyberSlider(value: $curThickness, range: 1.0...8.0, step: 0.5, activeColor: currentColor)

                            // Quick thickness buttons
                            HStack(spacing: 6) {
                                ForEach([1.5, 2.0, 3.0, 5.0, 8.0], id: \.self) { th in
                                    let isSel = abs(curThickness - th) < 0.2
                                    Button {
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                        curThickness = th
                                    } label: {
                                        Text(String(format: "%.1f px", th))
                                            .font(.system(size: 10, weight: isSel ? .bold : .medium, design: .monospaced))
                                            .foregroundColor(isSel ? .white : CyberTheme.textMuted)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .fill(isSel ? currentColor.opacity(0.8) : Color.white.opacity(0.06))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                        }
                        .padding(12)
                        .background(Color(red: 0.07, green: 0.07, blue: 0.09))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                        // 6. Action Apply Button
                        Button {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            cheatState.setRGB(r: curR, g: curG, b: curB, for: target)
                            cheatState.setThickness(curThickness, for: target)
                            AppLog.shared.append("[ESP] Đã lưu màu \(target.title): \(hexString) (Dày \(String(format: "%.1f", curThickness))px)")
                            dismiss()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 15, weight: .bold))
                                Text("LƯU & ÁP DỤNG CHO \(target.title.uppercased())")
                                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                    .tracking(0.5)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [currentColor, currentColor.opacity(0.75)],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.4), lineWidth: 1)
                                    )
                                    .shadow(color: currentColor.opacity(0.6), radius: 8)
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 4)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                }
            }
            .navigationTitle("Tùy Biến: \(target.title)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        cheatState.setRGB(r: curR, g: curG, b: curB, for: target)
                        cheatState.setThickness(curThickness, for: target)
                        AppLog.shared.append("[ESP] Đã lưu màu \(target.title): \(hexString)")
                        dismiss()
                    }
                    .foregroundColor(CyberTheme.cyberCyan)
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            let rgb = cheatState.getRGB(for: target)
            curR = rgb.r
            curG = rgb.g
            curB = rgb.b
            curThickness = cheatState.getThickness(for: target)
        }
    }
}

// MARK: - Main ContentView
struct ContentView: View {
    @StateObject private var cheatState = CheatMenuState.shared
    @ObservedObject private var licenseStore = LicenseStore.shared
    @EnvironmentObject private var appState: AppState

    @State private var selectedTab: CheatTab = .aim
    @State private var isInjecting: Bool = false
    @State private var isInjected: Bool = FreeFirePatchService.isInjected()
    @State private var selectedTarget: FreeFireTarget = FreeFirePatchService.selectedTarget
    @State private var showInjectionAlert: Bool = false
    @State private var injectionAlertText: String = ""
    @State private var toastMessage: String? = nil
    @State private var showFullKey: Bool = false
    @State private var showLogModal: Bool = false
    @State private var selectedColorTarget: ESPColorTarget = .all
    @State private var showColorPickerPopup: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var isCleaningAntiban: Bool = false
    @State private var antibanProgress: Double = 0.0
    @AppStorage(AppLanguage.storageKey) private var languageCode: String = AppLanguage.vietnamese.rawValue

    private var isEnglish: Bool {
        languageCode == AppLanguage.english.rawValue
    }

    private var isLicenseValid: Bool {
        guard let key = licenseStore.savedKey, !key.isEmpty,
              let exp = licenseStore.expiresAt, exp > Date() else {
            return false
        }
        return true
    }

    var body: some View {
        ZStack {
            // 1. Deep Obsidian Base
            CyberTheme.bgVoid
                .ignoresSafeArea()

            // 2. High-Tech Cyber Wallpaper (Clamped & Clipped to screen bounds)
            Image("Background")
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipped()
                .ignoresSafeArea()
                .opacity(0.85)

            // 3. Subtle Ambient Crimson Smoke & Edge Glow
            VStack {
                HStack {
                    Spacer()
                    RadialGradient(
                        colors: [CyberTheme.crimsonNeon.opacity(0.18), Color.clear],
                        center: .topTrailing,
                        startRadius: 0,
                        endRadius: 280
                    )
                    .frame(width: 280, height: 280)
                    .blur(radius: 25)
                }
                Spacer()
                HStack {
                    RadialGradient(
                        colors: [CyberTheme.crimsonNeon.opacity(0.22), Color.clear],
                        center: .bottomLeading,
                        startRadius: 0,
                        endRadius: 300
                    )
                    .frame(width: 300, height: 300)
                    .blur(radius: 30)
                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .ignoresSafeArea()
            .allowsHitTesting(false)

            // Main Content Layout
            VStack(spacing: 0) {
                // Top Header Bar
                topHeaderBar

                // Segmented Tab Switcher [ AIM | ESP | MISC ]
                topTabBar
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                // Game Target Selector (Side-by-side cards)
                gameTargetSelector

                // Warning Banner if Key is Missing / Expired
                if !isLicenseValid {
                    HStack(spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.red)
                            .font(.system(size: 16))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(isEnglish ? "LICENSE NOT ACTIVATED" : "BẢN QUYỀN CHƯA KÍCH HOẠT")
                                .font(.system(size: 11.5, weight: .black, design: .monospaced))
                                .foregroundColor(.red)
                            Text(isEnglish ? "All features are locked. Please enter a valid License Key." : "Mọi tính năng đã bị khóa. Vui lòng nhập License Key hợp lệ.")
                                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                                .foregroundColor(Color.white.opacity(0.8))
                        }
                        Spacer()
                        Button {
                            showSettingsSheet = true
                        } label: {
                            Text(isEnglish ? "ACTIVATE" : "KÍCH HOẠT")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.red)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(10)
                    .background(Color.red.opacity(0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color.red.opacity(0.45), lineWidth: 1))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
                }

                // Tab Content Views (Bị khóa và làm mờ nếu không có key)
                Group {
                    switch selectedTab {
                    case .aim:
                        aimTabContent
                    case .esp:
                        espTabContent
                    case .misc:
                        miscTabContent
                    }
                }
                .disabled(!isLicenseValid)
                .opacity(isLicenseValid ? 1.0 : 0.45)
            }
            .frame(maxWidth: 414)
            .frame(maxWidth: .infinity, alignment: .center)

            // Floating Action HUD (Visible across all tabs - Bị khóa khi không có key)
            VStack {
                Spacer()
                bottomActionBar
                    .disabled(!isLicenseValid)
                    .opacity(isLicenseValid ? 1.0 : 0.45)
            }
            .frame(maxWidth: .infinity)
            .ignoresSafeArea(.keyboard, edges: .bottom)

            // Quick Toast Notification
            if let msg = toastMessage {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(CyberTheme.matrixGreen)
                        Text(msg)
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.1, green: 0.1, blue: 0.14).opacity(0.95))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                    .shadow(color: Color.black.opacity(0.6), radius: 8)
                    .padding(.bottom, 95)
                }
                .frame(maxWidth: .infinity)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .preferredColorScheme(.dark)
        .onAppear {
            isInjected = FreeFirePatchService.isInjected(target: selectedTarget)
        }
        .alert("INNOVA CHEAT Engine", isPresented: $showInjectionAlert) {
            Button("Đóng", role: .cancel) {}
        } message: {
            Text(injectionAlertText)
        }
        .sheet(isPresented: $showSettingsSheet) {
            settingsSheetView
        }
        .sheet(isPresented: $showLogModal) {
            LogTerminalModalView(isPresented: $showLogModal)
        }
    }

    // MARK: - Top Header Bar (INNOVA CHEAT + PRO VIP + READY)
    private var topHeaderBar: some View {
        HStack(spacing: 10) {
            // Glowing Crosshair Emblem
            ZStack {
                // Outer subtle glowing ring
                Circle()
                    .strokeBorder(CyberTheme.crimsonNeon.opacity(0.6), lineWidth: 1.5)
                    .frame(width: 38, height: 38)
                    .shadow(color: CyberTheme.crimsonNeon.opacity(0.8), radius: 6)

                // Inner gradient disc
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CyberTheme.crimsonNeon, CyberTheme.crimsonDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 30, height: 30)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.8)
                    )

                Image(systemName: "scope")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
            }
            .fixedSize()

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 0) {
                    Text("INNOVA ")
                        .font(.system(size: 17, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(1.0)

                    Text("CHEAT")
                        .font(.system(size: 17, weight: .heavy, design: .monospaced))
                        .foregroundColor(CyberTheme.crimsonNeon)
                        .tracking(1.0)
                        .shadow(color: CyberTheme.crimsonNeon.opacity(0.6), radius: 6)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)

                HStack(spacing: 5) {
                    // VIP Badge
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(CyberTheme.crimsonNeon)
                        Text("VIP PRO")
                            .font(.system(size: 8, weight: .heavy, design: .monospaced))
                            .foregroundColor(CyberTheme.crimsonNeon)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(CyberTheme.crimsonNeon.opacity(0.14))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(CyberTheme.crimsonNeon.opacity(0.3), lineWidth: 0.8))

                    Text("INTERNAL ENGINE • BYPASS")
                        .font(.system(size: 7.5, weight: .semibold, design: .monospaced))
                        .foregroundColor(CyberTheme.textMuted)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }

            Spacer(minLength: 4)

            // Dynamic Engine Badge (Kernel Exploit / MHA-C2)
            Button {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                if appState.kernelExploitApplicable && !appState.kernelExploitRunning && !appState.exploitStatus.isSuccess {
                    appState.runKernelExploitIfNeeded(force: true)
                    showToast("Đang kích hoạt Kernel Exploit...")
                } else if appState.exploitStatus.isSuccess {
                    showToast("Kernel Exploit: R/W Active")
                } else {
                    showToast("Chế độ: MHA-C2 Active")
                }
            } label: {
                HStack(spacing: 3.5) {
                    if appState.kernelExploitRunning {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: CyberTheme.mechaGold))
                            .scaleEffect(0.5)
                        Text("KEXP...")
                            .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .foregroundColor(CyberTheme.mechaGold)
                    } else if appState.exploitStatus.isSuccess {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(CyberTheme.matrixGreen)
                        Text("KEXPLOIT")
                            .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .foregroundColor(CyberTheme.matrixGreen)
                    } else {
                        Image(systemName: "shield.checkered")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundColor(CyberTheme.cyberCyan)
                        Text("MHA-C2")
                            .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .foregroundColor(CyberTheme.cyberCyan)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3.5)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
                .overlay(
                    Capsule().strokeBorder(
                        appState.kernelExploitRunning ? CyberTheme.mechaGold.opacity(0.5) :
                        (appState.exploitStatus.isSuccess ? CyberTheme.matrixGreen.opacity(0.5) : CyberTheme.cyberCyan.opacity(0.5)),
                        lineWidth: 0.8
                    )
                )
            }
            .buttonStyle(.plain)
            .fixedSize()

            // Status Indicator Dot & Badge
            HStack(spacing: 4) {
                Circle()
                    .fill(isInjected ? CyberTheme.matrixGreen : CyberTheme.matrixGreen)
                    .frame(width: 6, height: 6)
                    .shadow(color: CyberTheme.matrixGreen.opacity(0.85), radius: 4)

                Text(isInjected ? "INJECTED" : "READY")
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundColor(isInjected ? CyberTheme.matrixGreen : CyberTheme.matrixGreen)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: 0.8))
            .fixedSize()

            // Settings Gear Button (Opens Settings Sheet)
            Button {
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
                showSettingsSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 0.8))

                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(CyberTheme.cyberCyan)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
    }

    // MARK: - Top Tab Switcher [ AIM | ESP | MISC ]
    private var topTabBar: some View {
        HStack(spacing: 6) {
            ForEach(CheatTab.allCases, id: \.self) { tab in
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(selectedTab == tab ? .white : CyberTheme.textMuted)

                        Text(tab.title)
                            .font(.system(size: 13, weight: selectedTab == tab ? .heavy : .medium, design: .monospaced))
                            .foregroundColor(selectedTab == tab ? .white : CyberTheme.textMuted)
                            .tracking(1.0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        ZStack {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                CyberTheme.crimsonNeon.opacity(0.90),
                                                CyberTheme.crimsonDark
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.30), lineWidth: 1)
                                    )
                                    .shadow(color: CyberTheme.crimsonNeon.opacity(0.45), radius: 8)
                            } else {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color.white.opacity(0.04))
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Game Target Selector (Side-by-side Cards)
    private var gameTargetSelector: some View {
        HStack(spacing: 8) {
            ForEach(FreeFireTarget.allCases) { target in
                let isSelected = (selectedTarget == target)
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    selectedTarget = target
                    FreeFirePatchService.selectedTarget = target
                    isInjected = FreeFirePatchService.isInjected(target: target)
                } label: {
                    HStack(spacing: 8) {
                        // Flame badge
                        ZStack {
                            Circle()
                                .fill(
                                    isSelected ?
                                    LinearGradient(colors: [CyberTheme.crimsonNeon, CyberTheme.crimsonDark], startPoint: .topLeading, endPoint: .bottomTrailing) :
                                    LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                                .frame(width: 28, height: 28)
                                .shadow(color: isSelected ? CyberTheme.crimsonNeon.opacity(0.5) : Color.clear, radius: 4)

                            Image(systemName: "flame.fill")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(isSelected ? .white : Color(white: 0.55))
                        }
                        .fixedSize()

                        // Title & Subtitle
                        VStack(alignment: .leading, spacing: 2) {
                            Text(target.displayName)
                                .font(.system(size: 12.5, weight: .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)

                            Text(target == .freeFireTH ? (isEnglish ? "Main Edition" : "Bản chính") : (isEnglish ? "Max Edition" : "Bản tối ưu"))
                                .font(.system(size: 9.5, weight: .medium))
                                .foregroundColor(CyberTheme.textMuted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }

                        Spacer(minLength: 2)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(isSelected ? CyberTheme.crimsonNeon : CyberTheme.textMuted)
                            .fixedSize()
                    }
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(
                        ZStack {
                            if isSelected {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(red: 0.22, green: 0.04, blue: 0.07),
                                                Color(red: 0.10, green: 0.02, blue: 0.04)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(CyberTheme.crimsonNeon.opacity(0.85), lineWidth: 1)
                                    )
                                    .shadow(color: CyberTheme.crimsonNeon.opacity(0.30), radius: 6)
                            } else {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(red: 0.08, green: 0.08, blue: 0.10).opacity(0.85))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                    )
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 6)
    }

    // MARK: - AIM Tab Content
    private var aimTabContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // AIM PROTOCOL Section
                aimingSection

                // Extra Bottom Padding for floating HUD
                Spacer().frame(height: 120)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
    }

    // MARK: - ESP Tab Content
    private var espTabContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // ESP MATRIX Section
                espSection

                // Extra Bottom Padding for floating HUD
                Spacer().frame(height: 120)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
    }

    // MARK: - AIM PROTOCOL Section (With Neck & Head options when Aimbot is on)
    private var aimingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            CyberSectionHeader(
                title: "AIM PROTOCOL",
                subtitle: "Tự động khóa mục tiêu & giảm giật",
                icon: "scope",
                accentColor: CyberTheme.crimsonNeon
            )

            // Card 1: Aim Silent & Sliders (FOV & Headshot)
            CyberCard(glowColor: CyberTheme.crimsonNeon.opacity(cheatState.aimSilent ? 0.14 : 0.0)) {
                // Aim Silent Row
                CyberRowView(
                    iconName: "wind",
                    title: "Aim Silent (Tàng Hình)",
                    subtitle: "Khóa tâm ẩn, giảm giật màn hình",
                    isOn: $cheatState.aimSilent,
                    activeColor: CyberTheme.crimsonNeon
                )

                // Sub-controls (Silent FOV & Headshot Rate) — only when Aim Silent is enabled
                if cheatState.aimSilent {
                    VStack(spacing: 12) {
                        Divider().background(CyberTheme.divider)

                        // Nút Bật / Tắt Vòng FOV
                        CyberRowView(
                            iconName: "circle.circle",
                            title: "Vòng Tròn FOV (Hiện Vòng Quét)",
                            subtitle: "Bật / tắt vòng tròn ngắm trên màn hình",
                            isOn: $cheatState.drawFOV,
                            activeColor: CyberTheme.crimsonNeon
                        )

                        // Silent FOV
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(CyberTheme.crimsonNeon.opacity(0.18))
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "scope")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(CyberTheme.crimsonNeon)
                                }

                                Text("Vòng Quét (Silent FOV)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(CyberTheme.textSecondary)

                                Spacer()

                                Text("\(Int(cheatState.silentFOV)) px")
                                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                    .foregroundColor(CyberTheme.crimsonNeon)
                            }
                            CyberSlider(value: $cheatState.silentFOV, range: 20...500, step: 2, activeColor: CyberTheme.crimsonNeon)

                            // Quick FOV Presets
                            HStack(spacing: 6) {
                                ForEach([90, 140, 250, 360, 500], id: \.self) { preset in
                                    let isSelected = Int(cheatState.silentFOV) == preset
                                    Button {
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            cheatState.silentFOV = Double(preset)
                                        }
                                    } label: {
                                        Text(preset == 500 ? "500 (MAX)" : "\(preset)")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(isSelected ? .white : CyberTheme.textMuted)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .fill(isSelected ? CyberTheme.crimsonNeon.opacity(0.85) : Color.white.opacity(0.06))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                            .padding(.top, 2)
                        }

                        // Headshot Rate
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(CyberTheme.mechaGold.opacity(0.18))
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "target")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(CyberTheme.mechaGold)
                                }

                                Text("Tỉ Lệ Trúng Đầu (Headshot)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(CyberTheme.textSecondary)

                                Spacer()

                                Text("\(Int(cheatState.headshotRate))%")
                                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                    .foregroundColor(CyberTheme.mechaGold)
                            }
                            CyberSlider(value: $cheatState.headshotRate, range: 0...100, step: 1, activeColor: CyberTheme.mechaGold)
                        }
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 2)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: cheatState.aimSilent)

            // Card 2: Aim Bot (Mặc định: Head)
            CyberCard(glowColor: cheatState.aimBot ? CyberTheme.crimsonNeon.opacity(0.12) : Color.clear) {
                // Aim Bot Row
                CyberRowView(
                    iconName: "target",
                    title: "Aim Bot (Tự Động)",
                    subtitle: "Hút tâm trực tiếp vào đầu đối thủ (Headshot)",
                    isOn: $cheatState.aimBot,
                    activeColor: CyberTheme.crimsonNeon
                )

                // FOV options (Shown when Aimbot is turned ON)
                if cheatState.aimBot {
                    VStack(alignment: .leading, spacing: 6) {
                        // Nút Bật / Tắt Vòng FOV cho Aimbot
                        CyberRowView(
                            iconName: "circle.circle",
                            title: "Vòng Tròn FOV (Hiện Vòng Quét)",
                            subtitle: "Bật / tắt vòng tròn ngắm trên màn hình",
                            isOn: $cheatState.drawFOV,
                            activeColor: CyberTheme.crimsonNeon
                        )

                        // FOV Slider cho Aimbot
                        VStack(spacing: 4) {
                            HStack(spacing: 8) {
                                ZStack {
                                    Circle()
                                        .fill(CyberTheme.crimsonNeon.opacity(0.18))
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "scope")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(CyberTheme.crimsonNeon)
                                }

                                Text("Vòng Quét (Aimbot FOV)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(CyberTheme.textSecondary)

                                Spacer()

                                Text("\(Int(cheatState.silentFOV)) px")
                                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                    .foregroundColor(CyberTheme.crimsonNeon)
                            }
                            CyberSlider(value: $cheatState.silentFOV, range: 20...500, step: 2, activeColor: CyberTheme.crimsonNeon)

                            // Quick FOV Presets
                            HStack(spacing: 6) {
                                ForEach([90, 140, 250, 360, 500], id: \.self) { preset in
                                    let isSelected = Int(cheatState.silentFOV) == preset
                                    Button {
                                        let impact = UIImpactFeedbackGenerator(style: .light)
                                        impact.impactOccurred()
                                        withAnimation(.easeInOut(duration: 0.15)) {
                                            cheatState.silentFOV = Double(preset)
                                        }
                                    } label: {
                                        Text(preset == 500 ? "500 (MAX)" : "\(preset)")
                                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                                            .foregroundColor(isSelected ? .white : CyberTheme.textMuted)
                                            .padding(.horizontal, 7)
                                            .padding(.vertical, 4)
                                            .background(
                                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                    .fill(isSelected ? CyberTheme.crimsonNeon.opacity(0.85) : Color.white.opacity(0.06))
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                                Spacer()
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .animation(.spring(response: 0.28, dampingFraction: 0.8), value: cheatState.aimBot)

            // Card 3: Vòng Tròn FOV (Hiện khi chưa bật Aim hoặc muốn cấu hình trước)
            if !cheatState.aimSilent && !cheatState.aimBot {
                CyberCard(glowColor: cheatState.drawFOV ? CyberTheme.crimsonNeon.opacity(0.12) : Color.clear) {
                    CyberRowView(
                        iconName: "circle.circle",
                        title: "Vòng Tròn FOV (Hiện Vòng Quét)",
                        subtitle: "Bật / tắt vòng tròn ngắm trên màn hình",
                        isOn: $cheatState.drawFOV,
                        activeColor: CyberTheme.crimsonNeon
                    )
                }
            }

            // Card 4: Nút Bật Antiban (Dọn dẹp file Documents & Telemetry Library)
            CyberCard(glowColor: CyberTheme.matrixGreen.opacity(0.18)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(CyberTheme.matrixGreen.opacity(0.18))
                                .frame(width: 22, height: 22)
                            Image(systemName: "shield.checkerboard")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(CyberTheme.matrixGreen)
                        }

                        Text("HỆ THỐNG ANTIBAN")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)

                        Spacer()

                        Text("V1 SAFE")
                            .font(.system(size: 9, weight: .heavy, design: .monospaced))
                            .foregroundColor(CyberTheme.matrixGreen)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(CyberTheme.matrixGreen.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    Text("Kích hoạt antiban trước sau đó mới inject cheat.")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(CyberTheme.textMuted)
                        .lineSpacing(2)

                    Button {
                        handleRunAntiban()
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: isCleaningAntiban ? "arrow.triangle.2.circlepath" : "shield.fill")
                                .font(.system(size: 14, weight: .bold))
                                .rotationEffect(.degrees(isCleaningAntiban ? 360 : 0))

                            VStack(alignment: .leading, spacing: 1.5) {
                                Text(isCleaningAntiban ? "ĐANG KÍCH HOẠT ANTIBAN... \(Int(antibanProgress * 100))%" : "BẬT ANTIBAN ( V1 )")
                                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                                    .tracking(0.5)

                                Text(isCleaningAntiban ? "Đang kích hoạt" : "Nhấn để kích hoạt antiban v1")
                                    .font(.system(size: 9.5, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.85))
                            }

                            Spacer()

                            if isCleaningAntiban {
                                Text("\(Int(antibanProgress * 100))%")
                                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                            } else {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(
                            LinearGradient(
                                colors: [
                                    CyberTheme.matrixGreen,
                                    Color(red: 0.02, green: 0.45, blue: 0.32)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: CyberTheme.matrixGreen.opacity(0.45), radius: 6)
                    }
                    .buttonStyle(.plain)
                    .disabled(isCleaningAntiban)

                    // Thanh ngang chạy tiến trình từ 0 tới 100%
                    if isCleaningAntiban || antibanProgress > 0 {
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(CyberTheme.matrixGreen)
                                        .frame(width: 5, height: 5)
                                    Text("TIẾN TRÌNH ANTIBAN:")
                                        .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                                        .foregroundColor(CyberTheme.matrixGreen)
                                }
                                Spacer()
                                Text("\(Int(antibanProgress * 100))%")
                                    .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                            }

                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 8)

                                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [CyberTheme.matrixGreen, CyberTheme.cyberCyan],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                        .frame(width: max(0, min(geo.size.width * CGFloat(antibanProgress), geo.size.width)), height: 8)
                                        .shadow(color: CyberTheme.matrixGreen.opacity(0.85), radius: 5)
                                }
                            }
                            .frame(height: 8)
                        }
                        .padding(.top, 2)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
            }
        }
    }

    // MARK: - ESP MATRIX Section (RGB Customizer & Thickness per Element)
    private var espSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            CyberSectionHeader(
                title: "ESP MATRIX SYSTEM",
                subtitle: "Nhìn xuyên tường, định vị vị trí đối thủ",
                icon: "eye.fill",
                accentColor: CyberTheme.cyberCyan
            )

            // Card 1: Main ESP Features (Box, Line, Thanh Máu, Name, Khoảng Cách)
            CyberCard(glowColor: CyberTheme.cyberCyan.opacity(0.12)) {
                // Box ESP (With active color badge & direct popup trigger)
                CyberRowView(
                    iconName: "shippingbox.fill",
                    title: "Khung 2D (Box ESP)",
                    subtitle: "Hộp nhận diện bao quanh đối thủ",
                    isOn: $cheatState.boxESP,
                    activeColor: cheatState.getColor(for: .box),
                    tagColor: cheatState.getColor(for: .box),
                    colorAction: {
                        selectedColorTarget = .box
                        showColorPickerPopup = true
                    }
                )

                Divider().background(CyberTheme.divider)

                // Line ESP (With active color badge & direct popup trigger)
                CyberRowView(
                    iconName: "line.diagonal",
                    title: "Tia Chỉ Hướng (Line ESP)",
                    subtitle: "Tia định vị từ đỉnh màn hình xuống địch",
                    isOn: $cheatState.lineESP,
                    activeColor: cheatState.getColor(for: .line),
                    tagColor: cheatState.getColor(for: .line),
                    colorAction: {
                        selectedColorTarget = .line
                        showColorPickerPopup = true
                    }
                )

                Divider().background(CyberTheme.divider)

                // Health Bar
                CyberRowView(
                    iconName: "cross.case.fill",
                    title: "Thanh Máu (Health Bar)",
                    subtitle: "Hiển thị lượng máu đối thủ",
                    isOn: $cheatState.healthBar,
                    activeColor: cheatState.getColor(for: .health),
                    tagColor: cheatState.getColor(for: .health),
                    colorAction: {
                        selectedColorTarget = .health
                        showColorPickerPopup = true
                    }
                )

                Divider().background(CyberTheme.divider)

                // Name Tag
                CyberRowView(
                    iconName: "tag.fill",
                    title: "Tên Kẻ Địch (Name Tag)",
                    subtitle: "Nhận diện nickname của mục tiêu",
                    isOn: $cheatState.nameTag,
                    activeColor: cheatState.getColor(for: .tag),
                    tagColor: cheatState.getColor(for: .tag),
                    colorAction: {
                        selectedColorTarget = .tag
                        showColorPickerPopup = true
                    }
                )

                Divider().background(CyberTheme.divider)

                // Distance Tag
                CyberRowView(
                    iconName: "ruler.fill",
                    title: "Khoảng Cách (Distance Tag)",
                    subtitle: "Đo cự ly chính xác theo mét",
                    isOn: $cheatState.distanceTag,
                    activeColor: cheatState.getColor(for: .tag),
                    tagColor: cheatState.getColor(for: .tag),
                    colorAction: {
                        selectedColorTarget = .tag
                        showColorPickerPopup = true
                    }
                )

                Divider().background(CyberTheme.divider)

                // Viền Đỏ Nhân Vật (Chams Outline)
                CyberRowView(
                    iconName: "person.crop.rectangle.stack.fill",
                    title: "VIỀN ĐỎ NHÂN VẬT (Chams)",
                    subtitle: "Shader viền đỏ phát sáng xuyên tường 500m mượt mà trên GPU",
                    isOn: $cheatState.chamsOutline,
                    activeColor: CyberTheme.crimsonNeon,
                    badgeText: "CHAMS",
                    badgeColor: CyberTheme.crimsonNeon
                )
            }

            // Card 2: Dedicated RGB Color & Thickness Customizer per ESP Type
            let currentTargetColor = cheatState.getColor(for: selectedColorTarget)
            let currentTargetThickness = cheatState.getThickness(for: selectedColorTarget)

            CyberCard(glowColor: currentTargetColor.opacity(0.18)) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(CyberTheme.cyberCyan)

                        Text("BẢNG MÀU RGB & ĐỘ DÀY ESP")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(1.0)

                        Spacer()

                        Text("TÙY CHỈNH TỪNG MỤC")
                            .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberTheme.cyberCyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(CyberTheme.cyberCyan.opacity(0.12))
                            .clipShape(Capsule())
                    }

                    // 1. Selector Option: Chọn loại ESP để chỉnh màu
                    VStack(alignment: .leading, spacing: 6) {
                        Text("CHỌN LOẠI ESP ĐỂ THIẾT LẬP:")
                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                            .foregroundColor(CyberTheme.textMuted)
                            .tracking(0.5)

                        HStack(spacing: 5) {
                            ForEach(ESPColorTarget.allCases) { target in
                                let isSelected = (selectedColorTarget == target)
                                let targetColor = cheatState.getColor(for: target)

                                Button {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                        selectedColorTarget = target
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(targetColor)
                                            .frame(width: 7, height: 7)
                                            .shadow(color: targetColor.opacity(0.9), radius: 2)

                                        Text(target.shortTitle)
                                            .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                    }
                                    .foregroundColor(isSelected ? .white : Color(white: 0.7))
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 32)
                                    .background(
                                        ZStack {
                                            if isSelected {
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(Color(white: 0.16))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                            .strokeBorder(targetColor.opacity(0.9), lineWidth: 1.2)
                                                    )
                                                    .shadow(color: targetColor.opacity(0.35), radius: 5)
                                            } else {
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(Color.white.opacity(0.04))
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 2. Bảng màu bên cạnh nhấn vào sẽ hiện popup bảng màu RGB (kéo hoặc nhấn chọn màu)
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .medium)
                        impact.impactOccurred()
                        showColorPickerPopup = true
                    } label: {
                        HStack(spacing: 12) {
                            // Left: Target Icon Badge
                            ZStack {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(currentTargetColor.opacity(0.18))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(currentTargetColor.opacity(0.7), lineWidth: 1)
                                    )

                                Image(systemName: selectedColorTarget.icon)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(currentTargetColor)
                            }

                            // Middle: Target Title & Hex / RGB
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(selectedColorTarget.title)
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundColor(.white)

                                    Text(cheatState.getHex(for: selectedColorTarget))
                                        .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                        .foregroundColor(currentTargetColor)
                                }

                                let rgb = cheatState.getRGB(for: selectedColorTarget)
                                Text("RGB(\(Int(rgb.r)), \(Int(rgb.g)), \(Int(rgb.b))) • Dày \(String(format: "%.1f", currentTargetThickness)) px")
                                    .font(.system(size: 10.5, weight: .medium, design: .monospaced))
                                    .foregroundColor(CyberTheme.textMuted)
                            }

                            Spacer()

                            // Right: Bảng màu bên cạnh nhấn vào sẽ hiện popup
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(currentTargetColor)
                                    .frame(width: 26, height: 26)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.7), lineWidth: 1)
                                    )
                                    .shadow(color: currentTargetColor.opacity(0.8), radius: 5)

                                VStack(alignment: .trailing, spacing: 1) {
                                    HStack(spacing: 3) {
                                        Text("BẢNG MÀU")
                                            .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .foregroundColor(CyberTheme.cyberCyan)

                                    Text("RGB Popup")
                                        .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                                        .foregroundColor(CyberTheme.textMuted)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.06))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(CyberTheme.cyberCyan.opacity(0.3), lineWidth: 0.8)
                            )
                        }
                        .padding(10)
                        .background(Color.black.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(currentTargetColor.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)

                    Divider().background(CyberTheme.divider)

                    // 3. Tùy chỉnh độ dày riêng cho từng loại ESP
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "line.horizontal.3")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(CyberTheme.cyberCyan)

                            Text("ĐỘ DÀY NÉT VẼ CHO \(selectedColorTarget.title.uppercased())")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundColor(CyberTheme.textSecondary)

                            Spacer()

                            Text(String(format: "%.1f px", currentTargetThickness))
                                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                .foregroundColor(currentTargetColor)
                        }

                        CyberSlider(
                            value: Binding<Double>(
                                get: { cheatState.getThickness(for: selectedColorTarget) },
                                set: { cheatState.setThickness($0, for: selectedColorTarget) }
                            ),
                            range: 1.0...8.0,
                            step: 0.5,
                            activeColor: currentTargetColor
                        )

                        // Quick preset thickness pills
                        HStack(spacing: 6) {
                            ForEach([1.5, 2.0, 3.0, 5.0, 8.0], id: \.self) { th in
                                let isSel = abs(currentTargetThickness - th) < 0.2
                                Button {
                                    let impact = UIImpactFeedbackGenerator(style: .light)
                                    impact.impactOccurred()
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.8)) {
                                        cheatState.setThickness(th, for: selectedColorTarget)
                                    }
                                } label: {
                                    Text(String(format: "%.1f px", th))
                                        .font(.system(size: 10, weight: isSel ? .bold : .medium, design: .monospaced))
                                        .foregroundColor(isSel ? .white : CyberTheme.textMuted)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(isSel ? currentTargetColor.opacity(0.85) : Color.white.opacity(0.06))
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                            Spacer()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showColorPickerPopup) {
            ESPColorPickerPopup(
                cheatState: cheatState,
                target: selectedColorTarget
            )
        }
    }

    // MARK: - COMBAT MODS Section (Buff Damage, Fast Fire, No Recoil, Fast Medkit)
    private var combatSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            CyberSectionHeader(
                title: "COMBAT & WEAPON MODS",
                subtitle: "Tối ưu hóa vũ khí & gia tăng sát thương",
                icon: "shield.righthalf.filled",
                accentColor: CyberTheme.crimsonFlame
            )

            CyberCard(glowColor: (cheatState.buffDamage || cheatState.fastFire || cheatState.fastSwap || cheatState.fastReload || cheatState.noRecoil || cheatState.fastMedkit || cheatState.spinBot) ? CyberTheme.crimsonFlame.opacity(0.12) : Color.clear) {
                // Buff Dame
                CyberRowView(
                    iconName: "flame.fill",
                    title: "Tăng Sát Thương (Buff Dame)",
                    subtitle: "Cường hóa chỉ số dame khi bắn trúng",
                    isOn: $cheatState.buffDamage,
                    activeColor: CyberTheme.crimsonNeon
                )

                Divider().background(CyberTheme.divider)

                // Fast Fire
                CyberRowView(
                    iconName: "bolt.fill",
                    title: "Bắn Siêu Tốc (Fast Fire)",
                    subtitle: "Tăng tốc độ nhả đạn của súng liên thanh",
                    isOn: $cheatState.fastFire,
                    activeColor: CyberTheme.mechaGold
                )

                Divider().background(CyberTheme.divider)

                // Đổi Súng Nhanh (Fast Weapon Swap)
                CyberRowView(
                    iconName: "arrow.triangle.swap",
                    title: "ĐỔI SÚNG NHANH",
                    subtitle: "Triệt tiêu 0s delay đổi súng, bắn liên tục không khựng (Shotgun & Sniper)",
                    isOn: $cheatState.fastSwap,
                    activeColor: CyberTheme.crimsonFlame,
                    badgeText: "0s DELAY",
                    badgeColor: CyberTheme.crimsonFlame
                )

                /*
                Divider().background(CyberTheme.divider)

                // Nạp Đạn Nhanh (Fast Reload)
                CyberRowView(
                    iconName: "bolt.badge.clock.fill",
                    title: "NẠP ĐẠN NHANH",
                    subtitle: "Rút ngắn thời gian nạp đạn xuống 0.05s, vừa nạp vừa bắn không bị khóa cò",
                    isOn: $cheatState.fastReload,
                    activeColor: CyberTheme.crimsonFlame,
                    badgeText: "0.05s RELOAD",
                    badgeColor: CyberTheme.crimsonFlame
                )
                */

                Divider().background(CyberTheme.divider)

                // SPIN BOT (Spinbot 360° + Slider Tốc Độ Xoay)
                VStack(alignment: .leading, spacing: 8) {
                    CyberRowView(
                        iconName: "tornado",
                        title: "SPIN BOT (360°)",
                        subtitle: "Xoay tròn nhân vật 360° liên tục làm rối hitbox, né đạn & chống kéo tâm",
                        isOn: $cheatState.spinBot,
                        activeColor: CyberTheme.mechaGold,
                        badgeText: "\(Int(cheatState.spinSpeed))°/s",
                        badgeColor: CyberTheme.mechaGold
                    )

                    if cheatState.spinBot {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("TỐC ĐỘ XOAY 360°:")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(CyberTheme.textMuted)
                                Spacer()
                                Text("\(Int(cheatState.spinSpeed))°/giây (\(String(format: "%.1f", cheatState.spinSpeed / 360.0)) vòng/s)")
                                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                                    .foregroundColor(CyberTheme.mechaGold)
                            }

                            CyberSlider(
                                value: $cheatState.spinSpeed,
                                range: 180...3600,
                                step: 60,
                                activeColor: CyberTheme.mechaGold
                            )
                        }
                        .padding(.horizontal, 10)
                        .padding(.bottom, 4)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }

                Divider().background(CyberTheme.divider)

                // Đạn Thẳng (No Recoil) - Cảnh báo nguy hiểm & Lỗi dame
                VStack(spacing: 6) {
                    CyberRowView(
                        iconName: "scope",
                        title: "Đạn Thẳng (No Recoil 0%)",
                        subtitle: "Khử rung lắc nòng súng, đạn bay thẳng tắp",
                        isOn: $cheatState.noRecoil,
                        activeColor: CyberTheme.crimsonNeon,
                        badgeText: "DỄ LỖI DAME",
                        badgeColor: CyberTheme.crimsonNeon
                    )

                    // Cảnh báo nguy hiểm & Lỗi dame
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(CyberTheme.crimsonNeon)
                            .shadow(color: CyberTheme.crimsonNeon.opacity(0.8), radius: 5)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Text("CẢNH BÁO NGUY HIỂM:")
                                    .font(.system(size: 10.5, weight: .black, design: .monospaced))
                                    .foregroundColor(CyberTheme.crimsonNeon)
                                Text("NGUY CƠ LỖI DAME")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(CyberTheme.crimsonNeon.opacity(0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))

                                Spacer(minLength: 0)

                                if cheatState.noRecoil {
                                    Text("ĐANG BẬT")
                                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(CyberTheme.crimsonNeon)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                            }

                            Text("Bật Đạn Thẳng can thiệp triệt tiêu độ tỏa đạn. Máy chủ có thể từ chối tính sát thương khi xả đạn liên tục dẫn tới SÁT THƯƠNG ẢO / LỖI DAME (bắn trúng địch nhưng không mất máu). Khuyên dùng cẩn trọng!")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(Color(white: 0.86))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                cheatState.noRecoil ?
                                CyberTheme.crimsonNeon.opacity(0.18) :
                                CyberTheme.crimsonNeon.opacity(0.08)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                cheatState.noRecoil ?
                                CyberTheme.crimsonNeon.opacity(0.7) :
                                CyberTheme.crimsonNeon.opacity(0.28),
                                lineWidth: 1
                            )
                    )
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: cheatState.noRecoil)
                }

                Divider().background(CyberTheme.divider)

                // Fast Medkit
                CyberRowView(
                    iconName: "cross.case.fill",
                    title: "Bơm Máu Siêu Tốc (Fast Medkit)",
                    subtitle: "Tăng tốc độ hồi phục sinh lực tức thì",
                    isOn: $cheatState.fastMedkit,
                    activeColor: CyberTheme.matrixGreen
                )
            }
        }
    }

    // MARK: - SURVIVAL & MOVEMENT Section (Cam Xa + Slider, Speed Run, Nhảy Dù Siêu Tốc)
    private var movementSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            CyberSectionHeader(
                title: "SURVIVAL & MOVEMENT",
                subtitle: "Góc nhìn bao quát & di chuyển thần tốc",
                icon: "figure.run",
                accentColor: CyberTheme.cyberCyan
            )

            CyberCard(glowColor: (cheatState.wideView || cheatState.speedRun || cheatState.fastParachute || cheatState.backJump || cheatState.highJump || cheatState.fastRotation || cheatState.noGrass || cheatState.noFog || cheatState.fastLoot || cheatState.fastCrouch || cheatState.superEmote || cheatState.unlockFps) ? CyberTheme.cyberCyan.opacity(0.12) : Color.clear) {
                // Cam Xa (Wide View) Row
                CyberRowView(
                    iconName: "camera.viewfinder",
                    title: "Góc Nhìn Rộng (Cam Xa)",
                    subtitle: "Mở rộng góc quan sát toàn cảnh chiến trường",
                    isOn: $cheatState.wideView,
                    activeColor: CyberTheme.cyberCyan
                )

                // Horizontal Slider for Cam Xa (FOV / Distance from 60° to 120°)
                if cheatState.wideView {
                    VStack(spacing: 5) {
                        HStack(spacing: 8) {
                            ZStack {
                                Circle()
                                    .fill(CyberTheme.cyberCyan.opacity(0.18))
                                    .frame(width: 22, height: 22)
                                Image(systemName: "viewfinder")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(CyberTheme.cyberCyan)
                            }

                            Text("Khoảng Cách Cam (FOV)")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(CyberTheme.textSecondary)

                            Spacer()

                            Text("\(Int(cheatState.camDistance))°")
                                .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                .foregroundColor(CyberTheme.cyberCyan)
                        }

                        CyberSlider(
                            value: $cheatState.camDistance,
                            range: 60...120,
                            step: 1,
                            activeColor: CyberTheme.cyberCyan
                        )
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider().background(CyberTheme.divider)

                // Chạy Nhanh (Speed Run) - Cảnh báo nguy hiểm & Lỗi dame
                VStack(spacing: 6) {
                    CyberRowView(
                        iconName: "figure.run",
                        title: "Chạy Nhanh (Speed Run)",
                        subtitle: "Di chuyển thần tốc, né đạn & lướt nhanh",
                        isOn: $cheatState.speedRun,
                        activeColor: CyberTheme.matrixGreen,
                        badgeText: "DỄ LỖI DAME",
                        badgeColor: CyberTheme.mechaGold
                    )

                    // Cảnh báo nguy hiểm & Lỗi dame
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(CyberTheme.mechaGold)
                            .shadow(color: CyberTheme.mechaGold.opacity(0.8), radius: 5)
                            .padding(.top, 1)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 5) {
                                Text("CẢNH BÁO NGUY HIỂM:")
                                    .font(.system(size: 10.5, weight: .black, design: .monospaced))
                                    .foregroundColor(CyberTheme.mechaGold)
                                Text("LỖI DAME / LỆCH SERVER")
                                    .font(.system(size: 9.5, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(CyberTheme.mechaGold.opacity(0.4))
                                    .clipShape(RoundedRectangle(cornerRadius: 3))

                                Spacer(minLength: 0)

                                if cheatState.speedRun {
                                    Text("ĐANG BẬT")
                                        .font(.system(size: 8.5, weight: .black, design: .monospaced))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(CyberTheme.mechaGold)
                                        .clipShape(RoundedRectangle(cornerRadius: 3))
                                }
                            }

                            Text("Tốc độ di chuyển quá cao gây lệch tọa độ giữa máy bạn và server game (Desync). Khi vừa chạy vừa xả đạn, server có thể TỪ CHỐI TÍNH SÁT THƯƠNG khiến đạn bắn trúng địch nhưng không mất máu. Khuyên dùng cẩn trọng!")
                                .font(.system(size: 10.5, weight: .medium))
                                .foregroundColor(Color(white: 0.86))
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                cheatState.speedRun ?
                                CyberTheme.mechaGold.opacity(0.18) :
                                CyberTheme.mechaGold.opacity(0.08)
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                cheatState.speedRun ?
                                CyberTheme.mechaGold.opacity(0.7) :
                                CyberTheme.mechaGold.opacity(0.28),
                                lineWidth: 1
                            )
                    )
                    .animation(.spring(response: 0.25, dampingFraction: 0.7), value: cheatState.speedRun)
                }

                Divider().background(CyberTheme.divider)

                // Fast Parachute
                CyberRowView(
                    iconName: "wind",
                    title: "Nhảy Dù Siêu Tốc (Fast Parachute)",
                    subtitle: "Rơi tự do và tiếp đất cực nhanh",
                    isOn: $cheatState.fastParachute,
                    activeColor: CyberTheme.mechaGold
                )

                Divider().background(CyberTheme.divider)

                // BACKJUMP (Khử Gia Tốc Rơi / Nhảy Lùi)
                CyberRowView(
                    iconName: "arrow.uturn.backward.circle.fill",
                    title: "BACKJUMP",
                    subtitle: "Khử gia tốc rơi, nhảy giật lùi né đạn & đổi súng trên không",
                    isOn: $cheatState.backJump,
                    activeColor: CyberTheme.cyberCyan
                )

                Divider().background(CyberTheme.divider)

                // Nhảy Cao (High Jump)
                CyberRowView(
                    iconName: "arrow.up.circle.fill",
                    title: "NHẢY CAO (High Jump)",
                    subtitle: "Bật nhảy 1.2x vượt tường keo, leo nóc nhà & vượt chướng ngại vật",
                    isOn: $cheatState.highJump,
                    activeColor: CyberTheme.matrixGreen,
                    badgeText: "1.2X",
                    badgeColor: CyberTheme.matrixGreen
                )

                Divider().background(CyberTheme.divider)

                // Đảo Như PC (Fast Rotation 360°)
                CyberRowView(
                    iconName: "arrow.triangle.2.circlepath",
                    title: "ĐẢO NHƯ PC (360°)",
                    subtitle: "Quay đầu tức thì 9999°/s không quán tính, xoay mượt như chuột PC",
                    isOn: $cheatState.fastRotation,
                    activeColor: CyberTheme.mechaGold,
                    badgeText: "9999°",
                    badgeColor: CyberTheme.mechaGold
                )

                /*
                Divider().background(CyberTheme.divider)

                // Khử Cỏ 100% (No Grass)
                CyberRowView(
                    iconName: "leaf.fill",
                    title: "KHỬ CỎ 100% (No Grass)",
                    subtitle: "Làm phẳng 0m mọi bụi cỏ cao & vừa trên toàn bản đồ, khắc chế nằm bo",
                    isOn: $cheatState.noGrass,
                    activeColor: CyberTheme.matrixGreen,
                    badgeText: "NO GRASS",
                    badgeColor: CyberTheme.matrixGreen
                )

                Divider().background(CyberTheme.divider)

                // Khử Sương Mù (No Fog)
                CyberRowView(
                    iconName: "sun.haze.fill",
                    title: "KHỬ SƯƠNG MÙ (No Fog)",
                    subtitle: "Xóa sạch sương mù che chắn, mở rộng tầm nhìn xa 1000m cực đại",
                    isOn: $cheatState.noFog,
                    activeColor: CyberTheme.cyberCyan,
                    badgeText: "1000M",
                    badgeColor: CyberTheme.cyberCyan
                )

                Divider().background(CyberTheme.divider)

                // Loot Đồ Nhanh (Fast Loot / Auto Pickup)
                CyberRowView(
                    iconName: "hand.grab.fill",
                    title: "LOOT ĐỒ NHANH",
                    subtitle: "Tối ưu hóa bộ nhớ đệm nhặt đồ, chạy lướt qua hút sạch trang bị",
                    isOn: $cheatState.fastLoot,
                    activeColor: CyberTheme.mechaGold,
                    badgeText: "AUTO LOOT",
                    badgeColor: CyberTheme.mechaGold
                )

                Divider().background(CyberTheme.divider)

                // Ngồi Di Chuyển Nhanh (Fast Crouch Run)
                CyberRowView(
                    iconName: "figure.walk",
                    title: "NGỒI DI CHUYỂN NHANH",
                    subtitle: "Di chuyển tốc độ tối đa ở tư thế ngồi, thu nhỏ hitbox né đạn",
                    isOn: $cheatState.fastCrouch,
                    activeColor: CyberTheme.cyberCyan,
                    badgeText: "FAST CROUCH",
                    badgeColor: CyberTheme.cyberCyan
                )

                Divider().background(CyberTheme.divider)

                // Điệu Nhảy Booyah (Super Emote)
                CyberRowView(
                    iconName: "figure.dance",
                    title: "ĐIỆU NHẢY BOOYAH",
                    subtitle: "Kích hoạt nhảy Booyah & Carnival Dance liên tục trong trận đấu",
                    isOn: $cheatState.superEmote,
                    activeColor: CyberTheme.crimsonNeon,
                    badgeText: "BOOYAH DANCE",
                    badgeColor: CyberTheme.crimsonNeon
                )

                Divider().background(CyberTheme.divider)

                // Mở Khóa 120 / 144 FPS (Ultra Smooth)
                CyberRowView(
                    iconName: "speedometer",
                    title: "MỞ KHÓA 120 / 144 FPS",
                    subtitle: "Mở khóa tần số quét cực hạn, hình ảnh siêu mượt và giảm giật lag cảm ứng",
                    isOn: $cheatState.unlockFps,
                    activeColor: CyberTheme.mechaGold,
                    badgeText: "144 FPS MAX",
                    badgeColor: CyberTheme.mechaGold
                )
                */
            }
        }
    }

    // MARK: - Floating Futuristic Action HUD (Bottom Bar)
    private var bottomActionBar: some View {
        VStack(spacing: 4) {
            // Quick Language Selector Row (Above inject button, right-aligned over lightning button)
            HStack {
                Spacer()
                languageSelectorButton
            }
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                // Main Inject Button (Chamfered Futuristic Angle)
                Button {
                    if isInjected {
                        handleUninjectCheat()
                    } else {
                        handleInjectCheat()
                    }
                } label: {
                    HStack(spacing: 12) {
                        // Flame icon badge
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.20))
                                .frame(width: 34, height: 34)

                            Image(systemName: isInjected ? "trash.fill" : "flame.fill")
                                .font(.system(size: 16, weight: .heavy))
                                .foregroundColor(.white)
                        }
                        .fixedSize()

                        // Label
                        VStack(alignment: .leading, spacing: 2) {
                            if isInjecting {
                                Text(isInjected ? (isEnglish ? "UNINJECTING..." : "ĐANG GỠ BỎ...") : (isEnglish ? "INJECTING..." : "ĐANG INJECT..."))
                                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                            } else {
                                Text(isInjected ? "UNINJECT (\(selectedTarget.displayName.uppercased()))" : "INJECT (\(selectedTarget.displayName.uppercased()))")
                                    .font(.system(size: 13.5, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                                    .tracking(0.5)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                Text(isInjected ? (isEnglish ? "Tap to revert all cheat features" : "Nhấn để hủy kích hoạt chức năng") : (isEnglish ? "Tap to activate all cheat features" : "Bắt đầu kích hoạt chức năng"))
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.85))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                        }

                        Spacer(minLength: 4)
                    }
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(
                        ZStack {
                            if isInjected {
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.85, green: 0.15, blue: 0.22),
                                        Color(red: 0.55, green: 0.08, blue: 0.12)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            } else {
                                LinearGradient(
                                    colors: [
                                        CyberTheme.matrixGreen,
                                        Color(red: 0.02, green: 0.45, blue: 0.32)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }
                        }
                    )
                    .clipShape(ChamferedCardShape(cutSize: 12))
                    .overlay(
                        ChamferedCardShape(cutSize: 12)
                            .stroke(Color.white.opacity(0.35), lineWidth: 1)
                    )
                    .shadow(color: (isInjected ? Color.red : CyberTheme.matrixGreen).opacity(0.65), radius: 12, y: 3)
                }
                .buttonStyle(.plain)
                .disabled(isInjecting)

                // Secondary Quick Action Circular Button (Lightning Bolt)
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .rigid)
                    impact.impactOccurred()
                    if !isInjected {
                        handleInjectCheat()
                    } else {
                        handleResetDefaults()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(white: 0.18),
                                        Color(white: 0.09)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 50, height: 50)
                            .overlay(
                                Circle().strokeBorder(Color.white.opacity(0.18), lineWidth: 1)
                            )
                            .shadow(color: Color.black.opacity(0.6), radius: 6)

                        Image(systemName: "bolt.fill")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // Sleek Footer with Red Neon Lines
            HStack(spacing: 12) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [Color.clear, CyberTheme.crimsonNeon.opacity(0.6)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                Text("INNOVA CHEAT")
                    .font(.system(size: 9.5, weight: .heavy, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.45))
                    .tracking(2.0)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [CyberTheme.crimsonNeon.opacity(0.6), Color.clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.top, 4)
            .padding(.bottom, 6)
        }
        .frame(maxWidth: 414)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            LinearGradient(
                colors: [
                    CyberTheme.bgVoid.opacity(0.0),
                    CyberTheme.bgVoid.opacity(0.92),
                    CyberTheme.bgVoid
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Language Selector Quick Action
    private var languageSelectorButton: some View {
        Menu {
            ForEach(AppLanguage.selectableCases) { option in
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .medium)
                    impact.impactOccurred()
                    languageCode = option.rawValue
                } label: {
                    HStack {
                        Text("\(option.flag) \(option.displayName)")
                        if languageCode == option.rawValue {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(white: 0.20),
                                    Color(white: 0.10)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle().strokeBorder(CyberTheme.cyberCyan.opacity(0.65), lineWidth: 1)
                        )
                        .shadow(color: CyberTheme.cyberCyan.opacity(0.35), radius: 4)

                    Image(systemName: "globe")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(CyberTheme.cyberCyan)
                }

                Text("Language")
                    .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                    .foregroundColor(Color.white.opacity(0.85))
                    .shadow(color: Color.black.opacity(0.8), radius: 2)
            }
            .frame(width: 50)
        }
        .buttonStyle(.plain)
    }

    // MARK: - MISC Tab Content (Combat & Movement Hacks Only)
    private var miscTabContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // 1. COMBAT MODS (Buff Damage, Fast Fire, No Recoil, Fast Medkit)
                combatSection

                // 2. SURVIVAL & MOVEMENT (Cam Xa + Slider, Speed Run, Fast Parachute)
                movementSection

                // Extra Bottom Padding for floating HUD
                Spacer().frame(height: 120)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
        }
    }

    // MARK: - Dedicated Settings Sheet View
    private var settingsSheetView: some View {
        NavigationView {
            ZStack {
                CyberTheme.bgVoid
                    .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 18) {
                        // 1. GIẤY PHÉP & BẢN QUYỀN
                        licenseSettingsCard

                        // 2. TIỆN ÍCH & NHẬT KÝ
                        utilitiesCard

                        // 3. THÔNG TIN ỨNG DỤNG
                        appCoreCard

                        // 4. THÔNG TIN THIẾT BỊ
                        deviceHardwareCard

                        // 5. KHẢ NĂNG HỖ TRỢ & HỆ THỐNG
                        systemCompatibilityCard

                        Spacer().frame(height: 40)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                }

                if let msg = toastMessage {
                    VStack {
                        Spacer()
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(CyberTheme.matrixGreen)
                            Text(msg)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundColor(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(red: 0.1, green: 0.1, blue: 0.14).opacity(0.95))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.18), lineWidth: 1))
                        .shadow(color: Color.black.opacity(0.6), radius: 8)
                        .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(100)
                }
            }
            .navigationTitle("Cài Đặt Hệ Thống")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Đóng") {
                        showSettingsSheet = false
                    }
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(CyberTheme.cyberCyan)
                }
            }
            .sheet(isPresented: $showLogModal) {
                LogTerminalModalView(isPresented: $showLogModal)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - App Core Card
    private var appCoreCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            CyberSectionHeader(
                title: "THÔNG TIN ỨNG DỤNG",
                subtitle: "Phiên bản & Lõi hệ thống",
                icon: "shield.lefthalf.filled",
                accentColor: CyberTheme.crimsonNeon
            )

            CyberCard(glowColor: CyberTheme.crimsonNeon.opacity(0.10)) {
                SettingsInfoRow(icon: "app.badge.fill", label: "Tên Ứng Dụng", value: "INNOVA CHEAT", valueColor: CyberTheme.crimsonNeon)
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(icon: "number.circle.fill", label: "Phiên Bản Core", value: "v1.0.0", isMonospaced: true)
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(icon: "cpu.fill", label: "Kiến Trúc Binary", value: "ARM64e • iOS Metal", isMonospaced: true)
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(icon: "gamecontroller.fill", label: "Đối Tượng Hỗ Trợ", value: "FF & FF MAX")
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(icon: "bolt.horizontal.fill", label: "Patch Engine", value: "IFix Dynamic Bytecode", valueColor: CyberTheme.matrixGreen)
            }
        }
    }

    // MARK: - License Settings Card
    private var licenseSettingsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            CyberSectionHeader(
                title: "GIẤY PHÉP & BẢN QUYỀN",
                subtitle: "Trạng thái key & Thời hạn sử dụng",
                icon: "key.fill",
                accentColor: CyberTheme.mechaGold
            )

            CyberCard(glowColor: CyberTheme.mechaGold.opacity(0.10)) {
                // Key Display & Copy Action
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("KEY ĐANG SỬ DỤNG")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberTheme.textMuted)

                        Text(showFullKey ? (licenseStore.savedKey ?? "Chưa có key") : maskedKeyText(licenseStore.savedKey))
                            .font(.system(size: 13.5, weight: .bold, design: .monospaced))
                            .foregroundColor(.white)
                            .lineLimit(1)
                    }

                    Spacer()

                    // Toggle Visibility Button
                    Button {
                        showFullKey.toggle()
                    } label: {
                        Image(systemName: showFullKey ? "eye.slash.fill" : "eye.fill")
                            .font(.system(size: 13))
                            .foregroundColor(CyberTheme.textMuted)
                            .padding(6)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)

                    // Copy Key Button
                    Button {
                        if let key = licenseStore.savedKey, !key.isEmpty {
                            UIPasteboard.general.string = key
                            showToast("Đã sao chép License Key!")
                        }
                    } label: {
                        Image(systemName: "doc.on.doc.fill")
                            .font(.system(size: 13))
                            .foregroundColor(CyberTheme.mechaGold)
                            .padding(6)
                            .background(CyberTheme.mechaGold.opacity(0.15))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }

                Divider().background(CyberTheme.divider)

                // Remaining Time Big Highlight
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("THỜI GIAN CÒN LẠI")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(CyberTheme.textMuted)

                        Text(remainingTimeText(licenseStore.expiresAt))
                            .font(.system(size: 16, weight: .heavy, design: .monospaced))
                            .foregroundColor(isLicenseValid ? CyberTheme.matrixGreen : Color.red)
                    }

                    Spacer()

                    // VIP Status Pill (Dynamic)
                    if isLicenseValid {
                        HStack(spacing: 5) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 12))
                                .foregroundColor(CyberTheme.matrixGreen)
                            Text("VIP ACTIVE")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundColor(CyberTheme.matrixGreen)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(CyberTheme.matrixGreen.opacity(0.12))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(CyberTheme.matrixGreen.opacity(0.3), lineWidth: 1))
                    } else {
                        HStack(spacing: 5) {
                            Image(systemName: "xmark.octagon.fill")
                                .font(.system(size: 12))
                                .foregroundColor(Color.red)
                            Text("CHƯA KÍCH HOẠT")
                                .font(.system(size: 11, weight: .heavy, design: .monospaced))
                                .foregroundColor(Color.red)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.red.opacity(0.15))
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.red.opacity(0.4), lineWidth: 1))
                    }
                }

                Divider().background(CyberTheme.divider)

                SettingsInfoRow(
                    icon: "calendar.badge.clock",
                    label: "Ngày Hết Hạn",
                    value: formattedDate(licenseStore.expiresAt),
                    isMonospaced: true
                )

                Divider().background(CyberTheme.divider)

                // Change Key Action Button
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .rigid)
                    impact.impactOccurred()
                    LicenseStore.shared.clear()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 13, weight: .bold))
                        Text("Đổi Mã Key Khác")
                            .font(.system(size: 13, weight: .bold))
                    }
                    .foregroundColor(Color.red.opacity(0.9))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.red.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Color.red.opacity(0.25), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
    }

    // MARK: - Device Hardware Card
    private var deviceHardwareCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            CyberSectionHeader(
                title: "THÔNG TIN THIẾT BỊ",
                subtitle: "Phần cứng & Định danh máy",
                icon: "iphone.gen3",
                accentColor: CyberTheme.cyberCyan
            )

            CyberCard(glowColor: CyberTheme.cyberCyan.opacity(0.10)) {
                SettingsInfoRow(
                    icon: "tag.fill",
                    label: "Tên Thiết Bị",
                    value: UIDevice.current.name
                )
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(
                    icon: "iphone",
                    label: "Dòng Máy",
                    value: AppInfo.hardwareDisplayName,
                    valueColor: CyberTheme.cyberCyan
                )
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(
                    icon: "cube.fill",
                    label: "Mã Model",
                    value: AppInfo.displayMachineName,
                    isMonospaced: true
                )
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(
                    icon: "gearshape.fill",
                    label: "Hệ Điều Hành",
                    value: "iOS \(AppInfo.osVersion) (\(AppInfo.osBuild))",
                    isMonospaced: true
                )
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(
                    icon: "barcode.viewfinder",
                    label: "Device Serial",
                    value: maskedKeyText(DeviceIdentity.serial()),
                    isMonospaced: true,
                    copyAction: {
                        UIPasteboard.general.string = DeviceIdentity.serial()
                        showToast("Đã sao chép Serial thiết bị!")
                    }
                )
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(
                    icon: "hand.tap.fill",
                    label: "Cử Chỉ Điều Hướng",
                    value: AppInfo.isHomeButton ? "Phím Home Cổ Điển" : "Face ID / Vuốt Màn Hình"
                )
            }
        }
    }

    // MARK: - System Compatibility Card
    private var systemCompatibilityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            CyberSectionHeader(
                title: "KHẢ NĂNG HỖ TRỢ & HỆ THỐNG",
                subtitle: "Tương thích Kernel Exploit & Game",
                icon: "checkmark.shield.fill",
                accentColor: CyberTheme.matrixGreen
            )

            CyberCard(glowColor: CyberTheme.matrixGreen.opacity(0.10)) {
                // Compatibility Banner
                HStack(spacing: 10) {
                    Image(systemName: isDeviceSupported ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(isDeviceSupported ? CyberTheme.matrixGreen : CyberTheme.mechaGold)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isDeviceSupported ? "ĐƯỢC HỖ TRỢ HOÀN TOÀN" : "HỖ TRỢ GIỚI HẠN")
                            .font(.system(size: 13.5, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                        Text(isDeviceSupported ? "Thiết bị tương thích 100% injection & bypass" : "Phiên bản iOS có thể cần thêm offset")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(CyberTheme.textMuted)
                    }
                    Spacer()
                }
                .padding(10)
                .background((isDeviceSupported ? CyberTheme.matrixGreen : CyberTheme.mechaGold).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                Divider().background(CyberTheme.divider)

                SettingsInfoRow(
                    icon: "lock.open.trianglebadge.exclamationmark.fill",
                    label: "Kernel Exploit",
                    value: kernelExploitStatusTitle,
                    valueColor: kernelExploitStatusColor,
                    copyAction: (appState.kernelExploitApplicable && !appState.kernelExploitRunning && !appState.exploitStatus.isSuccess) ? {
                        appState.runKernelExploitIfNeeded(force: true)
                        showToast("Bắt đầu chạy Kernel Exploit...")
                    } : nil
                )
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(
                    icon: "shield.checkered",
                    label: "MHA-C2 Engine",
                    value: "🟢 MobileHouseArrest Active",
                    valueColor: CyberTheme.matrixGreen
                )
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(
                    icon: "folder.badge.gearshape",
                    label: "Cơ Chế Can Thiệp",
                    value: appState.exploitStatus.isSuccess ? "Bundle + Data Sandbox Escape" : "MHA-C2 Documents Injection",
                    valueColor: CyberTheme.cyberCyan
                )
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(
                    icon: "cross.case.fill",
                    label: "Free Fire Thường",
                    value: isGameInstalled(.freeFireTH) ? "Đã Cài Đặt (Sẵn sàng)" : "Chưa Tìm Thấy",
                    valueColor: isGameInstalled(.freeFireTH) ? CyberTheme.matrixGreen : CyberTheme.textMuted
                )
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(
                    icon: "flame.fill",
                    label: "Free Fire MAX",
                    value: isGameInstalled(.freeFireMAX) ? "Đã Cài Đặt (Sẵn sàng)" : "Chưa Tìm Thấy",
                    valueColor: isGameInstalled(.freeFireMAX) ? CyberTheme.matrixGreen : CyberTheme.textMuted
                )
            }
        }
    }

    // MARK: - Utilities & Log Terminal Action Card
    private var utilitiesCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            CyberSectionHeader(
                title: "TIỆN ÍCH & NHẬT KÝ",
                subtitle: "Bảo trì & Xem console logs",
                icon: "terminal.fill",
                accentColor: CyberTheme.electricPurple
            )

            CyberCard(glowColor: CyberTheme.electricPurple.opacity(0.10)) {
                // View Console Logs Button (Isolated observer: does not trigger ContentView redraw)
                ConsoleLogSummaryRow(showLogModal: $showLogModal)

                Divider().background(CyberTheme.divider)

                // Reset Menu Settings Button
                Button(action: handleResetDefaults) {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.counterclockwise.circle.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(CyberTheme.mechaGold)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Khôi Phục Cài Đặt Menu Mặc Định")
                                .font(.system(size: 13.5, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Đưa toàn bộ thông số Aim & ESP về ban đầu")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundColor(CyberTheme.textMuted)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Actions
    private func handleInjectCheat() {
        guard !isInjecting else { return }

        // Block if Kernel Exploit is actively executing to avoid race condition/crash
        if appState.kernelExploitRunning {
            injectionAlertText = "⏳ Hệ thống đang chạy Kernel Exploit ngầm, vui lòng đợi giây lát rồi thử lại..."
            showInjectionAlert = true
            return
        }

        // Auto trigger Kernel Exploit if applicable and not yet tried
        if appState.kernelExploitApplicable && !appState.exploitStatus.isSuccess && !appState.exploitStatus.isFailed {
            appState.runKernelExploitIfNeeded()
            injectionAlertText = "⚡ Đang kích hoạt quyền hệ thống (Kernel Exploit). Vui lòng thử lại sau vài giây..."
            showInjectionAlert = true
            return
        }

        isInjecting = true
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        AppLog.shared.append("[CHEAT] Bắt đầu nạp module cheat vào \(selectedTarget.displayName)...")

        Task {
            do {
                try await FreeFirePatchService.inject(target: selectedTarget)
                await MainActor.run {
                    self.isInjecting = false
                    self.isInjected = true
                    let notif = UINotificationFeedbackGenerator()
                    notif.notificationOccurred(.success)
                    self.showToast("⚡ Đã Inject thành công! Đang mở \(self.selectedTarget.displayName)...")
                    FreeFirePatchService.launchGame(target: self.selectedTarget)
                }
            } catch {
                await MainActor.run {
                    self.isInjecting = false
                    let notif = UINotificationFeedbackGenerator()
                    notif.notificationOccurred(.error)
                    self.injectionAlertText = "❌ Lỗi Inject:\n\(error.localizedDescription)"
                    self.showInjectionAlert = true
                }
            }
        }
    }

    private func handleUninjectCheat() {
        guard !isInjecting else { return }
        isInjecting = true
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        AppLog.shared.append("[CHEAT] Bắt đầu gỡ bỏ module cheat khỏi \(selectedTarget.displayName)...")

        FreeFirePatchService.uninject(target: selectedTarget)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.isInjecting = false
            self.isInjected = false
            let notif = UINotificationFeedbackGenerator()
            notif.notificationOccurred(.success)
            self.injectionAlertText = "🗑️ Đã Uninject thành công."
            self.showInjectionAlert = true
        }
    }

    private func handleRunAntiban() {
        guard !isCleaningAntiban else { return }
        isCleaningAntiban = true
        antibanProgress = 0.0
        let impact = UIImpactFeedbackGenerator(style: .heavy)
        impact.impactOccurred()

        // Thực hiện xóa ngầm dữ liệu disk (không ghi log)
        DispatchQueue.global(qos: .userInitiated).async {
            _ = FreeFirePatchService.cleanAntibanAndTelemetry(target: self.selectedTarget)
        }

        // Chạy thanh ngang tiến trình mượt mà từ 0% tới 100% (~1.1 giây)
        let totalSteps = 24
        let interval = 0.045
        var currentStep = 0

        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            currentStep += 1
            let progress = min(1.0, Double(currentStep) / Double(totalSteps))
            withAnimation(.easeInOut(duration: interval)) {
                self.antibanProgress = progress
            }

            if currentStep >= totalSteps {
                timer.invalidate()
                let notif = UINotificationFeedbackGenerator()
                notif.notificationOccurred(.success)
                self.showToast("🛡️ Antiban: Đã bật thành công")

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation {
                        self.isCleaningAntiban = false
                        self.antibanProgress = 0.0
                    }
                }
            }
        }
    }

    private func handleResetDefaults() {
        let impact = UIImpactFeedbackGenerator(style: .rigid)
        impact.impactOccurred()
        cheatState.resetToDefaults()
        showToast("Đã khôi phục cài đặt mặc định!")
    }

    private func showToast(_ message: String) {
        withAnimation { toastMessage = message }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation { toastMessage = nil }
        }
    }

    private func isGameInstalled(_ target: FreeFireTarget) -> Bool {
        return ContainerStore.resolveAppContainerPath(bundleID: target.rawValue) != nil
    }

    private var isDeviceSupported: Bool {
        let v = AppInfo.versionTuple
        return ExploitSupportPolicy.isSupported(
            major: v.major,
            minor: v.minor,
            patch: v.patch,
            build: AppInfo.osBuild
        )
    }

    private var kernelExploitStatusTitle: String {
        if appState.kernelExploitRunning {
            return "Đang chạy ngầm..."
        } else if appState.exploitStatus.isSuccess {
            return "⚡ Hoạt Động (Kernel R/W)"
        } else if case .failed = appState.exploitStatus {
            return "Thất bại (-1) → Đã chuyển MHA-C2"
        } else if appState.kernelExploitApplicable {
            return "Chưa kích hoạt (Nhấn để chạy)"
        } else {
            return "Không áp dụng (Dùng MHA-C2)"
        }
    }

    private var kernelExploitStatusColor: Color {
        if appState.kernelExploitRunning {
            return CyberTheme.mechaGold
        } else if appState.exploitStatus.isSuccess {
            return CyberTheme.matrixGreen
        } else if case .failed = appState.exploitStatus {
            return CyberTheme.cyberCyan
        } else if appState.kernelExploitApplicable {
            return CyberTheme.mechaGold
        } else {
            return CyberTheme.textMuted
        }
    }

    private func logColor(for text: String) -> Color {
        if text.contains("[CHEAT]") || text.contains("Inject") {
            return CyberTheme.matrixGreen
        } else if text.contains("[AIM]") {
            return CyberTheme.cyberCyan
        } else if text.contains("[ESP]") {
            return CyberTheme.mechaGold
        } else if text.contains("[COMBAT]") {
            return CyberTheme.crimsonNeon
        } else if text.contains("Lỗi") || text.contains("failed") || text.contains("error") {
            return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
        return Color(white: 0.82)
    }

    private func maskedKeyText(_ raw: String?) -> String {
        guard let key = raw, !key.isEmpty else { return "Chưa có key" }
        if key.count <= 8 { return key }
        let start = key.prefix(4)
        let end = key.suffix(4)
        return "\(start)-****-****-\(end)"
    }

    private func remainingTimeText(_ date: Date?) -> String {
        guard let key = licenseStore.savedKey, !key.isEmpty, let date = date else {
            return "Chưa có key (Chưa kích hoạt)"
        }
        let diff = date.timeIntervalSince(Date())
        if diff <= 0 { return "Đã Hết Hạn" }
        let days = Int(diff) / 86400
        let hours = (Int(diff) % 86400) / 3600
        let minutes = (Int(diff) % 3600) / 60
        if days > 0 {
            return "\(days) ngày \(hours) giờ"
        } else if hours > 0 {
            return "\(hours) giờ \(minutes) phút"
        } else {
            let seconds = Int(diff) % 60
            return "\(minutes) phút \(seconds)s"
        }
    }

    private func formattedDate(_ date: Date?) -> String {
        guard let key = licenseStore.savedKey, !key.isEmpty, let date = date else {
            return "Chưa có bản quyền"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy • HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Dedicated Console Log Summary Row (Isolates @ObservedObject to prevent root ContentView redraws)
struct ConsoleLogSummaryRow: View {
    @ObservedObject private var appLog = AppLog.shared
    @Binding var showLogModal: Bool

    var body: some View {
        Button {
            showLogModal = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(CyberTheme.electricPurple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Xem Nhật Ký Hoạt Động (Console Logs)")
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(.white)
                    Text("\(appLog.entries.count) dòng log hệ thống")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundColor(CyberTheme.textMuted)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(CyberTheme.textMuted)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Log Terminal Modal View (High performance, bounded list with deduplication)
struct LogTerminalModalView: View {
    @Binding var isPresented: Bool
    @ObservedObject private var appLog = AppLog.shared
    @State private var toastMessage: String? = nil

    private func logColor(for text: String) -> Color {
        if text.contains("❌") || text.contains("Lỗi") || text.contains("failed") || text.contains("error") {
            return Color(red: 1.0, green: 0.35, blue: 0.35)
        } else if text.contains("✅") || text.contains("ENABLED") || text.contains("[+]") || text.contains("[CHEAT]") {
            return CyberTheme.matrixGreen
        } else if text.contains("🔒") || text.contains("[CONFIG]") {
            return CyberTheme.mechaGold
        } else if text.contains("[AIM]") {
            return CyberTheme.crimsonNeon
        } else if text.contains("[ESP]") {
            return CyberTheme.cyberCyan
        }
        return Color(white: 0.85)
    }

    var body: some View {
        NavigationView {
            ZStack {
                CyberTheme.bgVoid
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    // Header Bar
                    HStack {
                        HStack(spacing: 6) {
                            Circle()
                                .fill(CyberTheme.matrixGreen)
                                .frame(width: 8, height: 8)
                            Text("SYSTEM CONSOLE (\(appLog.entries.count))")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        // Copy All Logs
                        Button {
                            let text = appLog.entries.joined(separator: "\n")
                            UIPasteboard.general.string = text
                            toastMessage = "Đã sao chép toàn bộ logs!"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                                toastMessage = nil
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.doc")
                                    .font(.system(size: 11))
                                Text("Copy")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Capsule())
                        }

                        // Clear Logs
                        Button {
                            appLog.clear()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "trash")
                                    .font(.system(size: 11))
                                Text("Clear")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundColor(Color.red.opacity(0.85))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.red.opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    // Scrollable Terminal Console
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 5) {
                                if appLog.entries.isEmpty {
                                    VStack(spacing: 8) {
                                        Image(systemName: "terminal")
                                            .font(.system(size: 32))
                                            .foregroundColor(Color.white.opacity(0.2))
                                        Text("Chưa có log hệ thống")
                                            .font(.system(size: 13, design: .monospaced))
                                            .foregroundColor(CyberTheme.textMuted)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.top, 60)
                                } else {
                                    ForEach(Array(appLog.entries.enumerated()), id: \.offset) { idx, entry in
                                        Text(entry)
                                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                                            .foregroundColor(logColor(for: entry))
                                            .textSelection(.enabled)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .id(idx)
                                    }
                                }
                            }
                            .padding(14)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(Color(red: 0.04, green: 0.04, blue: 0.05))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                    }
                }

                if let toast = toastMessage {
                    VStack {
                        Spacer()
                        Text(toast)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.85))
                            .clipShape(Capsule())
                            .padding(.bottom, 24)
                    }
                    .transition(.opacity)
                }
            }
            .navigationTitle("Console Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        isPresented = false
                    }
                    .foregroundColor(CyberTheme.crimsonNeon)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

