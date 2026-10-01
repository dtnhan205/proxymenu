import SwiftUI
import UIKit

// MARK: - Cheat Tab Enum
enum CheatTab: Int, CaseIterable {
    case menu = 0
    case log = 1

    var title: String {
        switch self {
        case .menu: return "Menu"
        case .log: return "Log"
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

    // AIMING
    private func syncIfInjected() {
        if FreeFirePatchService.isInjected() {
            FreeFirePatchService.syncConfig(state: self)
        }
    }

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
        CheatColorOption(id: 0, name: "Green", color: Color(red: 0.05, green: 0.88, blue: 0.38), hex: "#0DE061"),
        CheatColorOption(id: 1, name: "Red", color: Color(red: 1.00, green: 0.24, blue: 0.24), hex: "#FF3D3D"),
        CheatColorOption(id: 2, name: "Cyan", color: Color(red: 0.00, green: 0.90, blue: 1.00), hex: "#00E5FF"),
        CheatColorOption(id: 3, name: "Yellow", color: Color(red: 1.00, green: 0.88, blue: 0.10), hex: "#FFE11A"),
        CheatColorOption(id: 4, name: "Purple", color: Color(red: 0.78, green: 0.35, blue: 1.00), hex: "#C759FF"),
        CheatColorOption(id: 5, name: "White", color: Color.white, hex: "#FFFFFF")
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

// MARK: - Custom Colors & Palette
private enum CheatPalette {
    static let background = Color(red: 0.05, green: 0.05, blue: 0.06)
    static let cardBackground = Color(red: 0.086, green: 0.086, blue: 0.094)
    static let cardBorder = Color(white: 0.15)
    static let divider = Color(white: 0.14)
    static let sectionHeader = Color(white: 0.44)

    // Cream / Off-White theme for active toggles, icons, and button
    static let cream = Color(red: 0.95, green: 0.93, blue: 0.88)
    static let darkKnob = Color(red: 0.08, green: 0.08, blue: 0.08)

    // Inactive elements
    static let inactiveTrack = Color(red: 0.17, green: 0.17, blue: 0.19)
    static let inactiveThumb = Color(red: 0.54, green: 0.54, blue: 0.56)
    static let inactiveIconBox = Color(red: 0.14, green: 0.14, blue: 0.16)
    static let inactiveIcon = Color(red: 0.72, green: 0.72, blue: 0.75)

    // Tab switcher
    static let tabBackground = Color(red: 0.15, green: 0.15, blue: 0.16)
    static let tabSelected = Color(red: 0.32, green: 0.32, blue: 0.35)
}

// MARK: - Custom Switch Toggle Style
struct CheatSwitchToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            Spacer()
            ZStack(alignment: configuration.isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(configuration.isOn ? CheatPalette.cream : CheatPalette.inactiveTrack)
                    .frame(width: 51, height: 31)

                Circle()
                    .fill(configuration.isOn ? CheatPalette.darkKnob : CheatPalette.inactiveThumb)
                    .frame(width: 23, height: 23)
                    .padding(.horizontal, 4)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                withAnimation(.spring(response: 0.22, dampingFraction: 0.75)) {
                    configuration.isOn.toggle()
                }
            }
        }
    }
}

// MARK: - Custom Drag Slider
struct CheatSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    var step: Double = 1.0

    var body: some View {
        GeometryReader { geo in
            let availableWidth = max(geo.size.width - 24, 1)
            let clampedVal = min(max(value, range.lowerBound), range.upperBound)
            let fraction = CGFloat((clampedVal - range.lowerBound) / (range.upperBound - range.lowerBound))
            let thumbX = 12 + fraction * availableWidth

            ZStack(alignment: .leading) {
                // Background Track
                Capsule()
                    .fill(Color(white: 0.22))
                    .frame(height: 3)
                    .padding(.horizontal, 12)

                // Active Track
                Capsule()
                    .fill(Color.white.opacity(0.35))
                    .frame(width: max(0, fraction * availableWidth), height: 3)
                    .padding(.leading, 12)

                // White Circular Thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(color: Color.black.opacity(0.4), radius: 3, x: 0, y: 1)
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

// MARK: - Cheat Row Component
struct CheatRowView: View {
    let iconName: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Icon Square
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn ? CheatPalette.cream : CheatPalette.inactiveIconBox)
                    .frame(width: 42, height: 42)

                Image(systemName: iconName)
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(isOn ? CheatPalette.darkKnob : CheatPalette.inactiveIcon)
            }
            .animation(.easeInOut(duration: 0.2), value: isOn)

            // Title & Subtitle
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)

                Text(subtitle)
                    .font(.system(size: 11.5, weight: .regular))
                    .foregroundColor(Color(white: 0.58))
                    .lineLimit(1)
            }

            Spacer()

            // Custom Switch
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(CheatSwitchToggleStyle())
        }
        .padding(.vertical, 8)
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
    @State private var copiedLogToast: Bool = false

    var body: some View {
        ZStack {
            // Solid dark backdrop
            CheatPalette.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Segmented Bar: [ Menu | Log ]
                topTabBar
                    .padding(.top, 6)
                    .padding(.bottom, 8)

                if selectedTab == .menu {
                    // Game Target Selector (FF Thường vs FF MAX)
                    gameTargetSelector
                }

                // Tab Content
                if selectedTab == .menu {
                    menuContent
                } else {
                    logContent
                }
            }

            // Fixed Bottom Action Bar (Only in Menu Tab)
            if selectedTab == .menu {
                VStack {
                    Spacer()
                    bottomActionBar
                }
                .ignoresSafeArea(.keyboard, edges: .bottom)
            }

            // Copy Toast
            if copiedLogToast {
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(CheatPalette.cream)
                        Text("Đã sao chép toàn bộ log!")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(white: 0.2).opacity(0.95))
                    .clipShape(Capsule())
                    .shadow(radius: 6)
                    .padding(.bottom, 30)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(100)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            isInjected = FreeFirePatchService.isInjected(target: selectedTarget)
        }
        .alert("Cheat Engine", isPresented: $showInjectionAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(injectionAlertText)
        }
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
                            .foregroundColor(selectedTarget == target ? CheatPalette.darkKnob : CheatPalette.inactiveIcon)

                        Text(target.displayName)
                            .font(.system(size: 13, weight: selectedTarget == target ? .bold : .medium))
                            .foregroundColor(selectedTarget == target ? CheatPalette.darkKnob : .white)

                        if FreeFirePatchService.isInjected(target: target) {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 7, height: 7)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(selectedTarget == target ? CheatPalette.cream : CheatPalette.cardBackground)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(selectedTarget == target ? Color.clear : CheatPalette.cardBorder, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 6)
    }

    // MARK: - Top Tab Switcher
    private var topTabBar: some View {
        HStack(spacing: 0) {
            ForEach(CheatTab.allCases, id: \.self) { tab in
                Button {
                    let impact = UIImpactFeedbackGenerator(style: .light)
                    impact.impactOccurred()
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.title)
                        .font(.system(size: 14, weight: selectedTab == tab ? .bold : .medium))
                        .foregroundColor(selectedTab == tab ? .white : Color(white: 0.6))
                        .frame(maxWidth: .infinity)
                        .frame(height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedTab == tab ? CheatPalette.tabSelected : Color.clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(CheatPalette.tabBackground)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Menu Tab Content
    private var menuContent: some View {
        ScrollView(showsIndicators: true) {
            VStack(alignment: .leading, spacing: 20) {
                // AIMING Section
                aimingSection

                // ESP Section
                espSection

                // COMBAT Section
                combatSection

                // Extra Bottom Padding so content isn't covered by bottom bar
                Spacer().frame(height: 90)
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
        }
    }

    // MARK: - AIMING Section
    private var aimingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AIMING")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(CheatPalette.sectionHeader)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Aim Silent Row
                CheatRowView(
                    iconName: "wind",
                    title: "Aim Silent",
                    subtitle: "Silent aim with headshot rate and FOV",
                    isOn: $cheatState.aimSilent
                )

                // Sub-controls for Aim Silent
                if cheatState.aimSilent {
                    VStack(spacing: 12) {
                        // Silent FOV
                        VStack(spacing: 4) {
                            HStack {
                                Text("Silent FOV")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color(white: 0.7))
                                Spacer()
                                Text("\(Int(cheatState.silentFOV))")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            CheatSlider(value: $cheatState.silentFOV, range: 0...180, step: 1)
                        }

                        // Headshot Rate
                        VStack(spacing: 4) {
                            HStack {
                                Text("Headshot")
                                    .font(.system(size: 13, weight: .regular))
                                    .foregroundColor(Color(white: 0.7))
                                Spacer()
                                Text("\(Int(cheatState.headshotRate))%")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white)
                            }
                            CheatSlider(value: $cheatState.headshotRate, range: 0...100, step: 1)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }

                Divider().background(CheatPalette.divider)

                // Aim Bot Row
                CheatRowView(
                    iconName: "scope",
                    title: "Aim Bot",
                    subtitle: "Head or neck aim with FOV mode",
                    isOn: $cheatState.aimBot
                )

                Divider().background(CheatPalette.divider)

                // Aim Line Row
                CheatRowView(
                    iconName: "pencil.line",
                    title: "Aim Line",
                    subtitle: "Line from crosshair to selected target",
                    isOn: $cheatState.aimLine
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CheatPalette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(CheatPalette.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - ESP Section
    private var espSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ESP")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(CheatPalette.sectionHeader)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Box ESP
                CheatRowView(
                    iconName: "square.dashed",
                    title: "Box ESP",
                    subtitle: "Enemy bounding box",
                    isOn: $cheatState.boxESP
                )

                Divider().background(CheatPalette.divider)

                // Line ESP
                CheatRowView(
                    iconName: "line.diagonal",
                    title: "Line ESP",
                    subtitle: "Tracer to enemy position",
                    isOn: $cheatState.lineESP
                )

                Divider().background(CheatPalette.divider)

                // Health Bar
                CheatRowView(
                    iconName: "heart.text.square",
                    title: "Health Bar",
                    subtitle: "Live enemy health",
                    isOn: $cheatState.healthBar
                )

                Divider().background(CheatPalette.divider)

                // Name Tag
                CheatRowView(
                    iconName: "tag.fill",
                    title: "Name Tag",
                    subtitle: "Show enemy name",
                    isOn: $cheatState.nameTag
                )

                Divider().background(CheatPalette.divider)

                // Distance Tag
                CheatRowView(
                    iconName: "ruler.fill",
                    title: "Distance Tag",
                    subtitle: "Show range in metres",
                    isOn: $cheatState.distanceTag
                )

                Divider().background(CheatPalette.divider)

                // Skeleton ESP
                CheatRowView(
                    iconName: "figure.stand",
                    title: "Skeleton ESP",
                    subtitle: "Bone-line overlay",
                    isOn: $cheatState.skeletonESP
                )

                Divider().background(CheatPalette.divider)

                // ESP Count
                CheatRowView(
                    iconName: "number",
                    title: "ESP Count",
                    subtitle: "Nearby enemy count (250m)",
                    isOn: $cheatState.espCount
                )

                Divider().background(CheatPalette.divider)

                // ESP Alert
                CheatRowView(
                    iconName: "exclamationmark.triangle.fill",
                    title: "ESP Alert",
                    subtitle: "360-degree enemy direction alerts (250m)",
                    isOn: $cheatState.espAlert
                )

                Divider().background(CheatPalette.divider)

                // ESP Color Row
                CheatRowView(
                    iconName: "paintpalette.fill",
                    title: "ESP Color",
                    subtitle: "Select ESP overlay color",
                    isOn: $cheatState.espColorEnabled
                )

                // Sub-settings for ESP Color
                if cheatState.espColorEnabled {
                    VStack(spacing: 12) {
                        // ESP Color indicator row
                        HStack {
                            Text("ESP Color")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(white: 0.7))
                            Spacer()
                            Circle()
                                .fill(cheatState.selectedColor.color)
                                .frame(width: 10, height: 10)
                            Text(cheatState.selectedColor.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(cheatState.selectedColor.color)
                        }

                        // Color Picker Dropdown Field (matching screenshot)
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
                                Text(cheatState.selectedColor.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.white)
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(Color(white: 0.6))
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .frame(height: 40)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(white: 0.12))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .strokeBorder(Color(white: 0.18), lineWidth: 1)
                            )
                        }

                        // Line thickness px slider
                        HStack(spacing: 12) {
                            Text("Line (thickness) px")
                                .font(.system(size: 13, weight: .regular))
                                .foregroundColor(Color(white: 0.7))
                                .layoutPriority(1)
                            CheatSlider(value: $cheatState.espLineThickness, range: 1.0...8.0, step: 0.5)
                        }
                    }
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CheatPalette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(CheatPalette.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - COMBAT Section
    private var combatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("COMBAT")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(CheatPalette.sectionHeader)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                // Fast Medkit
                CheatRowView(
                    iconName: "cross.case.fill",
                    title: "Fast Medkit",
                    subtitle: "Instant healing consumable speed",
                    isOn: $cheatState.fastMedkit
                )

                Divider().background(CheatPalette.divider)

                // No Recoil
                CheatRowView(
                    iconName: "shield.fill",
                    title: "No Recoil",
                    subtitle: "Reduce weapon recoil to 0%",
                    isOn: $cheatState.noRecoil
                )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(CheatPalette.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(CheatPalette.cardBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Bottom Floating Action Bar
    private var bottomActionBar: some View {
        HStack(spacing: 12) {
            // Main Inject / Uninject Cheat Button
            Button {
                if isInjected {
                    handleUninjectCheat()
                } else {
                    handleInjectCheat()
                }
            } label: {
                HStack(spacing: 8) {
                    if isInjecting {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: isInjected ? .white : CheatPalette.darkKnob))
                            .scaleEffect(0.85)
                        Text(isInjected ? "Đang gỡ bỏ..." : "Đang Inject...")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(isInjected ? .white : CheatPalette.darkKnob)
                    } else if isInjected {
                        Image(systemName: "trash.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.white)
                        Text("Uninject (\(selectedTarget.displayName))")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(CheatPalette.darkKnob)
                        Text("Inject (\(selectedTarget.displayName))")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(CheatPalette.darkKnob)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(isInjected ? Color(red: 0.85, green: 0.22, blue: 0.22) : CheatPalette.cream)
                )
                .shadow(color: Color.black.opacity(0.35), radius: 8, y: 3)
            }
            .buttonStyle(.plain)
            .disabled(isInjecting)

            // Reload / Reset Button
            Button(action: handleResetDefaults) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(CheatPalette.cardBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(CheatPalette.cardBorder, lineWidth: 1)
                        )
                        .frame(width: 52, height: 52)

                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                }
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 22)
        .background(
            LinearGradient(
                colors: [
                    CheatPalette.background.opacity(0.0),
                    CheatPalette.background.opacity(0.92),
                    CheatPalette.background
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Log Tab Content
    private var logContent: some View {
        VStack(spacing: 12) {
            // License & System Status Card
            licenseStatusCard
                .padding(.horizontal, 16)
                .padding(.top, 4)

            // Log Viewer Header
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(Color(red: 0.15, green: 0.9, blue: 0.35))
                        .frame(width: 6, height: 6)
                    Text("CONSOLE LOGS (\(appLog.entries.count))")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(white: 0.6))
                }

                Spacer()

                // Copy Logs Button
                Button {
                    let fullText = appLog.entries.joined(separator: "\n")
                    UIPasteboard.general.string = fullText
                    withAnimation { copiedLogToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation { copiedLogToast = false }
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
                    .background(Color(white: 0.18))
                    .clipShape(Capsule())
                }

                // Clear Logs Button
                Button {
                    appLog.entries.removeAll()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                        Text("Clear")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundColor(Color(red: 1.0, green: 0.4, blue: 0.4))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color(white: 0.18))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)

            // Scrollable Log Console
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        if appLog.entries.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "terminal")
                                    .font(.system(size: 28))
                                    .foregroundColor(Color(white: 0.3))
                                Text("Chưa có log hệ thống")
                                    .font(.system(size: 13, design: .monospaced))
                                    .foregroundColor(Color(white: 0.4))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
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
                    .padding(12)
                }
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(red: 0.04, green: 0.04, blue: 0.05))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(CheatPalette.cardBorder, lineWidth: 1)
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

    // MARK: - License Info Card in Log Tab
    private var licenseStatusCard: some View {
        VStack(spacing: 8) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 14))
                        .foregroundColor(Color(red: 0.15, green: 0.9, blue: 0.35))
                    Text("LICENSE HOẠT ĐỘNG")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }

                Spacer()

                // Change Key / Logout Button
                Button {
                    LicenseStore.shared.clear()
                } label: {
                    Text("Đổi Key")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(white: 0.8))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color(white: 0.2))
                        .clipShape(Capsule())
                }
            }

            Divider().background(Color(white: 0.18))

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("KEY ĐANG DÙNG")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                    Text(maskedKeyText(licenseStore.savedKey))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("THỜI GIAN CÒN LẠI")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundColor(Color(white: 0.5))
                    Text(remainingTimeText(licenseStore.expiresAt))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(Color(red: 0.15, green: 0.9, blue: 0.35))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(CheatPalette.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(CheatPalette.cardBorder, lineWidth: 1)
        )
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
                    self.injectionAlertText = "✅ Đã Inject Cheat thành công vào \(self.selectedTarget.displayName)!\n\nFile patch và cấu hình đã được nạp tự động. Bạn có thể mở game và trải nghiệm."
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
            self.injectionAlertText = "🗑️ Đã Uninject (xóa file patch) thành công khỏi \(self.selectedTarget.displayName)."
            self.showInjectionAlert = true
        }
    }

    private func handleResetDefaults() {
        let impact = UIImpactFeedbackGenerator(style: .rigid)
        impact.impactOccurred()
        cheatState.resetToDefaults()
    }

    private func logColor(for text: String) -> Color {
        if text.contains("[CHEAT]") || text.contains("Inject") {
            return Color(red: 0.15, green: 0.9, blue: 0.35)
        } else if text.contains("[AIM]") {
            return Color(red: 0.0, green: 0.85, blue: 1.0)
        } else if text.contains("[ESP]") {
            return Color(red: 1.0, green: 0.88, blue: 0.2)
        } else if text.contains("[COMBAT]") {
            return Color(red: 1.0, green: 0.35, blue: 0.45)
        } else if text.contains("Lỗi") || text.contains("failed") || text.contains("error") {
            return Color(red: 1.0, green: 0.3, blue: 0.3)
        }
        return Color(white: 0.8)
    }

    private func maskedKeyText(_ raw: String?) -> String {
        guard let key = raw, !key.isEmpty else { return "Chưa có key" }
        if key.count <= 8 { return key }
        let start = key.prefix(4)
        let end = key.suffix(4)
        return "\(start)-****-****-\(end)"
    }

    private func remainingTimeText(_ date: Date?) -> String {
        guard let date = date else { return "Vĩnh viễn" }
        let diff = date.timeIntervalSince(Date())
        if diff <= 0 { return "Đã hết hạn" }
        let hours = Int(diff) / 3600
        let days = hours / 24
        if days > 0 {
            return "\(days) ngày \(hours % 24)h"
        }
        let minutes = (Int(diff) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}
