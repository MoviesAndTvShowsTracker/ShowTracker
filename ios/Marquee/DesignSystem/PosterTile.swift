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
        HStack(spacing: 8) {
            ForEach(1...maxStars, id: \.self) { star in
                let value = Double(star)
                Button {
                    guard editable else { return }
                    rating = value
                    Haptics.light()
                } label: {
                    Image(systemName: rating >= value - 0.25 ? "star.fill" : "star")
                        .font(size)
                        .foregroundStyle(MarqueeColor.hibiscus)
                }
                .buttonStyle(.plain)
                .disabled(!editable)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Rating \(Int(rating)) of \(maxStars)")
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
    @Namespace private var zoom
    let id: Int
    let kind: MediaKind
    @ViewBuilder var label: () -> Label

    var body: some View {
        NavigationLink {
            Group {
                switch kind {
                case .movie: MovieDetailView(movieId: id)
                case .tv: TVDetailView(tvId: id)
                }
            }
            .navigationTransition(.zoom(sourceID: id, in: zoom))
        } label: {
            label()
        }
        .matchedTransitionSource(id: id, in: zoom)
        .buttonStyle(PressablePosterStyle())
    }
}
