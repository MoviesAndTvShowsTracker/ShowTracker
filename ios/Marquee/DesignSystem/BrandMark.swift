import SwiftUI

struct BrandMark: View {
    var size: CGFloat = 64

    var body: some View {
        Image("MarqueeMark")
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
            .accessibilityLabel("Marquee")
    }
}

struct BrandMarkImage: View {
    var size: CGFloat = 64

    var body: some View {
        BrandMark(size: size)
    }
}
