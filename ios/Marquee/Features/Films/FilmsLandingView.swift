import SwiftUI

private struct FilmsLandingCache: Codable {
    var today: [MediaItem]
    var week: [MediaItem]
    var nowPlaying: [MediaItem]
}

struct FilmsLandingView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(AppPreferences.self) private var preferences

    @State private var today: [MediaItem] = []
    @State private var week: [MediaItem] = []
    @State private var nowPlaying: [MediaItem] = []
    @State private var moodPack = CatalogMood.filmPack()
    @State private var loading = true
    @State private var error: String?
    /// Bumped by pull-to-refresh; lazy shelves refetch when it changes.
    @State private var refresh = 0

    private var diary: FilmDiaryIndex { .shared }
    private var providers: Set<Int> { preferences.preferredProviderIds }
    private var region: String { preferences.resolvedWatchRegion }

    private var servicesTitle: String {
        let names = StreamingProviderOption.allCases
            .filter { providers.contains($0.rawValue) }
            .map(\.title)
        switch names.count {
        case 0: return "New to streaming"
        case 1: return "New on \(names[0])"
        default: return "New on your services"
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                LandingIdentityTitle(title: "Films")

                if loading && week.isEmpty {
                    LandingSkeleton()
                } else if week.isEmpty, let error {
                    ErrorStateView(message: error) { Task { await load() } }
                } else {
                    sections
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 8)
        }
        .marqueeCanvas()
        .marqueeLandingChrome()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MediaBrowseView(kind: .movie)
                } label: {
                    Label("Browse", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task {
            async let index: Void = diary.refresh()
            await load()
            await index
        }
        .refreshable {
            refresh += 1
            async let index: Void = diary.refresh(force: true)
            await load()
            await index
        }
    }

    @ViewBuilder
    private var sections: some View {
        if !today.isEmpty {
            HeroCarousel(items: today, kind: .movie)
        }

        ServicesWatchBar()

        CatalogShelf(title: "Top 10 this week", items: week, kind: .movie, style: .ranked, limit: 10)

        LazyShelf(
            key: "films.new.\(region).\(providers.sorted().map(String.init).joined(separator: "-"))",
            refresh: refresh,
            load: { [providers, region] in try await FilmShelfQueries.newOnStreaming(providers: providers, region: region) }
        ) { items in
            CatalogShelf(
                title: servicesTitle,
                items: items,
                kind: .movie,
                style: .cinema,
                limit: 12,
                seeAllLabel: "Browse",
                seeAllDestination: { [providers] in
                    AnyView(MediaBrowseView(kind: .movie, initialProviders: providers))
                }
            )
        }

        if let loved = diary.loved {
            LazyShelf(key: "films.recs.\(loved.id)", refresh: refresh, load: {
                try await FilmShelfQueries.recommendations(for: loved.id)
            }) { items in
                CatalogShelf(
                    title: "Because you loved \(loved.title)",
                    items: items.filter { diary.watchCounts[$0.id] == nil },
                    kind: .movie
                )
            }
        }

        CatalogShelf(title: "In theaters", items: nowPlaying, kind: .movie)

        LazyShelf(key: "films.coming", refresh: refresh, load: FilmShelfQueries.comingSoon) { items in
            ComingSoonSection(items: items)
        }

        LazyShelf(key: "films.faces.v2", refresh: refresh, load: FilmShelfQueries.faces) { people in
            FacesRail(people: people)
        }

        LazyShelf(key: "films.short.v2", refresh: refresh, load: FilmShelfQueries.shortAndGreat) { items in
            CatalogShelf(
                title: "Short and great",
                items: items,
                kind: .movie,
                subtitle: "Under 95 minutes",
                posterWidth: 96
            )
        }

        LazyShelf(key: "films.gems.v2", refresh: refresh, load: FilmShelfQueries.hiddenGems) { items in
            CatalogShelf(title: "Hidden gems", items: items, kind: .movie, subtitle: "Highly rated, rarely seen")
        }

        LazyShelf(key: "films.top.v2", refresh: refresh, load: FilmShelfQueries.topRated) { items in
            CatalogShelf(title: "Top rated", items: items, kind: .movie)
        }

        LazyShelf(key: "films.mood.\(moodPack.id)", refresh: refresh, load: { [moodPack, region] in
            try await TMDBService.discover(
                BrowseQuery(kind: .movie, sort: .popular, genreId: moodPack.genreId, watchRegion: region)
            ).results
        }) { items in
            CatalogShelf(
                title: moodPack.title,
                items: items,
                kind: .movie,
                seeAllLabel: "More",
                seeAllDestination: { [moodPack] in
                    AnyView(MediaBrowseView(kind: .movie, initialGenreId: moodPack.genreId))
                },
                subtitle: moodPack.eyebrow
            )
        }

        FilmBrowseCard(genres: CatalogMood.filmGenreChips())

        if let error {
            InlineErrorBanner(message: error) { Task { await load() } }
        }
    }

    /// First paint: only the three lists above the fold. Everything else loads lazily.
    private func load() async {
        error = nil
        if week.isEmpty, let cached = ResponseCache.load(FilmsLandingCache.self, key: "films.landing.v4") {
            today = cached.today
            week = cached.week
            nowPlaying = cached.nowPlaying
            loading = false
        }
        do {
            async let d = TMDBService.fetchPaged("trending/movie/day")
            async let w = TMDBService.fetchPaged("trending/movie/week")
            async let n = TMDBService.fetchPaged("movie/now_playing")
            let (dayList, weekList) = try await (d.results, w.results)
            let now = (try? await n.results) ?? []
            today = dayList
            week = weekList
            nowPlaying = now
            ResponseCache.store(
                FilmsLandingCache(today: dayList, week: weekList, nowPlaying: now),
                key: "films.landing.v4"
            )
        } catch {
            self.error = week.isEmpty ? error.localizedDescription : "Couldn’t refresh. Showing last saved films."
        }
        loading = false
    }
}

struct NavigationRail: View {
    let title: String
    let items: [MediaItem]
    let kind: MediaKind
    var style: CatalogShelfStyle = .posters
    var eyebrow: String? = nil

    var body: some View {
        CatalogShelf(
            title: title,
            items: items,
            kind: kind,
            style: style,
            eyebrow: eyebrow
        )
    }
}
