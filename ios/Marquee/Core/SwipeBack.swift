import SwiftUI
import UIKit

extension UINavigationController: @retroactive UIGestureRecognizerDelegate {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.isEnabled = true
        interactivePopGestureRecognizer?.delegate = self
    }

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        viewControllers.count > 1
    }
}

/// Restores the interactive edge-swipe pop when the system back button is hidden.
struct EnableSwipeBack: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ uiViewController: Controller, context: Context) {}

    final class Controller: UIViewController, UIGestureRecognizerDelegate {
        override func loadView() {
            let v = UIView()
            v.backgroundColor = .clear
            v.isUserInteractionEnabled = false
            view = v
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard let pop = navigationController?.interactivePopGestureRecognizer else { return }
            pop.isEnabled = true
            pop.delegate = self
        }

        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            (navigationController?.viewControllers.count ?? 0) > 1
        }
    }
}

struct GlassBackButton: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .modifier(GlassCircleChrome())
        .accessibilityLabel("Back")
    }
}

private struct GlassCircleChrome: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .circle)
        } else {
            content.background(.ultraThinMaterial, in: Circle())
        }
    }
}

/// Full-bleed backdrop with a glass back control sitting on the artwork.
struct DetailHero: View {
    @Environment(\.marqueeTheme) private var theme
    let path: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            CachedAsyncImage(
                url: AppConfig.backdropURL(path: path),
                contentMode: .fill
            )
            LinearGradient(
                colors: [
                    Color.black.opacity(0.45),
                    Color.black.opacity(0.08),
                    .clear,
                    theme.surface.opacity(0.72),
                    theme.surface
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 320)
        .clipped()
        .contentShape(Rectangle())
        .accessibilityHidden(true)
    }
}

struct ExpandableText: View {
    @Environment(\.marqueeTheme) private var theme
    let text: String
    var lineLimit: Int = 4
    @State private var expanded = false

    private var needsToggle: Bool { text.count > 160 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.body)
                .foregroundStyle(theme.ink)
                .lineSpacing(3)
                .lineLimit(expanded ? nil : lineLimit)
                .animation(MarqueeMotion.micro, value: expanded)

            if needsToggle {
                Button(expanded ? "Show less" : "Read more") {
                    withAnimation(MarqueeMotion.micro) { expanded.toggle() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.olive)
            }
        }
    }
}
