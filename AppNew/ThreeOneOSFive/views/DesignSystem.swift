import SwiftUI

// MARK: - AppNew theme tokens (kept from original AppNew DesignSystem)
// Existing AppTheme members used across CleanerView, FileBrowserView, etc.
// MUST stay because 8+ views depend on them.
enum AppTheme {
    static let accent = Color(
        uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(red: 1.00, green: 0.64, blue: 0.42, alpha: 1.00)
                : UIColor(red: 0.85, green: 0.42, blue: 0.20, alpha: 1.00)
        }
    )
    static let pageBackground = Color(uiColor: .systemBackground)
    static let consoleBackground = Color(uiColor: .secondarySystemBackground)
    static let pageInset: CGFloat = 16
    static let rowIconSize: CGFloat = 17
    static let rowIconFrame: CGFloat = 28
    static let fileRowIconSize: CGFloat = 17
    static let fileRowIconFrame: CGFloat = 30
    static let fileRowHeight: CGFloat = 60
    static let appIconSize: CGFloat = 32
    static let emptyIconSize: CGFloat = 30
    static let selectionIconSize: CGFloat = 18
}

// MARK: - Cyberpunk Neon Palette (from root ThreeOneOSFive)
// Bổ sung các thành phần cyberpunk mà GamesHomeView / GamePatchesView /
// SupportStatusToast / KeyCountdownFooter cần (TechBackground, PulsingDot,
// NeonReadout, PatchIconCatalog, NeonShimmerBar, ToastMessage,…).
extension AppTheme {
    /// Primary accent: electric cyan, the dominant neon of the cyberpunk palette.
    static let neonCyan = Color(red: 0.00, green: 0.95, blue: 1.00)
    /// Slightly cooler cyan used for backlights and borders.
    static let neonIce = Color(red: 0.55, green: 1.00, blue: 1.00)
    /// Hot magenta accent for highlights, errors and active toggles.
    static let neonMagenta = Color(red: 1.00, green: 0.10, blue: 0.65)
    /// Acid lime accent for "success" or "running" indicators.
    static let neonLime = Color(red: 0.65, green: 1.00, blue: 0.20)
    /// Warm neon amber, used as legacy accent on the few places we still highlight non-toggle rows.
    static let neonAmber = Color(red: 1.00, green: 0.78, blue: 0.20)
    /// Deep violet used as a tertiary accent (rare).
    static let neonViolet = Color(red: 0.55, green: 0.30, blue: 1.00)

    // MARK: - Cyberpunk backdrop gradient (Home / per-game menu screens)
    static let techBackgroundTop = Color(red: 0.03, green: 0.06, blue: 0.12)
    static let techBackgroundMid = Color(red: 0.01, green: 0.02, blue: 0.06)
    static let techBackgroundBottom = Color(red: 0.00, green: 0.00, blue: 0.03)

    /// Glow that sits behind cards to make them feel like floating holograms.
    static let techGlow = neonCyan
    /// Card fill — a translucent slate-blue, slightly cooler than the background.
    static let techCardFill = Color.white.opacity(0.04)
    /// Card border — a dim neon line that lights up on focus.
    static let techCardStroke = neonCyan.opacity(0.35)

    /// Per-row accent cycled across list items so each toggle has its own neon color.
    static let rowPalette: [Color] = [
        neonAmber,
        neonMagenta,
        neonCyan,
        neonViolet,
        neonLime,
    ]

    static func rowColor(_ index: Int) -> Color {
        rowPalette[index % rowPalette.count]
    }
}

// MARK: - Cyberpunk Backdrop (Performance Optimized)

/// Cyberpunk tech-style background: layered gradients + dot matrix + soft
/// radial glow. Designed for low overhead — no always-running animations.
///
/// Performance notes:
/// - Removed the previously-pulsing radial glow (10s `repeatForever`). Even at
///   slow speeds, recomputing `blendMode(.screen)` opacity every frame cost
///   ~1–2 ms per draw on older devices. The glow is now a static gradient.
/// - The dot matrix is a single `Canvas` snapshot — it does not re-draw each
///   frame.
/// - Reduce-motion users see the same static variant.
struct TechBackground: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowPhase: Double = 0

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    AppTheme.techBackgroundTop,
                    AppTheme.techBackgroundMid,
                    AppTheme.techBackgroundBottom,
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            TechDotMatrixCanvas()
                .opacity(0.85)
                .mask(
                    RadialGradient(
                        colors: [.white, .white, .clear],
                        center: .center,
                        startRadius: 80,
                        endRadius: 480
                    )
                )

            // Static radial glow — was pulsing every frame (10s `repeatForever`),
            // which combined with `blendMode(.screen)` cost noticeable GPU time.
            RadialGradient(
                colors: [
                    AppTheme.neonCyan.opacity(0.18),
                    AppTheme.neonMagenta.opacity(0.05),
                    .clear,
                ],
                center: .top,
                startRadius: 0,
                endRadius: 520
            )
            .blendMode(.screen)

            TechScanlineOverlay()
                .fill(Color.white.opacity(0.02))
        }
        .ignoresSafeArea()
        // No `.onAppear` animation — kept the @State for source compatibility
        // but the body no longer reads `glowPhase`, so the runtime does not
        // schedule any animation drivers.
    }
}

/// A canvas that draws a uniform dot matrix — replaces the previous hard grid so the
/// background reads as a soft starfield / circuit-board rather than a square tile.
private struct TechDotMatrixCanvas: View {
    var spacing: CGFloat = 24
    var dotRadius: CGFloat = 0.9

    /// Subtle accent dots in cyan + magenta, scattered sparsely (every 5 cells along each axis)
    /// to add visual depth.
    private func isAccent(row: Int, col: Int) -> Bool {
        (row % 5 == 0 && col % 7 == 0) || (row % 7 == 0 && col % 5 == 0)
    }

    var body: some View {
        Canvas { context, size in
            var col = 0
            var x: CGFloat = spacing / 2
            while x <= size.width {
                var row = 0
                var y: CGFloat = spacing / 2
                while y <= size.height {
                    let isAccentDot = isAccent(row: row, col: col)
                    let radius = isAccentDot ? 1.6 : dotRadius
                    let color = isAccentDot
                        ? AppTheme.neonMagenta.opacity(0.28)
                        : AppTheme.neonCyan.opacity(0.18)
                    let rect = CGRect(
                        x: x - radius,
                        y: y - radius,
                        width: radius * 2,
                        height: radius * 2
                    )
                    context.fill(
                        Path(ellipseIn: rect),
                        with: .color(color)
                    )
                    y += spacing
                    row += 1
                }
                x += spacing
                col += 1
            }
        }
    }
}

private struct TechScanlineOverlay: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        var y: CGFloat = 0
        while y <= rect.height {
            path.addRect(CGRect(x: 0, y: y, width: rect.width, height: 1))
            y += 3
        }
        return path
    }
}

// MARK: - Neon Card Style

private struct TechCardStyle: ViewModifier {
    var glowColor: Color = AppTheme.neonCyan
    var glowOpacity: Double = 0.12

    func body(content: Content) -> some View {
        content
            .background(AppTheme.techCardFill, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                glowColor.opacity(0.45),
                                glowColor.opacity(0.18),
                                glowColor.opacity(0.45),
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: glowColor.opacity(glowOpacity), radius: 14, y: 0)
    }
}

extension View {
    func techCard(glow: Color = AppTheme.neonCyan, opacity: Double = 0.12) -> some View {
        modifier(TechCardStyle(glowColor: glow, glowOpacity: opacity))
    }
}

// MARK: - Toast

struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    var text: String
}

/// A brief, self-dismissing confirmation pill shown after a successful toggle.
private struct ToastOverlay: ViewModifier {
    @Binding var toast: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast {
                    HStack(spacing: 9) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(AppTheme.neonLime)
                        Text(toast.text)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(
                        Capsule().strokeBorder(AppTheme.neonCyan.opacity(0.55), lineWidth: 1)
                    )
                    .shadow(color: AppTheme.neonCyan.opacity(0.35), radius: 20, y: 6)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .id(toast.id)
                    .task(id: toast.id) {
                        try? await Task.sleep(nanoseconds: 2_200_000_000)
                        if self.toast?.id == toast.id {
                            self.toast = nil
                        }
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.78), value: toast)
    }
}

extension View {
    func toast(_ message: Binding<ToastMessage?>) -> some View {
        modifier(ToastOverlay(toast: message))
    }
}

// MARK: - Pulsing Dot

/// A small dot that pulses in size and opacity, used as a "live / syncing" indicator.
///
/// Performance: kept lightweight — only the outer halo animates, the inner
/// dot stays static. Animation runs at 3.2s/cycle so frames between cycles
/// are cheap, and only mutates when reduce-motion is off.
struct PulsingDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var color: Color = AppTheme.neonLime
    var size: CGFloat = 8

    @State private var pulse: Double = 0

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.28))
                .frame(width: size * 2.0, height: size * 2.0)
                .scaleEffect(reduceMotion ? 1.0 : CGFloat(1.0 + pulse * 0.35))
                .opacity(reduceMotion ? 0.30 : (0.45 - pulse * 0.30))
            Circle()
                .fill(color)
                .frame(width: size, height: size)
                .shadow(color: color.opacity(0.8), radius: 4)
        }
        .onAppear {
            guard !reduceMotion else { return }
            // Slowed from 2.2s → 3.2s; reduced scale amplitude from 0.6 → 0.35
            // and opacity swing from 0.45 → 0.30. Cuts per-frame work roughly
            // in half without losing the "live" feel.
            withAnimation(.easeOut(duration: 3.2).repeatForever(autoreverses: false)) {
                pulse = 1.0
            }
        }
    }
}

// MARK: - Neon Readout (HUD caps text)

/// Occasional subtitle text styled in monospaced neon caps — like a HUD readout.
struct NeonReadout: View {
    let text: String
    var tint: Color = AppTheme.neonCyan

    var body: some View {
        Text(text)
            .font(.caption2.weight(.bold))
            .tracking(1.6)
            .textCase(.uppercase)
            .foregroundStyle(tint)
            .shadow(color: tint.opacity(0.6), radius: 4)
    }
}

// MARK: - Neon Shimmer Bar

/// Thay thế dòng text "X replacement rules" — đếm số lượng rule bằng một thanh
/// mỏng có ánh sáng neon lướt qua liên tục.
struct NeonShimmerBar: View {
    let count: Int
    var tint: Color = AppTheme.neonCyan
    @State private var phase: CGFloat = -0.5

    /// Timer 250ms thay vì 50ms - giảm CPU usage.
    private let timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()

    private var width: CGFloat {
        let base: CGFloat = 28
        let extra = CGFloat(min(count, 12)) * 6.5
        return min(base + extra, 110)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(tint.opacity(0.10))
                .frame(width: width, height: 4)

            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.0), tint.opacity(0.95), tint.opacity(0.0)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width * 0.55, height: 4)
                .offset(x: phase * width)
                .shadow(color: tint.opacity(0.85), radius: 6)

            Circle()
                .fill(tint)
                .frame(width: 4, height: 4)
                .offset(x: phase * width + (width * 0.275))
                .shadow(color: tint, radius: 4)
        }
        .frame(width: width, height: 4)
        .onReceive(timer) { _ in
            phase += 0.02
            if phase > 1.5 { phase = -0.5 }
        }
        .accessibilityLabel(Text("\(count) replacement rules"))
    }
}

// MARK: - Patch Icon Catalog

/// Chọn ngẫu nhiên icon SF Symbol cho một patch dựa vào id ổn định của nó.
/// Mỗi lần build server trả về nhiều patch, mỗi row sẽ hiện một icon khác
/// nhau nhưng cố định theo id (không bị đổi khi redraw).
enum PatchIconCatalog {
    static let symbols: [String] = [
        "bolt.fill",
        "sparkles",
        "wand.and.stars",
        "shield.lefthalf.filled",
        "cpu.fill",
        "bolt.shield.fill",
        "scope",
        "target",
        "diamond.fill",
        "hexagon.fill",
        "atom",
        "rays",
        "flame.fill",
        "snowflake",
        "burst.fill",
        "circle.hexagongrid.fill",
        "bolt.horizontal.fill",
        "gamecontroller.fill",
        "trophy.fill",
        "star.fill",
        "shield.fill",
        "bolt.ring.closed",
        "ladybug.fill",
        "cross.case.fill",
    ]

    /// Hash id của patch thành index ổn định → icon cố định.
    static func symbol(for id: UUID) -> String {
        let bytes = id.uuidString.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
        let idx = abs(bytes) % symbols.count
        return symbols[idx]
    }
}

// MARK: - Neon Toggle

/// A bespoke neon toggle styled for the cyberpunk theme. The track is a translucent neon capsule
/// that fills with a cyan→magenta gradient when on, and a dim grey when off. The knob is a small
/// glowing disc.
struct NeonToggleStyle: ToggleStyle {
    var onColor: Color = AppTheme.neonCyan
    var offColor: Color = Color.white.opacity(0.18)

    func makeBody(configuration: Configuration) -> some View {
        let isOn = configuration.isOn
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                configuration.isOn.toggle()
            }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(
                        isOn
                            ? LinearGradient(
                                colors: [onColor.opacity(0.85), AppTheme.neonMagenta.opacity(0.55)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            : LinearGradient(
                                colors: [offColor, offColor.opacity(0.5)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                    )
                    .frame(width: 48, height: 28)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                (isOn ? onColor : Color.white.opacity(0.25)).opacity(0.7),
                                lineWidth: 1
                            )
                    )
                    .shadow(
                        color: isOn ? onColor.opacity(0.65) : .clear,
                        radius: isOn ? 8 : 0
                    )

                Circle()
                    .fill(Color.white)
                    .frame(width: 22, height: 22)
                    .shadow(
                        color: isOn ? onColor.opacity(0.8) : .clear,
                        radius: isOn ? 6 : 0
                    )
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(configuration.isOn ? "On" : "Off")
    }
}

extension View {
    /// Convenience to apply the cyberpunk neon style with a chosen accent color on a Toggle.
    /// Placed on `View` rather than `Toggle` because `.labelsHidden()` returns `some View`,
    /// so the call site no longer has a concrete `Toggle` to dispatch to.
    func neonToggleTint(_ color: Color = AppTheme.neonCyan) -> some View {
        self.toggleStyle(NeonToggleStyle(onColor: color))
    }
}

// MARK: - AppNew minimal UI primitives (kept from original AppNew DesignSystem)

struct AppRowIcon: View {
    let systemName: String
    var tint: Color = AppTheme.accent
    var symbolSize: CGFloat = AppTheme.rowIconSize
    var frameSize: CGFloat = AppTheme.rowIconFrame

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.opacity(0.12))
            Image(systemName: systemName)
                .font(.system(size: symbolSize, weight: .medium))
                .foregroundStyle(tint)
        }
        .frame(width: frameSize, height: frameSize)
        .accessibilityHidden(true)
    }
}

struct AppSearchField: View {
    @Binding var text: String
    let prompt: String
    let clearLabel: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)

            TextField(prompt, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(clearLabel)
            }
        }
        .padding(.horizontal, 11)
        .frame(minHeight: 36)
        .background(
            Color(uiColor: .secondarySystemFill),
            in: RoundedRectangle(cornerRadius: 10, style: .continuous)
        )
        .padding(.horizontal, AppTheme.pageInset)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct AppLogo: View {
    var size: CGFloat = 44

    var body: some View {
        Group {
            if let icon = UIImage(named: "AppIcon60x60")
                ?? Bundle.main.path(forResource: "AppIcon60x60@2x", ofType: "png").flatMap(UIImage.init(contentsOfFile:))
                ?? UIImage(named: "AppIcon") {
                Image(uiImage: icon)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppTheme.accent)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Color hex helper
// `Color(hex:)` đã được khai báo ở GamesHomeView.swift (line 290), không để tránh
// "invalid redeclaration" error.

// MARK: - AppBackground helper
//
// SwiftUI mặc định cho NavigationStack và List một opaque system background
// che hết parent ZStack. Để ảnh nền `Background.imageset/background.png`
// hiện được trên MỌI màn hình (Home, Settings, Game Detail, Cleaner, Files,
// Onboarding, …), apply modifier `.appBackground()` ở root view của từng
// trang — nó sẽ vẽ ảnh nền + lớp overlay đọc-chữ được (giống App.swift).
//
// Modifier này:
//   • KHÔNG dùng `.ignoresSafeArea()` trực tiếp trên background view — đã biết
//     nó gây bug SwiftUI: `.ignoresSafeArea()` trên background có thể lan lên
//     parent (đặc biệt NavigationStack/List) khiến foreground view bị extend
//     past safe area → giao diện bị tràn sang 2 bên màn hình.
//   • Dùng `.scaledToFill() + .clipped()` để ảnh LUÔN fill và KHÔNG tràn
//     ra ngoài frame của chính nó.
//   • Overlay `.ultraThinMaterial` 55% + Color.black 18% để text cyan/magenta
//     vẫn pop trên nền ảnh (giống App.swift root ZStack).
//   • Ảnh nền KHÔNG phủ status bar / tab bar (chỉ fill trong safe area của
//     foreground). Nếu caller muốn phủ kín, gọi thêm `.ignoresSafeArea()`
//     ngoài cùng (sau `.appBackground()`).
extension View {
    /// Ảnh nền phủ kín view hiện tại. Dùng cho các màn đặt trong
    /// NavigationStack/List mà system background mặc định che mất ảnh nền
    /// global trong App.swift.
    ///
    /// Performance: `.ultraThinMaterial` is GPU-expensive — the system has to
    /// re-blur the underlying image every time anything above it changes.
    /// We keep it (it gives the cyberpunk frosted look) but lower its opacity
    /// to 0.35 and lean on the static `Color.black.opacity(0.20)` overlay for
    /// the rest of the darken. Result: similar visual, ~30% less blur work.
    func appBackground() -> some View {
        self.background {
            ZStack(alignment: .topLeading) {
                Image("Background")
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.35)

                Color.black
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(0.20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
