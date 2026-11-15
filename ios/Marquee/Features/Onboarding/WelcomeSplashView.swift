import SwiftUI

struct WelcomeSplashView: View {
    @Environment(\.marqueeTheme) private var theme
    var onContinue: () -> Void

    private let steps: [(icon: String, title: String, text: String)] = [
        ("film", "Browse", "Find films and shows worth tracking."),
        ("checkmark.circle", "Log it", "Mark watched — films and episodes become your diary."),
        ("heart", "Save favorites", "Heart titles you love so they stay easy to find."),
    ]

    var body: some View {
        ZStack {
            theme.surface.ignoresSafeArea()
            // Soft olive wash so brand green is present from first screen
            Circle()
                .fill(theme.olive.opacity(0.14))
                .frame(width: 320, height: 320)
                .blur(radius: 60)
                .offset(x: 120, y: -220)
            Circle()
                .fill(theme.accent.opacity(0.12))
                .frame(width: 240, height: 240)
                .blur(radius: 50)
                .offset(x: -140, y: 280)

            VStack(alignment: .leading, spacing: 28) {
                Spacer(minLength: 24)

                BrandMark(size: 72)
                OliveChip(text: "Marquee")
                Text("Your watch diary")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundStyle(theme.olive)
                Text("Log what you watch, track TV episode by episode, and keep favorites in one quiet place.")
                    .font(.body)
                    .foregroundStyle(theme.inkMuted)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: 12) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 14) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(theme.oliveSoft)
                                    .frame(width: 44, height: 44)
                                Text("\(index + 1)")
                                    .font(.headline.weight(.bold))
                                    .foregroundStyle(theme.olive)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Label(step.title, systemImage: step.icon)
                                    .font(.headline)
                                    .foregroundStyle(theme.ink)
                                    .labelStyle(.titleAndIcon)
                                Text(step.text)
                                    .font(.subheadline)
                                    .foregroundStyle(theme.inkMuted)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .background(theme.surfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(theme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                Spacer()

                Button("Start your diary", action: onContinue)
                    .buttonStyle(PrimaryButtonStyle())
                Text("You can change nothing here — just browse and mark.")
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
                    .frame(maxWidth: .infinity)
            }
            .padding(24)
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
