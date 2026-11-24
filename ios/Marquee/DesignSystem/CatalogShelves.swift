import SwiftUI

/// Shelf shapes — only two intentional exceptions to the poster grid.
/// - `.posters`: default catalog rail (Letterboxd / JustWatch density)
/// - `.ranked`: same posters + rank (Netflix Top 10 — reason is ranking)
/// - `.cinema`: 16:9 cards for one “featured break” per screen (Apple TV WWDC19)
enum CatalogShelfStyle: Equatable {
    case posters
    case ranked
    case cinema

    var posterWidth: CGFloat { 118 }
    var landscapeWidth: CGFloat { 272 }
    var landscapeHeight: CGFloat { 153 }
    var spacing: CGFloat { self == .cinema ? 14 : 12 }
}

struct CatalogShelfHeader: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    var eyebrow: String? = nil
    var subtitle: String? = nil
    var seeAll: AnyView? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: 10) {
            VStack(alignment: .leading, spacing: 3) {
                if let eyebrow, !eyebrow.isEmpty {
                    Text(eyebrow)
                        .font(.caption2.weight(.bold))
                        .tracking(MarqueeType.labelTracking)
                        .textCase(.uppercase)
                        .foregroundStyle(theme.olive)
                }
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                }
            }
            Spacer(minLength: 8)
            if let seeAll {
                seeAll
            }
        }
        .padding(.horizontal, 20)
    }
}

struct CatalogShelf: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    let items: [MediaItem]
    let kind: MediaKind
    var style: CatalogShelfStyle = .posters
    var eyebrow: String? = nil
    var limit: Int = 14
    var seeAllLabel: String? = nil
    var seeAllDestination: (() -> AnyView)? = nil
    var subtitle: String? = nil
    var posterWidth: CGFloat? = nil
    /// Replaces the year under posters (e.g. release day).
    var caption: ((MediaItem) -> String?)? = nil

    private var slice: [MediaItem] {
        let cap = style == .ranked ? min(limit, 10) : limit
        return Array(items.prefix(cap))
    }

    var body: some View {
        if slice.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                CatalogShelfHeader(
                    title: title,
                    eyebrow: eyebrow,
                    subtitle: subtitle,
                    seeAll: seeAllView
                )
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: style.spacing) {
                        ForEach(Array(slice.enumerated()), id: \.element.id) { index, item in
                            MediaNavLink(id: item.id, kind: kind) {
                                switch style {
                                case .cinema:
                                    LandscapeShelfTile(
                                        title: item.displayTitle,
                                        backdropPath: item.backdrop_path,
                                        posterPath: item.poster_path,
                                        meta: item.year,
                                        width: style.landscapeWidth,
                                        height: style.landscapeHeight
                                    )
                                case .ranked:
                                    RankedPosterTile(
                                        rank: index + 1,
                                        title: item.displayTitle,
                                        posterPath: item.poster_path,
                                        year: item.year,
                                        width: style.posterWidth
                                    )
                                case .posters:
                                    PosterTile(
                                        title: item.displayTitle,
                                        posterPath: item.poster_path,
                                        width: posterWidth ?? style.posterWidth,
                                        year: caption?(item) ?? item.year
                                    )
                                }
                            }
                            .catalogQuickActions(item, kind: kind)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private var seeAllView: AnyView? {
        guard let seeAllLabel, let seeAllDestination else { return nil }
        return AnyView(
            NavigationLink {
                seeAllDestination()
            } label: {
                Text(seeAllLabel)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.olive)
            }
        )
    }
}

struct RankedPosterTile: View {
    @ScaledMetric(relativeTo: .largeTitle) private var rankFigure: CGFloat = 56
    @Environment(\.marqueeTheme) private var theme
    let rank: Int
    let title: String
    let posterPath: String?
    var year: String? = nil
    var width: CGFloat = 118

    var body: some View {
        HStack(alignment: .bottom, spacing: 0) {
            Text("\(rank)")
                .font(.system(size: rankFigure, weight: .heavy))
                .foregroundStyle(theme.ink.opacity(0.14))
                .offset(x: 6, y: 4)
                .accessibilityHidden(true)

            PosterTile(title: title, posterPath: posterPath, width: width, year: year)
                .offset(x: -10)
        }
        .accessibilityLabel("Number \(rank), \(title)")
    }
}

struct LandscapeShelfTile: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    let backdropPath: String?
    let posterPath: String?
    var meta: String? = nil
    var width: CGFloat = 272
    var height: CGFloat = 153

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            CachedAsyncImage(
                url: AppConfig.backdropURL(path: backdropPath ?? posterPath, size: "w780"),
                contentMode: .fill
            )
            .frame(width: width, height: height)
            .clipped()

            LinearGradient(
                colors: [.clear, .black.opacity(0.18), .black.opacity(0.75)],
                startPoint: .center,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                if let meta {
                    Text(meta)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.78))
                }
            }
            .padding(12)
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.border.opacity(0.35), lineWidth: 1)
        )
        .accessibilityLabel(meta.map { "\(title), \($0)" } ?? title)
    }
}

/// JustWatch-style “WatchBar” — pick services where discovery happens, not buried only in Browse.
struct ServicesWatchBar: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(AppPreferences.self) private var preferences
    var title: String = "Your services"

    private var subtitle: String {
        if preferences.preferredProviderIds.isEmpty {
            return "Tap the apps you subscribe to."
        }
        let count = preferences.preferredProviderIds.count
        return count == 1 ? "1 service selected" : "\(count) services selected"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            CatalogShelfHeader(
                title: title,
                eyebrow: nil
            )
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(theme.inkMuted)
                .padding(.horizontal, 20)

            StreamingFilterBar(selected: Bindable(preferences).preferredProviderIds)
        }
    }
}

struct GenreChipRail: View {
    @Environment(\.marqueeTheme) private var theme
    let kind: MediaKind
    var title: String = "Browse by genre"
    var genres: [BrowseGenre]

    var body: some View {
        if genres.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                CatalogShelfHeader(title: title)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(genres) { genre in
                            NavigationLink {
                                MediaBrowseView(kind: kind, initialGenreId: genre.id)
                            } label: {
                                Text(genre.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(theme.ink)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 11)
                                    .background(theme.surfaceElevated, in: Capsule(style: .continuous))
                                    .overlay(
                                        Capsule(style: .continuous)
                                            .stroke(theme.border, lineWidth: 1)
                                    )
                            }
                            .buttonStyle(PressablePosterStyle())
                        }
                        NavigationLink {
                            MediaBrowseView(kind: kind)
                        } label: {
                            HStack(spacing: 6) {
                                Text("All filters")
                                Image(systemName: "line.3.horizontal.decrease")
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.olive)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(theme.oliveSoft, in: Capsule(style: .continuous))
                        }
                        .buttonStyle(PressablePosterStyle())
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}

enum CatalogMood {
    struct Pack: Identifiable {
        let id: String
        let title: String
        let eyebrow: String
        let genreId: Int
    }

    static func filmPack(for date: Date = .now) -> Pack {
        let packs: [Pack] = [
            .init(id: "horror", title: "Horror", eyebrow: "Today’s pick", genreId: 27),
            .init(id: "comedy", title: "Comedy", eyebrow: "Today’s pick", genreId: 35),
            .init(id: "scifi", title: "Science fiction", eyebrow: "Today’s pick", genreId: 878),
            .init(id: "romance", title: "Romance", eyebrow: "Today’s pick", genreId: 10749),
            .init(id: "thriller", title: "Thriller", eyebrow: "Today’s pick", genreId: 53),
            .init(id: "action", title: "Action", eyebrow: "Today’s pick", genreId: 28),
            .init(id: "drama", title: "Drama", eyebrow: "Today’s pick", genreId: 18),
        ]
        let day = Calendar.current.component(.weekday, from: date)
        return packs[(day - 1) % packs.count]
    }

    static func tvPack(for date: Date = .now) -> Pack {
        let packs: [Pack] = [
            .init(id: "crime", title: "Crime", eyebrow: "Today’s pick", genreId: 80),
            .init(id: "comedy", title: "Comedy", eyebrow: "Today’s pick", genreId: 35),
            .init(id: "scifi", title: "Sci‑Fi & Fantasy", eyebrow: "Today’s pick", genreId: 10765),
            .init(id: "mystery", title: "Mystery", eyebrow: "Today’s pick", genreId: 9648),
            .init(id: "drama", title: "Drama", eyebrow: "Today’s pick", genreId: 18),
            .init(id: "action", title: "Action & Adventure", eyebrow: "Today’s pick", genreId: 10759),
            .init(id: "reality", title: "Reality", eyebrow: "Today’s pick", genreId: 10764),
        ]
        let day = Calendar.current.component(.weekday, from: date)
        return packs[(day - 1) % packs.count]
    }

    static func filmGenreChips() -> [BrowseGenre] {
        [
            .init(id: 27, name: "Horror"),
            .init(id: 35, name: "Comedy"),
            .init(id: 878, name: "Sci‑Fi"),
            .init(id: 53, name: "Thriller"),
            .init(id: 18, name: "Drama"),
            .init(id: 28, name: "Action"),
            .init(id: 10749, name: "Romance"),
            .init(id: 16, name: "Animation"),
        ]
    }

    static func tvGenreChips() -> [BrowseGenre] {
        [
            .init(id: 18, name: "Drama"),
            .init(id: 35, name: "Comedy"),
            .init(id: 80, name: "Crime"),
            .init(id: 10765, name: "Sci‑Fi"),
            .init(id: 9648, name: "Mystery"),
            .init(id: 10759, name: "Action"),
            .init(id: 16, name: "Animation"),
            .init(id: 10764, name: "Reality"),
        ]
    }
}
