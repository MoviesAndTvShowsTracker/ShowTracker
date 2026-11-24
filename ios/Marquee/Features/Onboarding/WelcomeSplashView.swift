import SwiftUI

struct WelcomeSplashView: View {
    @ScaledMetric(relativeTo: .largeTitle) private var titleFigure: CGFloat = 32
    @ScaledMetric(relativeTo: .largeTitle) private var glyphSize: CGFloat = 72
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var onContinue: () -> Void

    @State private var page = 0

    private let pages: [(icon: String, title: String, text: String, visual: String)] = [
        ("film.stack", "Browse the lobby", "Films and shows in quiet rails — posters first, noise last.", "rectangle.stack.fill"),
        ("checkmark.circle.fill", "Log as you go", "Mark a film or an episode and it becomes your diary.", "list.bullet.rectangle.portrait.fill"),
        ("heart.fill", "Keep favorites close", "Heart titles you love so they stay one tap away.", "heart.rectangle.fill"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, step in
                    pageView(step)
                        .tag(index)
                        .padding(.horizontal, 24)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(reduceMotion ? nil : MarqueeMotion.standard, value: page)

            HStack(spacing: 8) {
                ForEach(0..<pages.count, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? theme.accent : theme.olive.opacity(0.25))
                        .frame(width: index == page ? 22 : 8, height: 8)
                        .animation(reduceMotion ? nil : MarqueeMotion.micro, value: page)
                }
            }
            .padding(.bottom, 20)

            Button(page == pages.count - 1 ? "Start your diary" : "Next") {
                if page < pages.count - 1 {
                    withAnimation(reduceMotion ? nil : MarqueeMotion.standard) { page += 1 }
                    Haptics.light()
                } else {
                    Haptics.success()
                    onContinue()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .padding(.horizontal, 24)
            .padding(.bottom, 28)
        }
        .marqueeCanvas()
        .onAppear {
            OnboardingStore.hasSeenWelcome = true
        }
    }

    private func pageView(_ step: (icon: String, title: String, text: String, visual: String)) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer(minLength: 20)
            BrandMark(size: 64, lit: true)
            OliveChip(text: "Marquee")
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [theme.oliveSoft, theme.surfaceElevated],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 220)
                Image(systemName: step.visual)
                    .font(.system(size: glyphSize, weight: .semibold))
                    .foregroundStyle(theme.olive)
                    .symbolRenderingMode(.hierarchical)
            }
            Text(step.title)
                .font(.system(size: titleFigure, weight: .bold))
                .foregroundStyle(theme.olive)
            Text(step.text)
                .font(.body)
                .foregroundStyle(theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
    }
}

enum OnboardingStore {
    private static let key = "marquee.hasSeenWelcome"

    static var hasSeenWelcome: Bool {
        get { UserDefaults.standard.bool(forKey: key) }
        set { UserDefaults.standard.set(newValue, forKey: key) }
    }
}
