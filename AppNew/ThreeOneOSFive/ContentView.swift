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
        case .menu: return "bolt.shield.fill"
        case .settings: return "gearshape.2.fill"
        }
    }
}

// MARK: - ESP Color Definition
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
    @Published var espColorEnabled: Bool {
        didSet {
            UserDefaults.standard.set(espColorEnabled, forKey: "cheat.espColorEnabled")
            AppLog.shared.append("[ESP] ESP Color: \(espColorEnabled ? "ENABLED" : "DISABLED")")
            syncIfInjected()
        }
    }
    @Published var espSelectedColorId: Int {
        didSet {
            UserDefaults.standard.set(espSelectedColorId, forKey: "cheat.espSelectedColorId")
            AppLog.shared.append("[ESP] Color selected: \(selectedColor.name)")
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

    // Available ESP Colors
    let colorOptions: [CheatColorOption] = [
        CheatColorOption(id: 0, name: "Lục Bảo (Green)", color: Color(red: 0.05, green: 0.92, blue: 0.42), hex: "#0DE061"),
        CheatColorOption(id: 1, name: "Huyết Luân (Sharingan Red)", color: Color(red: 1.00, green: 0.16, blue: 0.24), hex: "#FF293E"),
        CheatColorOption(id: 2, name: "Chakra Lam (Cyan)", color: Color(red: 0.00, green: 0.90, blue: 1.00), hex: "#00E5FF"),
        CheatColorOption(id: 3, name: "Hoàng Kim (Gold)", color: Color(red: 1.00, green: 0.82, blue: 0.12), hex: "#FFD11F"),
        CheatColorOption(id: 4, name: "Susanoo Tím (Purple)", color: Color(red: 0.78, green: 0.35, blue: 1.00), hex: "#C759FF"),
        CheatColorOption(id: 5, name: "Bạch Nhãn (Pure White)", color: Color.white, hex: "#FFFFFF")
    ]

    var selectedColor: CheatColorOption {
        colorOptions.first(where: { $0.id == espSelectedColorId }) ?? colorOptions[0]
    }

    init() {
        let ud = UserDefaults.standard
        self.aimSilent = ud.object(forKey: "cheat.aimSilent") as? Bool ?? true
        self.silentFOV = ud.object(forKey: "cheat.silentFOV") as? Double ?? 70.0
        self.headshotRate = ud.object(forKey: "cheat.headshotRate") as? Double ?? 49.0
        self.aimBot = ud.object(forKey: "cheat.aimBot") as? Bool ?? false
        self.aimLine = ud.object(forKey: "cheat.aimLine") as? Bool ?? false

        self.boxESP = ud.object(forKey: "cheat.boxESP") as? Bool ?? true
        self.lineESP = ud.object(forKey: "cheat.lineESP") as? Bool ?? true
        self.healthBar = ud.object(forKey: "cheat.healthBar") as? Bool ?? true
        self.nameTag = ud.object(forKey: "cheat.nameTag") as? Bool ?? true
        self.distanceTag = ud.object(forKey: "cheat.distanceTag") as? Bool ?? true
        self.skeletonESP = ud.object(forKey: "cheat.skeletonESP") as? Bool ?? true
        self.espCount = ud.object(forKey: "cheat.espCount") as? Bool ?? true
        self.espAlert = ud.object(forKey: "cheat.espAlert") as? Bool ?? false
        self.espColorEnabled = ud.object(forKey: "cheat.espColorEnabled") as? Bool ?? true
        self.espSelectedColorId = ud.object(forKey: "cheat.espSelectedColorId") as? Int ?? 0
        self.espLineThickness = ud.object(forKey: "cheat.espLineThickness") as? Double ?? 2.5

        self.fastMedkit = ud.object(forKey: "cheat.fastMedkit") as? Bool ?? false
        self.noRecoil = ud.object(forKey: "cheat.noRecoil") as? Bool ?? false
    }

    func resetToDefaults() {
        aimSilent = true
        silentFOV = 70.0
        headshotRate = 49.0
        aimBot = false
        aimLine = false

        boxESP = true
        lineESP = true
        healthBar = true
        nameTag = true
        distanceTag = true
        skeletonESP = true
        espCount = true
        espAlert = false
        espColorEnabled = true
        espSelectedColorId = 0
        espLineThickness = 2.5

        fastMedkit = false
        noRecoil = false

        AppLog.shared.append("[CONFIG] Cheat settings reset to default values.")
        syncIfInjected()
    }
}

// MARK: - Cyber Shinobi & Mecha 3D Theme Palette
private enum CyberTheme {
    static let bgVoid = Color(red: 0.035, green: 0.035, blue: 0.045)
    static let bgPlate = Color(red: 0.075, green: 0.075, blue: 0.09)
    static let bgPlateElevated = Color(red: 0.105, green: 0.105, blue: 0.13)
    static let bgInput = Color(red: 0.05, green: 0.05, blue: 0.065)

    // Naruto / Sharingan Crimson Energy
    static let crimsonNeon = Color(red: 1.00, green: 0.18, blue: 0.25)
    static let crimsonFlame = Color(red: 0.95, green: 0.32, blue: 0.12)
    static let crimsonDark = Color(red: 0.35, green: 0.05, blue: 0.08)

    // Mecha Cybernetic Accents
    static let cyberCyan = Color(red: 0.00, green: 0.88, blue: 0.98)
    static let mechaGold = Color(red: 1.00, green: 0.78, blue: 0.18)
    static let matrixGreen = Color(red: 0.12, green: 0.94, blue: 0.45)
    static let purpleChakra = Color(red: 0.72, green: 0.35, blue: 1.00)

    static let cardBorderNormal = Color.white.opacity(0.09)
    static let divider = Color.white.opacity(0.07)
    static let textMuted = Color(white: 0.52)
    static let textSecondary = Color(white: 0.75)
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
        .padding(15)
        .background(
            ZStack {
                // Background gradient
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
                                Color.white.opacity(0.22),
                                Color.white.opacity(0.05),
                                CyberTheme.crimsonNeon.opacity(0.20)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        )
        .shadow(color: Color.black.opacity(0.55), radius: 8, x: 0, y: 4)
        .shadow(color: glowColor, radius: 10, x: 0, y: 0)
    }
}

// MARK: - Section Header with Cyber / Shinobi Motif
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
                    .font(.system(size: 12, weight: .heavy, design: .monospaced))
                    .foregroundColor(.white)
                    .tracking(1.2)
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(CyberTheme.textMuted)
            }

            Spacer()

            // 3D Mecha Telemetry Lines
            HStack(spacing: 3) {
                Rectangle().fill(accentColor.opacity(0.9)).frame(width: 3, height: 10)
                Rectangle().fill(accentColor.opacity(0.5)).frame(width: 3, height: 7)
                Rectangle().fill(accentColor.opacity(0.25)).frame(width: 3, height: 4)
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
                .shadow(color: configuration.isOn ? activeColor.opacity(0.5) : Color.clear, radius: 6)

            // 3D Metallic Knob
            Circle()
                .fill(
                    LinearGradient(
                        colors: [.white, Color(white: 0.88)],
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

    var body: some View {
        HStack(spacing: 12) {
            // 3D Mecha Icon Box
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
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(CyberTheme.textMuted)
                    .lineLimit(1)
            }

            Spacer()

            // Custom 3D Toggle
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(CyberToggleStyle(activeColor: activeColor))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Cyber 3D Drag Slider
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
                    .fill(Color.black.opacity(0.65))
                    .frame(height: 6)
                    .overlay(
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                    )
                    .padding(.horizontal, 12)

                // Glowing Active Chakra Fill
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [activeColor.opacity(0.8), activeColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, fraction * availableWidth), height: 6)
                    .padding(.leading, 12)
                    .shadow(color: activeColor.opacity(0.5), radius: 4)

                // 3D Circular Thumb with Chakra Core
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.white, Color(white: 0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 20, height: 20)
                        .shadow(color: Color.black.opacity(0.6), radius: 4, x: 0, y: 2)

                    Circle()
                        .fill(activeColor)
                        .frame(width: 7, height: 7)
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
        .frame(height: 28)
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

    var body: some View {
        ZStack {
            // Deep Obsidian Matrix Backdrop
            CyberTheme.bgVoid
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Shinobi / Mecha Header Bar
                topHeaderBar

                // Segmented Tab Switcher [ MENU | SETTINGS ]
                topTabBar
                    .padding(.top, 8)
                    .padding(.bottom, 8)

                if selectedTab == .menu {
                    // Game Target Selector (Free Fire Thường vs Free Fire MAX)
                    gameTargetSelector
                }

                // Tab Content Views
                if selectedTab == .menu {
                    menuContent
                } else {
                    settingsContent
                }
            }

            // Floating 3D Action HUD (Only in Menu Tab)
            if selectedTab == .menu {
                VStack {
                    Spacer()
                    bottomActionBar
                }
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
                    .padding(.bottom, 85)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
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

    // MARK: - Top Header Bar (Naruto + Mecha Branding)
    private var topHeaderBar: some View {
        HStack(spacing: 12) {
            // Glowing Shinobi / Sharingan Emblem
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [CyberTheme.crimsonNeon, CyberTheme.crimsonDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 36, height: 36)
                    .overlay(
                        Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: CyberTheme.crimsonNeon.opacity(0.6), radius: 8)

                Image(systemName: "scope")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
            }

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text("INNOVA CHEAT")
                        .font(.system(size: 17, weight: .heavy, design: .monospaced))
                        .foregroundColor(.white)
                        .tracking(1.5)

                    // Shinobi Tag
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(CyberTheme.crimsonNeon)
                        Text("SHINOBI")
                            .font(.system(size: 8.5, weight: .heavy, design: .monospaced))
                            .foregroundColor(CyberTheme.crimsonNeon)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(CyberTheme.crimsonNeon.opacity(0.14))
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(CyberTheme.crimsonNeon.opacity(0.3), lineWidth: 0.8))
                }

                Text("CHAKRA MATRIX • FREE FIRE BYPASS ENGINE")
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundColor(CyberTheme.textMuted)
            }

            Spacer()

            // Status Indicator Dot
            HStack(spacing: 5) {
                Circle()
                    .fill(isInjected ? CyberTheme.matrixGreen : CyberTheme.crimsonNeon)
                    .frame(width: 7, height: 7)
                    .shadow(color: (isInjected ? CyberTheme.matrixGreen : CyberTheme.crimsonNeon).opacity(0.8), radius: 4)

                Text(isInjected ? "INJECTED" : "READY")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundColor(isInjected ? CyberTheme.matrixGreen : CyberTheme.crimsonNeon)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
        }
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
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(selectedTab == tab ? .white : CyberTheme.textMuted)

                        Text(tab.title)
                            .font(.system(size: 13, weight: selectedTab == tab ? .heavy : .medium, design: .monospaced))
                            .foregroundColor(selectedTab == tab ? .white : CyberTheme.textMuted)
                            .tracking(1.0)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        ZStack {
                            if selectedTab == tab {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                CyberTheme.crimsonNeon.opacity(0.85),
                                                CyberTheme.crimsonDark
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                                    )
                                    .shadow(color: CyberTheme.crimsonNeon.opacity(0.4), radius: 6)
                            } else {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
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
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(red: 0.06, green: 0.06, blue: 0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Game Target Selector
    private var gameTargetSelector: some View {
        HStack(spacing: 8) {
            ForEach(FreeFireTarget.allCases) { target in
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    selectedTarget = target
                    FreeFirePatchService.selectedTarget = target
                    isInjected = FreeFirePatchService.isInjected(target: target)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: target == .freeFireMAX ? "flame.fill" : "cross.case.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(selectedTarget == target ? .white : CyberTheme.textMuted)

                        Text(target.displayName)
                            .font(.system(size: 13, weight: selectedTarget == target ? .bold : .medium))
                            .foregroundColor(selectedTarget == target ? .white : Color(white: 0.8))

                        if FreeFirePatchService.isInjected(target: target) {
                            Circle()
                                .fill(CyberTheme.matrixGreen)
                                .frame(width: 7, height: 7)
                                .shadow(color: CyberTheme.matrixGreen.opacity(0.8), radius: 3)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(
                        ZStack {
                            if selectedTarget == target {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color(white: 0.18),
                                                Color(white: 0.10)
                                            ],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(CyberTheme.crimsonNeon.opacity(0.7), lineWidth: 1)
                                    )
                            } else {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(CyberTheme.bgPlate)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
                                    )
                            }
                        }
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Menu Tab Content
    private var menuContent: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 18) {
                // AIMING Section
                aimingSection

                // ESP Section
                espSection

                // COMBAT Section
                combatSection

                // Extra Bottom Padding for floating HUD
                Spacer().frame(height: 95)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    // MARK: - AIMING Section
    private var aimingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CyberSectionHeader(
                title: "AIM PROTOCOL",
                subtitle: "Khóa mục tiêu & Cân bằng Chakra",
                icon: "scope",
                accentColor: CyberTheme.crimsonNeon
            )

            CyberCard(glowColor: CyberTheme.crimsonNeon.opacity(cheatState.aimSilent ? 0.14 : 0.0)) {
                // Aim Silent Row
                CyberRowView(
                    iconName: "wind",
                    title: "Aim Silent (Tàng Hình)",
                    subtitle: "Khóa tâm ẩn giấu không giật màn hình",
                    isOn: $cheatState.aimSilent,
                    activeColor: CyberTheme.crimsonNeon
                )

                // Sub-controls for Aim Silent
                if cheatState.aimSilent {
                    VStack(spacing: 12) {
                        // Silent FOV
                        VStack(spacing: 4) {
                            HStack {
                                Text("Góc Quét (Silent FOV)")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(CyberTheme.textSecondary)
                                Spacer()
                                Text("\(Int(cheatState.silentFOV))°")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(CyberTheme.crimsonNeon)
                            }
                            CyberSlider(value: $cheatState.silentFOV, range: 0...180, step: 1, activeColor: CyberTheme.crimsonNeon)
                        }

                        // Headshot Rate
                        VStack(spacing: 4) {
                            HStack {
                                Text("Tỉ Lệ Trúng Đầu (Headshot)")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(CyberTheme.textSecondary)
                                Spacer()
                                Text("\(Int(cheatState.headshotRate))%")
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(CyberTheme.mechaGold)
                            }
                            CyberSlider(value: $cheatState.headshotRate, range: 0...100, step: 1, activeColor: CyberTheme.mechaGold)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                }

                Divider().background(CyberTheme.divider)

                // Aim Bot Row
                CyberRowView(
                    iconName: "target",
                    title: "Aim Bot (Tự Động)",
                    subtitle: "Hút tâm trực tiếp vào đầu / cổ địch",
                    isOn: $cheatState.aimBot,
                    activeColor: CyberTheme.cyberCyan
                )

                Divider().background(CyberTheme.divider)

                // Aim Line Row
                CyberRowView(
                    iconName: "pencil.line",
                    title: "Aim Line (Tia Dẫn Tâm)",
                    subtitle: "Vạch định vị từ nòng súng đến kẻ địch",
                    isOn: $cheatState.aimLine,
                    activeColor: CyberTheme.matrixGreen
                )
            }
        }
    }

    // MARK: - ESP Section (Byakugan Vision)
    private var espSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CyberSectionHeader(
                title: "BYAKUGAN ESP MATRIX",
                subtitle: "Bạch nhãn quét xuyên vật thể & bản đồ",
                icon: "eye.fill",
                accentColor: CyberTheme.cyberCyan
            )

            CyberCard(glowColor: CyberTheme.cyberCyan.opacity(0.10)) {
                // Box ESP
                CyberRowView(
                    iconName: "square.dashed",
                    title: "Khung 2D (Box ESP)",
                    subtitle: "Hộp nhận diện bao quanh đối thủ",
                    isOn: $cheatState.boxESP,
                    activeColor: CyberTheme.cyberCyan
                )

                Divider().background(CyberTheme.divider)

                // Line ESP
                CyberRowView(
                    iconName: "line.diagonal",
                    title: "Tia Chỉ Hướng (Line ESP)",
                    subtitle: "Tia định vị từ đỉnh màn hình xuống địch",
                    isOn: $cheatState.lineESP,
                    activeColor: CyberTheme.cyberCyan
                )

                Divider().background(CyberTheme.divider)

                // Health Bar
                CyberRowView(
                    iconName: "heart.text.square.fill",
                    title: "Thanh Máu (Health Bar)",
                    subtitle: "Hiển thị lượng sinh lực thời gian thực",
                    isOn: $cheatState.healthBar,
                    activeColor: CyberTheme.matrixGreen
                )

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

                // Skeleton ESP
                CyberRowView(
                    iconName: "figure.stand",
                    title: "Khung Xương (Skeleton ESP)",
                    subtitle: "Mô phỏng khớp xương & cử động",
                    isOn: $cheatState.skeletonESP,
                    activeColor: CyberTheme.purpleChakra
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

                // ESP Alert
                CyberRowView(
                    iconName: "exclamationmark.triangle.fill",
                    title: "Cảnh Báo Địch Sau Lưng (360° Alert)",
                    subtitle: "Radar cảnh báo nguy hiểm xung quanh",
                    isOn: $cheatState.espAlert,
                    activeColor: CyberTheme.crimsonNeon
                )

                Divider().background(CyberTheme.divider)

                // ESP Color Option
                CyberRowView(
                    iconName: "paintpalette.fill",
                    title: "Màu Sắc ESP",
                    subtitle: "Tùy biến bảng màu hiển thị",
                    isOn: $cheatState.espColorEnabled,
                    activeColor: cheatState.selectedColor.color
                )

                if cheatState.espColorEnabled {
                    VStack(spacing: 12) {
                        // Color Selector Menu
                        Menu {
                            ForEach(cheatState.colorOptions) { option in
                                Button {
                                    cheatState.espSelectedColorId = option.id
                                } label: {
                                    HStack {
                                        Text(option.name)
                                        if option.id == cheatState.espSelectedColorId {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(cheatState.selectedColor.color)
                                    .frame(width: 14, height: 14)
                                    .shadow(color: cheatState.selectedColor.color.opacity(0.8), radius: 4)

                                Text(cheatState.selectedColor.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)

                                Spacer()

                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(CyberTheme.textMuted)
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 42)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(Color(white: 0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                            )
                        }

                        // Line thickness slider
                        VStack(spacing: 4) {
                            HStack {
                                Text("Độ Dày Nét Vẽ ESP (px)")
                                    .font(.system(size: 12.5, weight: .medium))
                                    .foregroundColor(CyberTheme.textSecondary)
                                Spacer()
                                Text(String(format: "%.1f px", cheatState.espLineThickness))
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            CyberSlider(value: $cheatState.espLineThickness, range: 1.0...8.0, step: 0.5, activeColor: cheatState.selectedColor.color)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 6)
                }
            }
        }
    }

    // MARK: - COMBAT Section
    private var combatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            CyberSectionHeader(
                title: "COMBAT OVERDRIVE",
                subtitle: "Cường hóa thể thuật nhẫn giả",
                icon: "shield.righthalf.filled",
                accentColor: CyberTheme.crimsonFlame
            )

            CyberCard(glowColor: CyberTheme.crimsonFlame.opacity(0.10)) {
                // Fast Medkit
                CyberRowView(
                    iconName: "cross.case.fill",
                    title: "Bơm Máu Siêu Tốc (Fast Medkit)",
                    subtitle: "Tăng tốc độ hồi phục sinh lực tức thì",
                    isOn: $cheatState.fastMedkit,
                    activeColor: CyberTheme.matrixGreen
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
            }
        }
    }

    // MARK: - Floating 3D Mecha Action HUD
    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            // Main Inject / Uninject Button
            Button {
                if isInjected {
                    handleUninjectCheat()
                } else {
                    handleInjectCheat()
                }
            } label: {
                HStack(spacing: 9) {
                    if isInjecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.9)
                        Text(isInjected ? "ĐANG GỠ BỎ..." : "ĐANG INJECT...")
                            .font(.system(size: 15, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                    } else if isInjected {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 19, weight: .bold))
                            .foregroundColor(.white)
                        Text("UNINJECT (\(selectedTarget.displayName.uppercased()))")
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(0.5)
                    } else {
                        Image(systemName: "flame.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("INJECT (\(selectedTarget.displayName.uppercased()))")
                            .font(.system(size: 14, weight: .heavy, design: .monospaced))
                            .foregroundColor(.white)
                            .tracking(0.5)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    ZStack {
                        if isInjected {
                            LinearGradient(
                                colors: [
                                    Color(red: 0.88, green: 0.20, blue: 0.25),
                                    Color(red: 0.60, green: 0.10, blue: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        } else {
                            LinearGradient(
                                colors: [
                                    CyberTheme.crimsonNeon,
                                    CyberTheme.crimsonDark
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 1)
                )
                .shadow(color: (isInjected ? Color.red : CyberTheme.crimsonNeon).opacity(0.5), radius: 10, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(isInjecting)

            // Reset Defaults Button
            Button(action: handleResetDefaults) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(CyberTheme.bgPlateElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 24)
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

    // MARK: - SETTINGS Tab Content (Full Comprehensive System Specs)
    private var settingsContent: some View {
        ScrollView(showsIndicators: true) {
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

                Spacer().frame(height: 35)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
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
                accentColor: CyberTheme.purpleChakra
            )

            CyberCard(glowColor: CyberTheme.purpleChakra.opacity(0.10)) {
                // View Console Logs Button
                Button {
                    showLogModal = true
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "terminal.fill")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(CyberTheme.purpleChakra)

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
