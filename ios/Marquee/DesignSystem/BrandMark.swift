import SwiftUI

/// Theater-facade M with hibiscus marquee bulbs — Lobby Light identity.
struct BrandMark: View {
    var size: CGFloat = 64
    var showBackdrop: Bool = true

    var body: some View {
        Canvas { context, canvasSize in
            let s = min(canvasSize.width, canvasSize.height)
            let inset = s * 0.12
            let rect = CGRect(x: (canvasSize.width - s) / 2, y: (canvasSize.height - s) / 2, width: s, height: s)

            if showBackdrop {
                let bg = Path(roundedRect: rect, cornerRadius: s * 0.22)
                context.fill(bg, with: .color(MarqueeColor.saltGrey))
                let inner = rect.insetBy(dx: inset * 0.35, dy: inset * 0.35)
                context.fill(Path(roundedRect: inner, cornerRadius: s * 0.18), with: .color(MarqueeColor.surfaceElevatedLight))
            }

            let leftX = rect.minX + s * 0.28
            let rightX = rect.minX + s * 0.72
            let midX = rect.midX
            let topY = rect.minY + s * 0.38
            let bottomY = rect.minY + s * 0.72
            let peakY = rect.minY + s * 0.56
            let stroke = s * 0.09

            var m = Path()
            m.move(to: CGPoint(x: leftX, y: bottomY))
            m.addLine(to: CGPoint(x: leftX, y: topY))
            m.move(to: CGPoint(x: rightX, y: bottomY))
            m.addLine(to: CGPoint(x: rightX, y: topY))
            m.move(to: CGPoint(x: leftX, y: topY))
            m.addLine(to: CGPoint(x: midX, y: peakY))
            m.addLine(to: CGPoint(x: rightX, y: topY))

            context.stroke(
                m,
                with: .color(MarqueeColor.deepOlive),
                style: StrokeStyle(lineWidth: stroke, lineCap: .round, lineJoin: .round)
            )

            let bulbR = s * 0.035
            let bulbs: [CGPoint] = [
                CGPoint(x: leftX, y: rect.minY + s * 0.26),
                CGPoint(x: midX, y: rect.minY + s * 0.22),
                CGPoint(x: rightX, y: rect.minY + s * 0.26),
            ]
            for p in bulbs {
                let bulb = Path(ellipseIn: CGRect(x: p.x - bulbR, y: p.y - bulbR, width: bulbR * 2, height: bulbR * 2))
                context.fill(bulb, with: .color(MarqueeColor.hibiscus))
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Marquee")
    }
}

struct BrandMarkImage: View {
    var size: CGFloat = 64

    var body: some View {
        Image("MarqueeMark")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityLabel("Marquee")
    }
}
