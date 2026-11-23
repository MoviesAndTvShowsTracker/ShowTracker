import SwiftUI

/// Soft color washes that slowly roam the canvas.
struct AmbientBlobs: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @Environment(AppPreferences.self) private var preferences

    var body: some View {
        Group {
            if preferences.blobsEnabled {
                TimelineView(.animation(minimumInterval: shouldMove ? 1 / 24 : 120)) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    Canvas { ctx, size in
                        for spec in specs(size: size, light: colorScheme != .dark) {
                            paint(ctx, spec: spec, t: t, moving: shouldMove)
                        }
                    }
                }
                .blur(radius: 42)
                .blendMode(colorScheme == .dark ? .screen : .multiply)
                .opacity(colorScheme == .dark ? 0.88 : 0.78)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }

    private var shouldMove: Bool {
        scenePhase == .active && !reduceMotion
    }

    private func specs(size: CGSize, light: Bool) -> [BlobSpec] {
        let olive = MarqueeColor.oliveLeaf
        let pink = MarqueeColor.hibiscus
        return [
            BlobSpec(
                color: olive,
                opacity: light ? 0.58 : 0.26,
                radius: 168,
                origin: CGPoint(x: size.width * 0.16, y: size.height * 0.18),
                amplitude: CGSize(width: size.width * 0.28, height: size.height * 0.22),
                period: CGSize(width: 14, height: 19),
                phase: 0.4
            ),
            BlobSpec(
                color: pink,
                opacity: light ? 0.26 : 0.52,
                radius: 150,
                origin: CGPoint(x: size.width * 0.84, y: size.height * 0.2),
                amplitude: CGSize(width: size.width * 0.26, height: size.height * 0.24),
                period: CGSize(width: 17, height: 13),
                phase: 1.7
            ),
            BlobSpec(
                color: olive,
                opacity: light ? 0.42 : 0.22,
                radius: 148,
                origin: CGPoint(x: size.width * 0.18, y: size.height * 0.82),
                amplitude: CGSize(width: size.width * 0.24, height: size.height * 0.2),
                period: CGSize(width: 16, height: 21),
                phase: 2.8
            ),
            BlobSpec(
                color: pink,
                opacity: light ? 0.22 : 0.4,
                radius: 136,
                origin: CGPoint(x: size.width * 0.86, y: size.height * 0.78),
                amplitude: CGSize(width: size.width * 0.22, height: size.height * 0.22),
                period: CGSize(width: 12, height: 18),
                phase: 0.9
            ),
            BlobSpec(
                color: light ? olive : pink,
                opacity: light ? 0.2 : 0.24,
                radius: 120,
                origin: CGPoint(x: size.width * 0.5, y: size.height * 0.48),
                amplitude: CGSize(width: size.width * 0.34, height: size.height * 0.3),
                period: CGSize(width: 22, height: 15),
                phase: 3.4
            )
        ]
    }

    private func paint(_ ctx: GraphicsContext, spec: BlobSpec, t: TimeInterval, moving: Bool) {
        let center = spec.center(at: t, moving: moving)
        let rect = CGRect(
            x: center.x - spec.radius,
            y: center.y - spec.radius,
            width: spec.radius * 2,
            height: spec.radius * 2
        )
        ctx.fill(
            Path(ellipseIn: rect),
            with: .radialGradient(
                Gradient(colors: [
                    spec.color.opacity(spec.opacity),
                    spec.color.opacity(spec.opacity * 0.4),
                    .clear
                ]),
                center: center,
                startRadius: 0,
                endRadius: spec.radius
            )
        )
    }
}

private struct BlobSpec {
    var color: Color
    var opacity: Double
    var radius: CGFloat
    var origin: CGPoint
    var amplitude: CGSize
    var period: CGSize
    var phase: Double

    func center(at t: TimeInterval, moving: Bool) -> CGPoint {
        guard moving else { return origin }
        return CGPoint(
            x: origin.x + CGFloat(sin(t / period.width + phase)) * amplitude.width,
            y: origin.y + CGFloat(cos(t / period.height + phase * 0.7)) * amplitude.height
        )
    }
}

private struct MarqueeCanvasModifier: ViewModifier {
    @Environment(\.marqueeTheme) private var theme

    func body(content: Content) -> some View {
        content
            .background(theme.surface)
            .containerBackground(theme.surface, for: .navigation)
            // Let the system scroll-edge material do the work — a forced
            // toolbarBackground reads as a hard slab over posters (esp. iOS 27
            // hard default). Soft edge = Music / Apple TV style fade.
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollContentBackground(.hidden)
    }
}

/// Film / TV detail — hero underlaps the status bar.
/// Same soft top edge as Films/TV landings (`e32c539`); system bar stays hidden
/// so custom back/share chrome can sit on the blur.
///
/// Search handoff (iOS 18+): if the previous screen still has an active
/// `.searchable` session, a *static* `.toolbar(.hidden)` is ignored and the
/// soft scroll-edge dies with it — buttons sit too low and the top looks
/// unblurred. Films/TV never hit this (no searchable). Fix: start visible,
/// then hide on appear (known SwiftUI workaround).
private struct MarqueeDetailCanvasModifier: ViewModifier {
    @Environment(\.marqueeTheme) private var theme
    @State private var hideBar = false

    func body(content: Content) -> some View {
        content
            .background(theme.surface)
            .containerBackground(.clear, for: .navigation)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarVisibility(hideBar ? .hidden : .automatic, for: .navigationBar)
            .toolbar(hideBar ? .hidden : .automatic, for: .navigationBar)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .scrollEdgeEffectStyle(.soft, for: .bottom)
            .onAppear {
                // Deferred — a static `.hidden` is ignored after an active search push.
                hideBar = true
            }
    }
}

extension View {
    func marqueeCanvas() -> some View {
        modifier(MarqueeCanvasModifier())
    }

    func marqueeDetailCanvas() -> some View {
        modifier(MarqueeDetailCanvasModifier())
    }

    /// Tab-root landings (Films / TV).
    /// Large identity lives in the scroll (`LandingIdentityTitle`) so it leaves
    /// with the content — the tab already names the section. Soft system edge
    /// + a light progressive veil (Music / Apple TV) instead of a hard slab.
    func marqueeLandingChrome() -> some View {
        modifier(MarqueeLandingChromeModifier())
    }
}

/// In-scroll section name for Films / TV — leaves with the content.
struct LandingIdentityTitle: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String

    var body: some View {
        Text(title)
            .font(.largeTitle.weight(.bold))
            .foregroundStyle(theme.ink)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct MarqueeLandingChromeModifier: ViewModifier {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var veil: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                max(0, geometry.contentOffset.y + geometry.contentInsets.top)
            } action: { _, y in
                let next = min(1, y / 56)
                if abs(next - veil) > 0.02 { veil = next }
            }
            .overlay(alignment: .top) {
                LinearGradient(
                    stops: [
                        .init(color: theme.surface.opacity(0.78 * veil), location: 0),
                        .init(color: theme.surface.opacity(0.36 * veil), location: 0.55),
                        .init(color: theme.surface.opacity(0), location: 1),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 96)
                .ignoresSafeArea(edges: .top)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .animation(reduceMotion ? nil : MarqueeMotion.micro, value: veil)
            }
    }
}
