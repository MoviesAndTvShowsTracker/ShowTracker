import SwiftUI

// MARK: - Library panel

/// Your show counts on the olive panel (your numbers, like Home's week panel).
struct TVLibraryPanel: View {
    let counts: LibraryCounts

    private var cells: [(TVLibraryView.LibraryTab, Int)] {
        [(.watching, counts.watching ?? 0), (.stopped, counts.paused ?? 0), (.finished, counts.completed ?? 0)]
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(cells.enumerated()), id: \.element.0) { i, cell in
                if i > 0 {
                    Rectangle().fill(MarqueeColor.saltGrey.opacity(0.18)).frame(width: 1, height: 40)
                }
                NavigationLink {
                    TVLibraryView(initialTab: cell.0)
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(cell.1)")
                            .font(.title2.weight(.bold))
                            .foregroundStyle(MarqueeColor.saltGrey)
                            .monospacedDigit()
                        Text(cell.0.label)
                            .font(.caption)
                            .foregroundStyle(MarqueeColor.saltGrey.opacity(0.75))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, i == 0 ? 0 : 16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(cell.1) \(cell.0.label.lowercased()). Opens your library.")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(OlivePanel(cornerRadius: 18))
        .padding(.horizontal, 20)
    }
}

// MARK: - On your services (one rail, a tab per service)

struct ProviderRailSection: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let kind: MediaKind
    let providers: [StreamingProviderOption]
    let region: String
    let refresh: Int
    @State private var selected: StreamingProviderOption?
    @State private var items: [MediaItem]?

    private var active: StreamingProviderOption? { selected ?? providers.first }

    var body: some View {
        if let active {
            VStack(alignment: .leading, spacing: 12) {
                CatalogShelfHeader(
                    title: "On your services",
                    seeAll: AnyView(
                        NavigationLink("All") {
                            MediaBrowseView(kind: kind, initialProviders: [active.rawValue])
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.olive)
                    )
                )

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(providers) { option in
                            providerTab(option, isOn: option == active)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 2)
                }

                if let items {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(items.prefix(14)) { item in
                                MediaNavLink(id: item.id, kind: kind) {
                                    PosterTile(title: item.displayTitle, posterPath: item.poster_path, width: 118, year: item.year)
                                }
                                .catalogQuickActions(item, kind: kind)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .id(active)
                    .transition(.opacity)
                } else {
                    RailSkeleton()
                }
            }
            .animation(reduceMotion ? nil : MarqueeMotion.micro, value: active)
            .task(id: "\(active.rawValue)#\(refresh)") { await load(active) }
        }
    }

    private func providerTab(_ option: StreamingProviderOption, isOn: Bool) -> some View {
        Button {
            selected = option
            Haptics.light()
        } label: {
            HStack(spacing: 8) {
                CachedAsyncImage(url: AppConfig.posterURL(path: option.logoPath, size: "w92"), contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text(option.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isOn ? MarqueeColor.saltGrey : theme.ink)
            }
            .padding(.leading, 6)
            .padding(.trailing, 14)
            .padding(.vertical, 6)
            .background(isOn ? theme.olive : theme.surfaceElevated, in: Capsule())
            .overlay(Capsule().stroke(isOn ? .clear : theme.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(option.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func load(_ option: StreamingProviderOption) async {
        let key = "\(kind == .movie ? "films" : "tv").provider.\(option.rawValue).\(region)"
        if let cached = ResponseCache.load([MediaItem].self, key: key, maxAge: 6 * 60 * 60), refresh == 0 {
            items = cached
            return
        }
        items = ResponseCache.load([MediaItem].self, key: key)
        let query = BrowseQuery(kind: kind, sort: .popular, providerIds: [option.rawValue], watchRegion: region)
        if let fresh = try? await TMDBService.discover(query).results {
            items = fresh
            ResponseCache.store(fresh, key: key)
        } else if items == nil {
            items = []
        }
    }
}

// MARK: - Queries

enum TVShelfQueries {
    private static func day(_ offset: Int) -> String { FilmShelfQueries.dayString(offset) }

    /// Popular shows with episodes out this week.
    static func airingThisWeek() async throws -> [MediaItem] {
        try await TMDBService.discoverTV([
            "sort_by": "popularity.desc",
            "air_date.gte": day(-2),
            "air_date.lte": day(7),
            "with_original_language": "en|ko|ja|es|fr|de",
            "vote_count.gte": "20",
        ])
    }

    /// Brand-new shows premiering soon.
    static func premieres() async throws -> [MediaItem] {
        try await TMDBService.discoverTV([
            "sort_by": "popularity.desc",
            "first_air_date.gte": day(1),
            "first_air_date.lte": day(75),
            "with_original_language": "en|ko|ja|es|fr|de",
        ])
        .filter { $0.poster_path != nil }
        .prefix(6)
        .sorted { ($0.first_air_date ?? "") < ($1.first_air_date ?? "") }
    }

    /// Miniseries with a real consensus: one season, start to finish.
    static func limitedSeries() async throws -> [MediaItem] {
        try await TMDBService.discoverTV([
            "sort_by": "popularity.desc",
            "with_type": "2",
            "vote_average.gte": "7.5",
            "vote_count.gte": "300",
        ])
    }

    /// Acclaimed scripted shows a few hundred people rated, not thousands.
    static func hiddenGems() async throws -> [MediaItem] {
        try await TMDBService.discoverTV([
            "sort_by": "vote_average.desc",
            "vote_average.gte": "7.8",
            "vote_count.gte": "250",
            "vote_count.lte": "900",
            "first_air_date.gte": "2008-01-01",
            "first_air_date.lte": day(-180),
            "with_genres": "18|80|9648|10765",
            "without_genres": "16|10762|10764|10767|10763|10766|99",
            "with_original_language": "en",
        ])
    }

    static func topRated() async throws -> [MediaItem] {
        try await TMDBService.discoverTV([
            "sort_by": "vote_average.desc",
            "vote_count.gte": "3000",
        ])
    }

    static func recommendations(for id: Int) async throws -> [MediaItem] {
        try await TMDBService.fetchPaged("tv/\(id)/recommendations").results
    }

    /// Trending faces, TV-known people first, topped up with the rest.
    static func faces() async throws -> [TrendingPerson] {
        let people = try await TMDBService.trendingPeople().filter {
            $0.profile_path != nil && ["Acting", "Directing"].contains($0.known_for_department ?? "")
        }
        let tv = people.filter { ($0.known_for ?? []).contains { $0.media_type == "tv" } }
        return tv + people.filter { p in !tv.contains { $0.id == p.id } }
    }
}
