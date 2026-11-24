import SwiftUI

private struct TVLandingCache: Codable {
    var today: [MediaItem]
    var week: [MediaItem]
}

struct TVLandingView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(AppPreferences.self) private var preferences

    @State private var today: [MediaItem] = []
    @State private var week: [MediaItem] = []
    @State private var counts: LibraryCounts?
    @State private var moodPack = CatalogMood.tvPack()
    @State private var loading = true
    @State private var error: String?
    /// Bumped by pull-to-refresh; lazy shelves refetch when it changes.
    @State private var refresh = 0

    private var diary: TVDiaryIndex { .shared }
    private var providers: Set<Int> { preferences.preferredProviderIds }
    private var region: String { preferences.resolvedWatchRegion }

    /// Picked services, or the big four until the user picks.
    private var serviceTabs: [StreamingProviderOption] {
        let picked = StreamingProviderOption.allCases.filter { providers.contains($0.rawValue) }
        return picked.isEmpty ? [.netflix, .prime, .disney, .max] : picked
    }

    private var hasLibrary: Bool {
        guard let counts else { return false }
        return (counts.watching ?? 0) + (counts.paused ?? 0) + (counts.completed ?? 0) > 0
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 30) {
                LandingIdentityTitle(title: "TV")

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
                    MediaBrowseView(kind: .tv)
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
            HeroCarousel(items: today, kind: .tv)
        }

        if hasLibrary, let counts {
            TVLibraryPanel(counts: counts)
        }

        ServicesWatchBar()

        CatalogShelf(title: "Top 10 this week", items: week, kind: .tv, style: .ranked, limit: 10)

        LazyShelf(key: "tv.airing.week", refresh: refresh, load: TVShelfQueries.airingThisWeek) { items in
            CatalogShelf(title: "Airing this week", items: items, kind: .tv, style: .cinema, limit: 12)
        }

        if let loved = diary.loved {
            LazyShelf(key: "tv.recs.\(loved.id)", refresh: refresh, load: {
                try await TVShelfQueries.recommendations(for: loved.id)
            }) { items in
                CatalogShelf(
                    title: "Because you loved \(loved.title)",
                    items: items.filter { !diary.seen.contains($0.id) },
                    kind: .tv
                )
            }
        }

        ProviderRailSection(kind: .tv, providers: serviceTabs, region: region, refresh: refresh)

        LazyShelf(key: "tv.premieres", refresh: refresh, load: TVShelfQueries.premieres) { items in
            ComingSoonSection(items: items, kind: .tv, title: "Premieres")
        }

        LazyShelf(key: "tv.faces.v2", refresh: refresh, load: TVShelfQueries.faces) { people in
            FacesRail(people: people)
        }

        LazyShelf(key: "tv.limited", refresh: refresh, load: TVShelfQueries.limitedSeries) { items in
            CatalogShelf(
                title: "Limited series",
                items: items,
                kind: .tv,
                subtitle: "One season, start to finish",
                posterWidth: 96
            )
        }

        LazyShelf(key: "tv.gems.v3", refresh: refresh, load: TVShelfQueries.hiddenGems) { items in
            CatalogShelf(title: "Hidden gems", items: items, kind: .tv, subtitle: "Highly rated, rarely seen")
        }

        LazyShelf(key: "tv.top", refresh: refresh, load: TVShelfQueries.topRated) { items in
            CatalogShelf(title: "Top rated", items: items, kind: .tv)
        }

        LazyShelf(key: "tv.mood.\(moodPack.id)", refresh: refresh, load: { [moodPack, region] in
            try await TMDBService.discover(
                BrowseQuery(kind: .tv, sort: .popular, genreId: moodPack.genreId, watchRegion: region)
            ).results
        }) { items in
            CatalogShelf(
                title: moodPack.title,
                items: items,
                kind: .tv,
                seeAllLabel: "More",
                seeAllDestination: { [moodPack] in
                    AnyView(MediaBrowseView(kind: .tv, initialGenreId: moodPack.genreId))
                },
                subtitle: moodPack.eyebrow
            )
        }

        MediaBrowseCard(kind: .tv, genres: CatalogMood.tvGenreChips())

        if let error {
            InlineErrorBanner(message: error) { Task { await load() } }
        }
    }

    /// First paint: hero, Top 10 and library counts. Everything else loads lazily.
    private func load() async {
        error = nil
        if week.isEmpty, let cached = ResponseCache.load(TVLandingCache.self, key: "tv.landing.v6") {
            today = cached.today
            week = cached.week
            loading = false
        }
        async let summary = UITestingFixtures.isEnabled ? nil : try? DiaryService.librarySummary()
        do {
            async let d = TMDBService.fetchPaged("trending/tv/day")
            async let w = TMDBService.fetchPaged("trending/tv/week")
            let (dayList, weekList) = try await (d.results, w.results)
            today = dayList
            week = weekList
            ResponseCache.store(
                TVLandingCache(today: dayList, week: weekList),
                key: "tv.landing.v6"
            )
        } catch {
            self.error = week.isEmpty ? error.localizedDescription : "Couldn’t refresh. Showing last saved TV."
        }
        if let fresh = await summary?.counts { counts = fresh }
        loading = false
    }
}

struct LibraryShelf: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    let count: Int
    let items: [TrackingRecord]
    let tab: TVLibraryView.LibraryTab

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.ink)
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.olive)
                        .monospacedDigit()
                    Spacer()
                    NavigationLink {
                        TVLibraryView(initialTab: tab)
                    } label: {
                        Text("See all")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.olive)
                    }
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(items.prefix(14)) { item in
                            NavigationLink {
                                TVDetailView(tvId: Int(item.tvId) ?? 0)
                            } label: {
                                let progress = ShowProgress.from(track: item)
                                PosterTile(
                                    title: item.tvTitle ?? "Show",
                                    posterPath: item.posterPath,
                                    year: tab == .finished ? "Finished" : progress.episodeLine
                                )
                            }
                            .buttonStyle(PressablePosterStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
