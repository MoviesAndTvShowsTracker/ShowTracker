import SwiftUI

struct BrandMark: View {
    var size: CGFloat = 64
    var lit: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glow = false

    var body: some View {
        Image("MarqueeMark")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .shadow(color: MarqueeColor.hibiscus.opacity(glow ? 0.55 : 0), radius: glow ? size * 0.28 : 0)
            .scaleEffect(glow ? 1.04 : 1)
            .accessibilityLabel("Marquee")
            .onAppear {
                guard lit else { return }
                if reduceMotion {
                    glow = true
                    return
                }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    glow = true
                }
            }
    }
}

