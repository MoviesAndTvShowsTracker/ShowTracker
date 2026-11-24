import SwiftUI
import UIKit

/// Geometry shared with the static launch screen (`UILaunchScreen` → `LaunchMark`).
enum LaunchMetrics {
    /// Point size iOS draws `LaunchMark` at (its @2x/@3x pixels ÷ scale).
    static let markSide: CGFloat = 128
    /// Continuous-corner ratio baked into `LaunchMark` (iOS icon squircle).
    static let cornerRatio: CGFloat = 0.2237

    /// What iOS drew the static frame with — the system appearance, not the app's
    /// forced Light/Dark preference (a window override doesn't reach the screen).
    @MainActor
    static var systemStyle: UIUserInterfaceStyle {
        let scene = UIApplication.shared.connectedScenes.first { $0 is UIWindowScene } as? UIWindowScene
        return scene?.screen.traitCollection.userInterfaceStyle ?? .light
    }

    @MainActor
    static var launchBackground: Color {
        let ui = UIColor(named: "LaunchBackground") ?? .systemBackground
        return Color(uiColor: ui.resolvedColor(with: UITraitCollection(userInterfaceStyle: systemStyle)))
    }
}

/// Full-bleed launch colour, pixel-matched to the static frame. Sits beneath the
/// app while the reveal window grows, then is removed.
struct LaunchSplashBackground: View {
    @State private var color = LaunchMetrics.launchBackground

    var body: some View {
        color.ignoresSafeArea()
    }
}

/// The logo exactly where iOS drew it, a soft smoke aura settling behind it,
/// and — on reveal — the logo swelling and fading as the app opens through it.
struct LaunchSplashView: View {
    var revealed: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var settledIn = false

    var body: some View {
        ZStack {
            if !reduceMotion {
                aura
            }
            Image("LaunchMark")
                .resizable()
                .interpolation(.high)
                .frame(width: LaunchMetrics.markSide, height: LaunchMetrics.markSide)
                .offset(y: settledIn ? -4 : 0)
                .scaleEffect(settledIn ? 1.02 : 1)
                .scaleEffect(revealed && !reduceMotion ? 2.2 : 1)
                .opacity(revealed ? 0 : 1)
                .animation(.easeOut(duration: reduceMotion ? 0.25 : 0.3), value: revealed)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Marquee")
        .accessibilityIdentifier("launch.splash")
        .accessibilityHidden(revealed)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.smooth(duration: 1.2)) { settledIn = true }
        }
    }

    /// Olive and hibiscus haze — blurred once, animated by opacity and scale only.
    private var aura: some View {
        ZStack {
            Circle()
                .fill(MarqueeColor.oliveLeaf.opacity(0.35))
                .frame(width: 190, height: 190)
                .offset(x: -26, y: -18)
            Circle()
                .fill(MarqueeColor.hibiscus.opacity(0.28))
                .frame(width: 170, height: 170)
                .offset(x: 30, y: 24)
        }
        .blur(radius: 40)
        .compositingGroup()
        .opacity(settledIn && !revealed ? 1 : 0)
        .scaleEffect(settledIn ? 1 : 0.85)
        .animation(.easeOut(duration: 0.25), value: revealed)
    }
}

/// The app appears through a rounded-square window that grows from under the
/// logo to past the screen corners. Dropped entirely once settled so navigation
/// transitions never fight a parent mask or scale.
struct LaunchRevealMask: ViewModifier {
    var revealed: Bool
    var settled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if settled {
            content
        } else if reduceMotion {
            content.opacity(revealed ? 1 : 0)
        } else {
            content
                .scaleEffect(revealed ? 1 : 1.04)
                .mask {
                    GeometryReader { geo in
                        let full = hypot(geo.size.width, geo.size.height) * 1.05
                        // Starts just inside the logo so nothing peeks around it.
                        let side = revealed ? full : LaunchMetrics.markSide * 0.9
                        RoundedRectangle(cornerRadius: side * LaunchMetrics.cornerRatio, style: .continuous)
                            .frame(width: side, height: side)
                            .position(x: geo.size.width / 2, y: geo.size.height / 2)
                    }
                    .ignoresSafeArea()
                }
        }
    }
}
