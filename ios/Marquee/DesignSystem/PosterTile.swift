import SwiftUI

struct PosterTile: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    let posterPath: String?
    var width: CGFloat = 110
    var year: String? = nil
    /// Fixed caption band so rails don’t bounce when titles wrap unevenly.
    var captionLines: Int = 2

    private var posterHeight: CGFloat { width * 1.5 }
    private var captionHeight: CGFloat { year == nil ? 36 : 52 }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CachedAsyncImage(url: AppConfig.posterURL(path: posterPath))
                .frame(width: width, height: posterHeight)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .accessibilityLabel(title)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(captionLines)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                if let year {
                    Text(year)
                        .font(.caption2)
                        .foregroundStyle(theme.inkMuted)
                        .lineLimit(1)
                }
            }
            .frame(width: width, height: captionHeight, alignment: .topLeading)
        }
        .frame(width: width, alignment: .top)
        .accessibilityIdentifier("posterTile")
    }
}

struct PosterGridTile: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    let posterPath: String?
    var caption: String? = nil
    var progress: Double? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Color.clear
                .aspectRatio(2 / 3, contentMode: .fit)
                .overlay {
                    CachedAsyncImage(url: AppConfig.posterURL(path: posterPath))
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(alignment: .bottom) {
                    if let progress {
                        ProgressTrack(progress: progress)
                            .padding(7)
                    }
                }
                .accessibilityLabel(title)

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .topLeading)

            if let caption {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(1)
            }
        }
        .accessibilityIdentifier("posterTile")
    }
}

struct PosterGridSection: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    let items: [MediaItem]
    let kind: MediaKind
    var limit: Int = 6

    private let columns = [
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10),
        GridItem(.flexible(), spacing: 10)
    ]

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(items.prefix(limit)) { item in
                        MediaNavLink(id: item.id, kind: kind) {
                            PosterGridTile(
                                title: item.displayTitle,
                                posterPath: item.poster_path,
                                caption: item.year
                            )
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct CastBubble: View {
    @Environment(\.marqueeTheme) private var theme
    let name: String
    let character: String?
    let profilePath: String?
    var diameter: CGFloat = 72

    var body: some View {
        VStack(spacing: 8) {
            CachedAsyncImage(url: AppConfig.posterURL(path: profilePath, size: "w185"))
                .frame(width: diameter, height: diameter)
                .clipShape(Circle())
                .overlay(Circle().stroke(theme.border, lineWidth: 1))

            VStack(spacing: 2) {
                Text(name)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(character ?? " ")
                    .font(.caption2)
                    .foregroundStyle(theme.inkMuted)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .opacity(character == nil ? 0 : 1)
            }
            .frame(width: diameter + 8, height: 52, alignment: .top)
        }
        .frame(width: diameter + 8, alignment: .top)
    }
}

struct PosterRail: View {
    let title: String
    let items: [MediaItem]
    var onSelect: (MediaItem) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(MarqueeColor.deepOlive)
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: 12) {
                    ForEach(items) { item in
                        Button {
                            onSelect(item)
                        } label: {
                            PosterTile(
                                title: item.displayTitle,
                                posterPath: item.poster_path,
                                year: item.year
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }
}

struct StarRatingView: View {
    @Binding var rating: Double
    var maxStars: Int = 5
    var editable: Bool = true
    var size: Font = .title3

    var body: some View {
        HStack(spacing: 6) {
            ForEach(1...maxStars, id: \.self) { star in
                let full = Double(star)
                let half = full - 0.5
                ZStack {
                    Image(systemName: starSymbol(for: full))
                        .font(size)
                        .foregroundStyle(MarqueeColor.hibiscus)
                    if editable {
                        HStack(spacing: 0) {
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    rating = half
                                    Haptics.light()
                                }
                            Color.clear
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    rating = full
                                    Haptics.light()
                                }
                        }
                    }
                }
                .frame(minWidth: 28, minHeight: 28)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating \(String(format: "%g", rating)) of \(maxStars)")
        .accessibilityAdjustableAction { direction in
            guard editable else { return }
            switch direction {
            case .increment: rating = min(Double(maxStars), rating + 0.5)
            case .decrement: rating = max(0, rating - 0.5)
            @unknown default: break
            }
        }
    }

    private func starSymbol(for full: Double) -> String {
        if rating >= full - 0.01 { return "star.fill" }
        if rating >= full - 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

enum GridDensity: Int, CaseIterable, Identifiable {
    case cozy = 3
    case compact = 4
    var id: Int { rawValue }
    var label: String { rawValue == 3 ? "3" : "4" }
}

struct GridDensityToggle: View {
    @Environment(\.marqueeTheme) private var theme
    @Binding var density: GridDensity

    var body: some View {
        Button {
            withAnimation(MarqueeMotion.micro) {
                density = density == .cozy ? .compact : .cozy
            }
            Haptics.light()
        } label: {
            Image(systemName: density == .cozy ? "square.grid.2x2" : "square.grid.3x3")
                .font(.body.weight(.medium))
                .foregroundStyle(theme.olive)
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(density == .cozy ? "Show denser grid" : "Show larger posters")
    }
}

struct MediaNavLink<Label: View>: View {
    let id: Int
    let kind: MediaKind
    @ViewBuilder var label: () -> Label
    @Environment(\.marqueePosterNamespace) private var posterNamespace
    /// Unique per poster instance so the same title in Trending + Popular
    /// (or a carousel) zooms from the card you tapped — not a sibling source.
    @State private var sourceToken = UUID()

    private var transitionID: String {
        "\(kind == .movie ? "m" : "t")-\(id)-\(sourceToken.uuidString)"
    }

    var body: some View {
        NavigationLink {
            switch kind {
            case .movie:
                MovieDetailView(movieId: id)
                    .modifier(PosterZoomTransition(id: transitionID, namespace: posterNamespace))
            case .tv:
                TVDetailView(tvId: id)
                    .modifier(PosterZoomTransition(id: transitionID, namespace: posterNamespace))
            }
        } label: {
            label()
                .modifier(PosterMatchedSource(id: transitionID, namespace: posterNamespace))
        }
        .buttonStyle(PressablePosterStyle())
    }
}

private struct PosterZoomTransition: ViewModifier {
    let id: String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

private struct PosterMatchedSource: ViewModifier {
    let id: String
    let namespace: Namespace.ID?

    func body(content: Content) -> some View {
        if let namespace {
            content.matchedTransitionSource(id: id, in: namespace)
        } else {
            content
        }
    }
}

private struct MarqueePosterNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    var marqueePosterNamespace: Namespace.ID? {
        get { self[MarqueePosterNamespaceKey.self] }
        set { self[MarqueePosterNamespaceKey.self] = newValue }
    }
}
