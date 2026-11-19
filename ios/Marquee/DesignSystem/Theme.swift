import SwiftUI

enum MarqueeColor {
    /// Soft parchment ground
    static let saltGrey = Color(hex: 0xE5E5DE)
    /// Brand green — use on surfaces, chips, kickers (must be visible, not only body text)
    static let deepOlive = Color(hex: 0x3D3B2E)
    /// Brighter olive for progress / completed / links (still in the olive family)
    static let oliveLeaf = Color(hex: 0x5C6B4A)
    static let hibiscus = Color(hex: 0xFF4F8B)
    static let surfaceElevatedLight = Color(hex: 0xF3F3EE)
    /// Dark canvas — matches DESIGN.md (true near-black olive, not murky brown)
    static let surfaceDark = Color(hex: 0x1C1B16)
    static let surfaceElevatedDark = Color(hex: 0x2A281F)
    static let inkDark = Color(hex: 0xF3F2EA)
    static let onAccent = Color.white
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

struct MarqueeTheme {
    let surface: Color
    let surfaceElevated: Color
    let ink: Color
    let inkMuted: Color
    let accent: Color
    let onAccent: Color
    /// Visible brand green for kickers, chips, progress, library
    let olive: Color
    let oliveSoft: Color
    let border: Color
    /// Loading bones — must read clearly on `surface` (oliveSoft is too faint for this).
    let skeleton: Color

    static func resolve(colorScheme: ColorScheme) -> MarqueeTheme {
        switch colorScheme {
        case .dark:
            return MarqueeTheme(
                surface: MarqueeColor.surfaceDark,
                surfaceElevated: MarqueeColor.surfaceElevatedDark,
                ink: MarqueeColor.inkDark,
                inkMuted: MarqueeColor.inkDark.opacity(0.72),
                accent: MarqueeColor.hibiscus,
                onAccent: MarqueeColor.onAccent,
                olive: Color(hex: 0xA3B389),
                oliveSoft: MarqueeColor.oliveLeaf.opacity(0.28),
                border: MarqueeColor.inkDark.opacity(0.16),
                skeleton: MarqueeColor.inkDark.opacity(0.14)
            )
        default:
            return MarqueeTheme(
                surface: MarqueeColor.saltGrey,
                surfaceElevated: MarqueeColor.surfaceElevatedLight,
                ink: MarqueeColor.deepOlive,
                inkMuted: MarqueeColor.deepOlive.opacity(0.55),
                accent: MarqueeColor.hibiscus,
                onAccent: MarqueeColor.onAccent,
                olive: MarqueeColor.deepOlive,
                oliveSoft: MarqueeColor.deepOlive.opacity(0.10),
                border: MarqueeColor.deepOlive.opacity(0.12),
                skeleton: Color(hex: 0xCDCBC0)
            )
        }
    }
}

private struct MarqueeThemeKey: EnvironmentKey {
    static let defaultValue = MarqueeTheme.resolve(colorScheme: .light)
}

extension EnvironmentValues {
    var marqueeTheme: MarqueeTheme {
        get { self[MarqueeThemeKey.self] }
        set { self[MarqueeThemeKey.self] = newValue }
    }
}

struct MarqueeThemeModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.marqueeTheme, MarqueeTheme.resolve(colorScheme: colorScheme))
            .tint(MarqueeColor.hibiscus)
    }
}

extension View {
    func marqueeTheme() -> some View {
        modifier(MarqueeThemeModifier())
    }
}

enum MarqueeMotion {
    static let micro = Animation.spring(response: 0.22, dampingFraction: 0.86)
    static let standard = Animation.spring(response: 0.32, dampingFraction: 0.84)
    static let press = Animation.spring(response: 0.18, dampingFraction: 0.78)
    /// Splash lifts off; content settles in.
    static let handoff = Animation.spring(response: 0.72, dampingFraction: 0.92)
    static let reveal = Animation.spring(response: 0.78, dampingFraction: 0.9)
    /// Splash zooms through into the app.
    static let zoom = Animation.spring(response: 0.86, dampingFraction: 0.92)
}

struct PressablePosterStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .opacity(configuration.isPressed ? 0.92 : 1)
            .animation(MarqueeMotion.press, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                if pressed { Haptics.prepare() }
            }
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(theme.accent.opacity(isEnabled ? 1 : 0.4))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(MarqueeMotion.micro, value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.marqueeTheme) private var theme

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(theme.olive)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(theme.oliveSoft)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(MarqueeMotion.micro, value: configuration.isPressed)
    }
}

struct OliveChip: View {
    @Environment(\.marqueeTheme) private var theme
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .tracking(0.6)
            .textCase(.uppercase)
            .foregroundStyle(theme.olive)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(theme.oliveSoft)
            .clipShape(Capsule())
    }
}

struct SectionKicker: View {
    @Environment(\.marqueeTheme) private var theme
    let text: String
    var accented: Bool = false

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(accented ? theme.accent : theme.olive)
    }
}

struct GlassCard<Content: View>: View {
    @Environment(\.marqueeTheme) private var theme
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
            }
    }
}
