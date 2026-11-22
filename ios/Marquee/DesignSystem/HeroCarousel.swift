import Combine
import SwiftUI

struct HeroCarousel: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(AppPreferences.self) private var preferences
    let items: [MediaItem]
    let kind: MediaKind
    @State private var page = 0
    private let timer = Timer.publish(every: 5.5, on: .main, in: .common).autoconnect()

    private var slides: [MediaItem] { Array(items.prefix(8)) }

    var body: some View {
        VStack(spacing: 10) {
            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.element.id) { index, item in
                    MediaNavLink(id: item.id, kind: kind) {
                        slide(item)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

            if slides.count > 1 {
                HStack(spacing: 6) {
                    ForEach(0..<slides.count, id: \.self) { i in
                        Capsule()
                            .fill(i == page ? theme.olive : theme.olive.opacity(0.25))
                            .frame(width: i == page ? 16 : 6, height: 6)
                    }
                }
                .animation(MarqueeMotion.micro, value: page)
            }
        }
        .padding(.horizontal, 20)
        .onReceive(timer) { _ in
            guard !reduceMotion, preferences.heroAutoplay, slides.count > 1 else { return }
            withAnimation(MarqueeMotion.standard) {
                page = (page + 1) % slides.count
            }
        }
    }

    private func slide(_ item: MediaItem) -> some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(
                url: AppConfig.backdropURL(path: item.backdrop_path ?? item.poster_path),
                contentMode: .fill
            )

            LinearGradient(
                colors: [.clear, Color.black.opacity(0.55)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text(kind == .movie ? "Film" : "TV")
                    .font(.caption.weight(.bold))
                    .tracking(1)
                    .textCase(.uppercase)
                    .foregroundStyle(.white.opacity(0.8))
                Text(item.displayTitle)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let year = item.year {
                    Text(year)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .accessibilityIdentifier("heroSlide")
    }
}
