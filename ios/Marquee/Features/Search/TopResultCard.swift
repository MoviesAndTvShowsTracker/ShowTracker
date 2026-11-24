import SwiftUI

/// The closest title match, shown wide above the grid.
struct TopResultCard: View {
    @Environment(\.marqueeTheme) private var theme
    let item: MediaItem
    let kind: MediaKind

    var body: some View {
        MediaNavLink(id: item.id, kind: kind) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: AppConfig.backdropURL(path: item.backdrop_path), contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .frame(height: 190)
                    .clipped()
                LinearGradient(colors: [.clear, .black.opacity(0.6)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 4) {
                    Text(item.displayTitle)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(meta)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(16)
            }
            .frame(height: 190)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
        .catalogQuickActions(item, kind: kind)
        .padding(.horizontal, 20)
        .accessibilityLabel("Top result: \(item.displayTitle), \(meta)")
    }

    private var meta: String {
        var parts = [kind == .tv ? "TV" : "Film"]
        if let year = item.year { parts.append(year) }
        if let vote = item.vote_average, vote > 0 { parts.append(String(format: "★ %.1f", vote)) }
        return parts.joined(separator: "  ")
    }
}
