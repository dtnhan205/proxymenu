import SwiftUI
import UIKit

// MARK: - Cheat Tab Enum (Menu & Settings)
enum CheatTab: Int, CaseIterable {
    case menu = 0
    case settings = 1

    var title: String {
        switch self {
        case .menu: return "MENU"
        case .settings: return "SETTINGS"
        }
    }

    var icon: String {
        switch self {
        case .menu: return "house.fill"
        case .settings: return "gearshape.fill"
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

// MARK: - ESP Color Target (Toàn bộ hoặc từng bộ phận)
enum ESPColorTarget: Int, CaseIterable, Identifiable {
    case all = 0
    case box = 1
    case line = 2
    case skeleton = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .all: return "Tất Cả"
        case .box: return "Khung Box"
        case .line: return "Tia Line"
        case .skeleton: return "Khung Xương"
        }
    }

    var icon: String {
        switch self {
        case .all: return "paintpalette.fill"
        case .box: return "shippingbox.fill"
        case .line: return "line.diagonal"
        case .skeleton: return "figure.stand"
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
        if FreeFirePatchService.isInjected() {
            FreeFirePatchService.syncConfig(state: self)
        }
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
            AppLog.shared.append("[COMBAT] No Recoil: \(noRecoil ? "ENABLED" : "DISABLED")")
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
            syncIfInjected()
        }
    }
    @Published var fastParachute: Bool {
        didSet {
            UserDefaults.standard.set(fastParachute, forKey: "cheat.fastParachute")
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

    func getColorId(for target: ESPColorTarget) -> Int {
        switch target {
        case .all: return espSelectedColorId
        case .box: return boxColorId
        case .line: return lineColorId
        case .skeleton: return skeletonColorId
        }
    }

    func setColorId(_ id: Int, for target: ESPColorTarget) {
        switch target {
        case .all:
            espSelectedColorId = id
            boxColorId = id
            lineColorId = id
            skeletonColorId = id
            AppLog.shared.append("[ESP] Đổi màu toàn bộ: \(getColor(for: id).name)")
        case .box:
            boxColorId = id
            AppLog.shared.append("[ESP] Đổi màu Khung Box: \(getColor(for: id).name)")
        case .line:
            lineColorId = id
            AppLog.shared.append("[ESP] Đổi màu Tia Line: \(getColor(for: id).name)")
        case .skeleton:
            skeletonColorId = id
            AppLog.shared.append("[ESP] Đổi màu Khung Xương: \(getColor(for: id).name)")
        }
    }

    init() {
        let ud = UserDefaults.standard
        self.aimSilent = ud.object(forKey: "cheat.aimSilent") as? Bool ?? false
        self.silentFOV = ud.object(forKey: "cheat.silentFOV") as? Double ?? 180.0
        self.headshotRate = ud.object(forKey: "cheat.headshotRate") as? Double ?? 100.0
        self.aimBot = ud.object(forKey: "cheat.aimBot") as? Bool ?? false
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

        self.fastMedkit = ud.object(forKey: "cheat.fastMedkit") as? Bool ?? false
        self.noRecoil = ud.object(forKey: "cheat.noRecoil") as? Bool ?? false
        self.buffDamage = ud.object(forKey: "cheat.buffDamage") as? Bool ?? false
        self.fastFire = ud.object(forKey: "cheat.fastFire") as? Bool ?? false
        self.wideView = ud.object(forKey: "cheat.wideView") as? Bool ?? false
        self.camDistance = ud.object(forKey: "cheat.camDistance") as? Double ?? 85.0
        self.speedRun = ud.object(forKey: "cheat.speedRun") as? Bool ?? false
        self.fastParachute = ud.object(forKey: "cheat.fastParachute") as? Bool ?? false
    }

    func resetToDefaults() {
        aimSilent = false
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
        espAlert = false
        espColorEnabled = true
        espSelectedColorId = 1
        boxColorId = 1
        lineColorId = 1
        skeletonColorId = 5
        espLineThickness = 2.5

        fastMedkit = false
        noRecoil = false
        buffDamage = false
        fastFire = false
        wideView = false
        camDistance = 85.0
        speedRun = false
        fastParachute = false

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
        .padding(15)
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

                    if let tColor = tagColor, isOn {
                        Circle()
                            .fill(tColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: tColor.opacity(0.8), radius: 3)
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

// MARK: - ESP Color Picker Popup (7 Preset Colors)
struct ESPColorPickerPopup: View {
    @ObservedObject var cheatState: CheatMenuState
    let target: ESPColorTarget
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                CyberTheme.bgVoid
                    .ignoresSafeArea()

                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        Image(systemName: target.icon)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(CyberTheme.cyberCyan)
                        Text("Chọn Màu Cho: \(target.title)")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
                        ForEach(cheatState.colorOptions) { option in
                            let isPicked = (cheatState.getColorId(for: target) == option.id)

                            Button {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                                    cheatState.setColorId(option.id, for: target)
                                }
                                dismiss()
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: [option.color, option.color.opacity(0.8)],
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                            .frame(width: 48, height: 48)
                                            .overlay(
                                                Circle()
                                                    .strokeBorder(isPicked ? Color.white : Color.white.opacity(0.2), lineWidth: isPicked ? 2.5 : 1)
                                            )
                                            .shadow(color: option.color.opacity(isPicked ? 0.8 : 0.25), radius: isPicked ? 8 : 2)

                                        if isPicked {
                                            Image(systemName: "checkmark")
                                                .font(.system(size: 16, weight: .heavy))
                                                .foregroundColor(.white)
                                                .shadow(color: Color.black.opacity(0.6), radius: 2)
                                        }
                                    }

                                    Text(option.name)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(isPicked ? .white : CyberTheme.textMuted)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.7)
                                        .multilineTextAlignment(.center)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)

                    Spacer()
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Xong") {
                        dismiss()
                    }
                    .foregroundColor(CyberTheme.cyberCyan)
                    .fontWeight(.semibold)
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

// MARK: - Main ContentView
struct ContentView: View {
    @StateObject private var cheatState = CheatMenuState.shared
    @ObservedObject private var licenseStore = LicenseStore.shared
    @ObservedObject private var appLog = AppLog.shared

    @State private var selectedTab: CheatTab = .menu
    @State private var isInjecting: Bool = false
    @State private var isInjected: Bool = FreeFirePatchService.isInjected()
    @State private var selectedTarget: FreeFireTarget = FreeFirePatchService.selectedTarget
    @State private var showInjectionAlert: Bool = false
    @State private var injectionAlertText: String = ""
    @State private var toastMessage: String? = nil
    @State private var showFullKey: Bool = false
    @State private var showLogModal: Bool = false
    @State private var showAdvancedESP: Bool = false
    @State private var selectedColorTarget: ESPColorTarget = .all
    @State private var showColorPickerPopup: Bool = false

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

                // Segmented Tab Switcher [ MENU | SETTINGS ]
                topTabBar
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                if selectedTab == .menu {
                    // Game Target Selector (Side-by-side cards)
                    gameTargetSelector
                }

                // Tab Content Views
                if selectedTab == .menu {
                    menuContent
                } else {
                    settingsContent
                }
            }
            .frame(maxWidth: .infinity)

            // Floating Action HUD (Only in Menu Tab)
            if selectedTab == .menu {
                VStack {
                    Spacer()
                    bottomActionBar
                }
                .frame(maxWidth: .infinity)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }

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
        .sheet(isPresented: $showLogModal) {
            logTerminalSheet
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
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }

    // MARK: - Top Tab Switcher [ MENU | SETTINGS ]
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
        .frame(maxWidth: .infinity)
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
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

                            Text(target == .freeFireTH ? "Bản chính" : "Bản tối ưu")
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
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Menu Tab Content
    private var menuContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // AIM PROTOCOL Section
                aimingSection

                // ESP MATRIX Section
                espSection

                // COMBAT MODS Section (Buff Damage, Fast Fire, No Recoil, Fast Medkit)
                combatSection

                // SURVIVAL & MOVEMENT Section (Cam Xa + Slider, Speed Run, Fast Parachute)
                movementSection

                // Extra Bottom Padding for floating HUD
                Spacer().frame(height: 110)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
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

                                Text("Góc Quét (Silent FOV)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(CyberTheme.textSecondary)

                                Spacer()

                                Text("\(Int(cheatState.silentFOV))°")
                                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                    .foregroundColor(CyberTheme.crimsonNeon)
                            }
                            CyberSlider(value: $cheatState.silentFOV, range: 0...180, step: 1, activeColor: CyberTheme.crimsonNeon)
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

            // Card 2: Aim Bot & Target Selection (Neck / Head) + Aim Line
            CyberCard(glowColor: (cheatState.aimBot || cheatState.aimLine) ? CyberTheme.crimsonNeon.opacity(0.12) : Color.clear) {
                // Aim Bot Row
                CyberRowView(
                    iconName: "target",
                    title: "Aim Bot (Tự Động)",
                    subtitle: "Hút tâm trực tiếp vào đối thủ",
                    isOn: $cheatState.aimBot,
                    activeColor: CyberTheme.crimsonNeon
                )

                // 2 Options: Neck & Head (Shown when Aimbot is turned ON)
                if cheatState.aimBot {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "scope")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(CyberTheme.crimsonNeon)
                            Text("VỊ TRÍ HÚT TÂM (AIM TARGET)")
                                .font(.system(size: 10.5, weight: .heavy, design: .monospaced))
                                .foregroundColor(CyberTheme.crimsonNeon)
                                .tracking(1.0)
                            Spacer()
                        }
                        .padding(.top, 2)

                        HStack(spacing: 8) {
                            ForEach(AimBotTarget.allCases) { target in
                                let isSelected = (cheatState.aimBotTarget == target)
                                Button {
                                    let impact = UIImpactFeedbackGenerator(style: .medium)
                                    impact.impactOccurred()
                                    withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                                        cheatState.aimBotTarget = target
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        ZStack {
                                            Circle()
                                                .fill(isSelected ? Color.white.opacity(0.20) : Color.white.opacity(0.06))
                                                .frame(width: 24, height: 24)
                                            Image(systemName: target.icon)
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(isSelected ? .white : CyberTheme.textMuted)
                                        }

                                        VStack(alignment: .leading, spacing: 1) {
                                            Text(target.displayName)
                                                .font(.system(size: 12, weight: isSelected ? .bold : .medium))
                                                .foregroundColor(isSelected ? .white : Color(white: 0.8))
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.8)
                                            Text(target.subtitle)
                                                .font(.system(size: 9, weight: .regular))
                                                .foregroundColor(isSelected ? Color.white.opacity(0.85) : CyberTheme.textMuted)
                                                .lineLimit(1)
                                                .minimumScaleFactor(0.75)
                                        }
                                        Spacer(minLength: 2)

                                        if isSelected {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                    .padding(.horizontal, 8)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 42)
                                    .background(
                                        ZStack {
                                            if isSelected {
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(
                                                        LinearGradient(
                                                            colors: [
                                                                CyberTheme.crimsonNeon,
                                                                CyberTheme.crimsonDark
                                                            ],
                                                            startPoint: .topLeading,
                                                            endPoint: .bottomTrailing
                                                        )
                                                    )
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                            .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                                                    )
                                                    .shadow(color: CyberTheme.crimsonNeon.opacity(0.4), radius: 6)
                                            } else {
                                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                    .fill(Color.white.opacity(0.05))
                                                    .overlay(
                                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                                                    )
                                            }
                                        }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 2)
                    .padding(.bottom, 6)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Divider().background(CyberTheme.divider)

                // Aim Line Row
                CyberRowView(
                    iconName: "pencil.line",
                    title: "Aim Line (Tia Dẫn Tâm)",
                    subtitle: "Vạch định vị từ nòng súng đến kẻ địch",
                    isOn: $cheatState.aimLine,
                    activeColor: CyberTheme.crimsonNeon
                )
            }
        }
    }

    // MARK: - ESP MATRIX Section (With Separate Color Pickers for Box, Line, Skeleton, All)
    private var espSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            CyberSectionHeader(
                title: "ESP MATRIX SYSTEM",
                subtitle: "Nhìn xuyên tường, định vị vị trí đối thủ",
                icon: "eye.fill",
                accentColor: CyberTheme.cyberCyan
            )

            // Card 1: Main ESP Features
            CyberCard(glowColor: CyberTheme.cyberCyan.opacity(0.12)) {
                // Box ESP (With active color dot)
                CyberRowView(
                    iconName: "shippingbox.fill",
                    title: "Khung 2D (Box ESP)",
                    subtitle: "Hộp nhận diện bao quanh đối thủ",
                    isOn: $cheatState.boxESP,
                    activeColor: cheatState.getColor(for: cheatState.boxColorId).color,
                    tagColor: cheatState.getColor(for: cheatState.boxColorId).color
                )

                Divider().background(CyberTheme.divider)

                // Line ESP (With active color dot)
                CyberRowView(
                    iconName: "line.diagonal",
                    title: "Tia Chỉ Hướng (Line ESP)",
                    subtitle: "Tia định vị từ đỉnh màn hình xuống địch",
                    isOn: $cheatState.lineESP,
                    activeColor: cheatState.getColor(for: cheatState.lineColorId).color,
                    tagColor: cheatState.getColor(for: cheatState.lineColorId).color
                )

                Divider().background(CyberTheme.divider)

                // Health Bar
                CyberRowView(
                    iconName: "cross.case.fill",
                    title: "Thanh Máu (Health Bar)",
                    subtitle: "Hiển thị máu đối thủ",
                    isOn: $cheatState.healthBar,
                    activeColor: CyberTheme.cyberCyan
                )

                Divider().background(CyberTheme.divider)

                // Advanced ESP Expandable Toggle
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        showAdvancedESP.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: "slider.horizontal.3")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(CyberTheme.cyberCyan)

                        Text("Tùy Chọn ESP Mở Rộng")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color.white)

                        Spacer()

                        Image(systemName: showAdvancedESP ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(CyberTheme.textMuted)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if showAdvancedESP {
                    VStack(spacing: 8) {
                        Divider().background(CyberTheme.divider)

                        // Name Tag
                        CyberRowView(
                            iconName: "tag.fill",
                            title: "Tên Kẻ Địch (Name Tag)",
                            subtitle: "Nhận diện nickname của mục tiêu",
                            isOn: $cheatState.nameTag,
                            activeColor: CyberTheme.cyberCyan
                        )

                        Divider().background(CyberTheme.divider)

                        // Distance Tag
                        CyberRowView(
                            iconName: "ruler.fill",
                            title: "Khoảng Cách (Distance Tag)",
                            subtitle: "Đo cự ly chính xác theo mét",
                            isOn: $cheatState.distanceTag,
                            activeColor: CyberTheme.mechaGold
                        )

                        Divider().background(CyberTheme.divider)

                        // Skeleton ESP (With active color dot)
                        CyberRowView(
                            iconName: "figure.stand",
                            title: "Khung Xương (Skeleton ESP)",
                            subtitle: "Mô phỏng khớp xương & cử động",
                            isOn: $cheatState.skeletonESP,
                            activeColor: cheatState.getColor(for: cheatState.skeletonColorId).color,
                            tagColor: cheatState.getColor(for: cheatState.skeletonColorId).color
                        )

                        Divider().background(CyberTheme.divider)

                        // ESP Count
                        CyberRowView(
                            iconName: "number",
                            title: "Đếm Số Lượng Địch (ESP Count)",
                            subtitle: "Cảnh báo số lượng quân địch trong 250m",
                            isOn: $cheatState.espCount,
                            activeColor: CyberTheme.mechaGold
                        )

                        Divider().background(CyberTheme.divider)

                        // 360 Alert
                        CyberRowView(
                            iconName: "exclamationmark.triangle.fill",
                            title: "Cảnh Báo Địch Sau Lưng (360° Alert)",
                            subtitle: "Radar cảnh báo nguy hiểm xung quanh",
                            isOn: $cheatState.espAlert,
                            activeColor: CyberTheme.crimsonNeon
                        )
                    }
                    .padding(.top, 4)
                }
            }

            // Card 2: Dedicated Rich Color Matrix Customizer (Box, Line, Skeleton, All)
            CyberCard(glowColor: cheatState.getColor(for: cheatState.getColorId(for: selectedColorTarget)).color.opacity(0.15)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(CyberTheme.cyberCyan)

                        Text("BẢNG MÀU ESP TÙY BIẾN")
                            .font(.system(size: 12, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(1.0)

                        Spacer()

                        Text("7 Gam Màu")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundColor(CyberTheme.textMuted)
                    }

                    // Target Element Tabs [ Tất Cả | Khung Box | Tia Line | Khung Xương ]
                    HStack(spacing: 5) {
                        ForEach(ESPColorTarget.allCases) { target in
                            let isSelected = (selectedColorTarget == target)
                            let currentTargetColor = cheatState.getColor(for: cheatState.getColorId(for: target)).color

                            Button {
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                    selectedColorTarget = target
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Circle()
                                        .fill(currentTargetColor)
                                        .frame(width: 6, height: 6)
                                        .shadow(color: currentTargetColor.opacity(0.8), radius: 2)

                                    Text(target.title)
                                        .font(.system(size: 10.5, weight: isSelected ? .bold : .medium))
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.75)
                                }
                                .foregroundColor(isSelected ? .white : Color(white: 0.7))
                                .frame(maxWidth: .infinity)
                                .frame(height: 32)
                                .background(
                                    ZStack {
                                        if isSelected {
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(Color(white: 0.18))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .strokeBorder(currentTargetColor.opacity(0.8), lineWidth: 1)
                                                )
                                                .shadow(color: currentTargetColor.opacity(0.3), radius: 4)
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

                    // Tappable Color Item -> Opens Popup Picker (7 Preset Colors)
                    let activeCol = cheatState.getColor(for: cheatState.getColorId(for: selectedColorTarget))
                    Button {
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                        showColorPickerPopup = true
                    } label: {
                        HStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(activeCol.color.opacity(0.20))
                                    .frame(width: 32, height: 32)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(activeCol.color.opacity(0.6), lineWidth: 1)
                                    )

                                Image(systemName: selectedColorTarget.icon)
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(activeCol.color)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mục áp dụng: \(selectedColorTarget.title)")
                                    .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                                    .foregroundColor(CyberTheme.textMuted)

                                Text("\(activeCol.name) • \(activeCol.hex)")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(activeCol.color)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(CyberTheme.textMuted)
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    Divider().background(CyberTheme.divider)

                    // Line Thickness Slider
                    VStack(spacing: 4) {
                        HStack {
                            Text("Độ Dày Nét Vẽ ESP")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(CyberTheme.textSecondary)
                            Spacer()
                            Text(String(format: "%.1f px", cheatState.espLineThickness))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        CyberSlider(
                            value: $cheatState.espLineThickness,
                            range: 1.0...8.0,
                            step: 0.5,
                            activeColor: activeCol.color
                        )
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

            CyberCard(glowColor: (cheatState.buffDamage || cheatState.fastFire || cheatState.noRecoil || cheatState.fastMedkit) ? CyberTheme.crimsonFlame.opacity(0.12) : Color.clear) {
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

                // No Recoil
                CyberRowView(
                    iconName: "bolt.shield.fill",
                    title: "Không Giật (No Recoil 0%)",
                    subtitle: "Khử rung lắc nòng súng khi xả đạn liên tục",
                    isOn: $cheatState.noRecoil,
                    activeColor: CyberTheme.crimsonNeon
                )

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

            CyberCard(glowColor: (cheatState.wideView || cheatState.speedRun || cheatState.fastParachute) ? CyberTheme.cyberCyan.opacity(0.12) : Color.clear) {
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

                // Speed Run
                CyberRowView(
                    iconName: "figure.run",
                    title: "Tăng Tốc Chạy (Speed Run)",
                    subtitle: "Di chuyển thần tốc, né đạn linh hoạt",
                    isOn: $cheatState.speedRun,
                    activeColor: CyberTheme.matrixGreen
                )

                Divider().background(CyberTheme.divider)

                // Fast Parachute
                CyberRowView(
                    iconName: "wind",
                    title: "Nhảy Dù Siêu Tốc (Fast Parachute)",
                    subtitle: "Rơi tự do và tiếp đất cực nhanh",
                    isOn: $cheatState.fastParachute,
                    activeColor: CyberTheme.mechaGold
                )
            }
        }
    }

    // MARK: - Floating Futuristic Action HUD (Bottom Bar)
    private var bottomActionBar: some View {
        VStack(spacing: 6) {
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
                                Text(isInjected ? "ĐANG GỠ BỎ..." : "ĐANG INJECT...")
                                    .font(.system(size: 14, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                            } else {
                                Text(isInjected ? "UNINJECT (\(selectedTarget.displayName.uppercased()))" : "INJECT (\(selectedTarget.displayName.uppercased()))")
                                    .font(.system(size: 13.5, weight: .heavy, design: .monospaced))
                                    .foregroundColor(.white)
                                    .tracking(0.5)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)

                                Text(isInjected ? "Nhấn để hủy kích hoạt chức năng" : "Bắt đầu kích hoạt chức năng")
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
            .padding(.horizontal, 16)
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
        .frame(maxWidth: .infinity)
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

    // MARK: - SETTINGS Tab Content
    private var settingsContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                // Card 1: App Info & Engine Core
                appCoreCard

                // Card 2: License Key & Remaining Expiration
                licenseSettingsCard

                // Card 3: Device Hardware & Model Specs
                deviceHardwareCard

                // Card 4: Compatibility & Kernel Status
                systemCompatibilityCard

                // Card 5: Utilities & Log Terminal Action
                utilitiesCard

                Spacer().frame(height: 40)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
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
                SettingsInfoRow(icon: "number.circle.fill", label: "Phiên Bản Core", value: "v1.0.0 (Build 3105)", isMonospaced: true)
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(icon: "cpu.fill", label: "Kiến Trúc Binary", value: "ARM64e • iOS Metal", isMonospaced: true)
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(icon: "gamecontroller.fill", label: "Đối Tượng Hỗ Trợ", value: "Free Fire & FF MAX")
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
                            .foregroundColor(CyberTheme.matrixGreen)
                    }

                    Spacer()

                    // VIP Status Pill
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
                    value: "KFD / Opa334 Sẵn Sàng",
                    valueColor: CyberTheme.matrixGreen
                )
                Divider().background(CyberTheme.divider)
                SettingsInfoRow(
                    icon: "folder.badge.gearshape",
                    label: "Quyền Sandbox",
                    value: "Container Documents R/W Active",
                    valueColor: CyberTheme.matrixGreen
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
                // View Console Logs Button
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

    // MARK: - Log Terminal Modal Sheet
    private var logTerminalSheet: some View {
        NavigationView {
            ZStack {
                CyberTheme.bgVoid
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    // Action Buttons Header
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
                            showToast("Đã sao chép toàn bộ logs!")
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
                            appLog.entries.removeAll()
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

                    // Scrollable Console
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
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
                        .onChange(of: appLog.entries.count) { count in
                            guard count > 0 else { return }
                            proxy.scrollTo(count - 1, anchor: .bottom)
                        }
                    }
                }
            }
            .navigationTitle("Console Logs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        showLogModal = false
                    }
                    .foregroundColor(CyberTheme.crimsonNeon)
                }
            }
        }
    }

    // MARK: - Actions
    private func handleInjectCheat() {
        guard !isInjecting else { return }
        isInjecting = true
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()

        appLog.append("[CHEAT] Bắt đầu nạp module cheat vào \(selectedTarget.displayName)...")

        Task {
            do {
                try await FreeFirePatchService.inject(target: selectedTarget)
                await MainActor.run {
                    self.isInjecting = false
                    self.isInjected = true
                    let notif = UINotificationFeedbackGenerator()
                    notif.notificationOccurred(.success)
                    self.injectionAlertText = "✅ Đã Inject Cheat thành công."
                    self.showInjectionAlert = true
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

        appLog.append("[CHEAT] Bắt đầu gỡ bỏ module cheat khỏi \(selectedTarget.displayName)...")

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
        guard let date = date else { return "Vĩnh Viễn (Lifetime)" }
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
        guard let date = date else { return "Vĩnh viễn (Không giới hạn)" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "vi_VN")
        formatter.dateFormat = "dd/MM/yyyy • HH:mm"
        return formatter.string(from: date)
    }
}
