import SwiftUI

/// Liquid Glass helpers for iOS 26. Glass stays on chrome only.
enum GlassChrome {
    @ViewBuilder
    static func regular<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if #available(iOS 26.0, *) {
            content()
                .glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content()
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

struct GlassFAB: View {
    let systemName: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(MarqueeColor.deepOlive)
                .frame(width: 56, height: 56)
        }
        .modifier(GlassFABModifier())
    }
}

private struct GlassFABModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular.interactive(), in: .circle)
        } else {
            content.background(.ultraThinMaterial, in: Circle())
        }
    }
}
