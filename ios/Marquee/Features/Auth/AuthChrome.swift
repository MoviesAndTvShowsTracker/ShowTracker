import SwiftUI

struct AuthScaffold<Content: View>: View {
    @ScaledMetric(relativeTo: .largeTitle) private var titleFigure: CGFloat = 40
    @Environment(\.marqueeTheme) private var theme
    var kicker: String
    var title: String
    var subtitle: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                content()
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 36)
            .frame(maxWidth: 480)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollIndicators(.hidden)
        .marqueeCanvas()
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            BrandMark(size: 76)
                .shadow(color: theme.olive.opacity(0.2), radius: 18, y: 10)
            SectionKicker(text: kicker)
            Text(title)
                .font(.system(size: titleFigure, weight: .bold))
                .tracking(-1)
                .foregroundStyle(theme.olive)
            Text(subtitle)
                .font(.body)
                .foregroundStyle(theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.bottom, 28)
        .accessibilityElement(children: .combine)
    }
}

struct AuthTextField: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    @Binding var text: String
    var isSecure = false
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption.weight(.bold))
                .tracking(MarqueeType.labelTracking)
                .textCase(.uppercase)
                .foregroundStyle(theme.olive)
            Group {
                if isSecure {
                    SecureField("", text: $text)
                } else {
                    TextField("", text: $text)
                }
            }
            .keyboardType(keyboard)
            .textContentType(contentType)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(theme.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }
}

struct AuthOrDivider: View {
    @Environment(\.marqueeTheme) private var theme
    var label: String = "or with email"

    var body: some View {
        HStack(spacing: 12) {
            Capsule().fill(theme.border).frame(height: 1)
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.inkMuted)
                .fixedSize()
            Capsule().fill(theme.border).frame(height: 1)
        }
    }
}

struct ContinueWithAppleButton: View {
    var busy: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if busy {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "apple.logo")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white)
                    Text("Continue with Apple")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Color.black)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(PressablePosterStyle())
        .disabled(busy)
        .accessibilityLabel("Continue with Apple")
    }
}

struct ContinueWithGoogleButton: View {
    @Environment(\.marqueeTheme) private var theme
    var busy: Bool = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if busy {
                    ProgressView()
                        .tint(theme.ink)
                } else {
                    GoogleGMark()
                        .frame(width: 22, height: 22)
                    Text("Continue with Google")
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(theme.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: theme.olive.opacity(0.08), radius: 12, y: 6)
        }
        .buttonStyle(PressablePosterStyle())
        .disabled(busy)
        .accessibilityLabel("Continue with Google")
    }
}

/// Official four-color Google G, drawn as vectors so it stays sharp on every screen.
struct GoogleGMark: View {
    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / 48
            context.scaleBy(x: scale, y: scale)
            context.fill(Self.red, with: .color(Color(red: 234 / 255, green: 67 / 255, blue: 53 / 255)))
            context.fill(Self.blue, with: .color(Color(red: 66 / 255, green: 133 / 255, blue: 244 / 255)))
            context.fill(Self.yellow, with: .color(Color(red: 251 / 255, green: 188 / 255, blue: 5 / 255)))
            context.fill(Self.green, with: .color(Color(red: 52 / 255, green: 168 / 255, blue: 83 / 255)))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private static let red = Path { path in
        path.move(to: CGPoint(x: 24, y: 9.5))
        path.addCurve(to: CGPoint(x: 33.21, y: 13.1), control1: CGPoint(x: 27.54, y: 9.5), control2: CGPoint(x: 30.71, y: 10.72))
        path.addLine(to: CGPoint(x: 40.06, y: 6.25))
        path.addCurve(to: CGPoint(x: 24, y: 0), control1: CGPoint(x: 35.9, y: 2.38), control2: CGPoint(x: 30.47, y: 0))
        path.addCurve(to: CGPoint(x: 2.56, y: 13.22), control1: CGPoint(x: 14.62, y: 0), control2: CGPoint(x: 6.51, y: 5.38))
        path.addLine(to: CGPoint(x: 10.54, y: 19.41))
        path.addCurve(to: CGPoint(x: 24, y: 9.5), control1: CGPoint(x: 12.43, y: 13.72), control2: CGPoint(x: 17.74, y: 9.5))
        path.closeSubpath()
    }

    private static let blue = Path { path in
        path.move(to: CGPoint(x: 46.98, y: 24.55))
        path.addCurve(to: CGPoint(x: 46.6, y: 20), control1: CGPoint(x: 46.98, y: 22.98), control2: CGPoint(x: 46.83, y: 21.46))
        path.addLine(to: CGPoint(x: 24, y: 20))
        path.addLine(to: CGPoint(x: 24, y: 29.02))
        path.addLine(to: CGPoint(x: 36.94, y: 29.02))
        path.addCurve(to: CGPoint(x: 32.16, y: 36.2), control1: CGPoint(x: 36.36, y: 31.98), control2: CGPoint(x: 34.68, y: 34.5))
        path.addLine(to: CGPoint(x: 39.89, y: 42.2))
        path.addCurve(to: CGPoint(x: 46.98, y: 24.55), control1: CGPoint(x: 44.4, y: 38.02), control2: CGPoint(x: 46.98, y: 31.84))
        path.closeSubpath()
    }

    private static let yellow = Path { path in
        path.move(to: CGPoint(x: 10.53, y: 28.59))
        path.addCurve(to: CGPoint(x: 9.77, y: 24), control1: CGPoint(x: 10.05, y: 27.14), control2: CGPoint(x: 9.77, y: 25.6))
        path.addCurve(to: CGPoint(x: 10.53, y: 19.41), control1: CGPoint(x: 9.77, y: 22.4), control2: CGPoint(x: 10.04, y: 20.86))
        path.addLine(to: CGPoint(x: 2.55, y: 13.22))
        path.addCurve(to: CGPoint(x: 0, y: 24), control1: CGPoint(x: 0.92, y: 16.46), control2: CGPoint(x: 0, y: 20.12))
        path.addCurve(to: CGPoint(x: 2.56, y: 34.78), control1: CGPoint(x: 0, y: 27.88), control2: CGPoint(x: 0.92, y: 31.54))
        path.addLine(to: CGPoint(x: 10.53, y: 28.59))
        path.closeSubpath()
    }

    private static let green = Path { path in
        path.move(to: CGPoint(x: 24, y: 48))
        path.addCurve(to: CGPoint(x: 39.89, y: 42.19), control1: CGPoint(x: 30.48, y: 48), control2: CGPoint(x: 35.93, y: 45.87))
        path.addLine(to: CGPoint(x: 32.16, y: 36.19))
        path.addCurve(to: CGPoint(x: 24, y: 38.49), control1: CGPoint(x: 30.01, y: 37.64), control2: CGPoint(x: 27.24, y: 38.49))
        path.addCurve(to: CGPoint(x: 10.53, y: 28.58), control1: CGPoint(x: 17.74, y: 38.49), control2: CGPoint(x: 12.43, y: 34.27))
        path.addLine(to: CGPoint(x: 2.55, y: 34.77))
        path.addCurve(to: CGPoint(x: 24, y: 48), control1: CGPoint(x: 6.51, y: 42.62), control2: CGPoint(x: 14.62, y: 48))
        path.closeSubpath()
    }
}

struct AuthFooterLink: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.olive)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}
