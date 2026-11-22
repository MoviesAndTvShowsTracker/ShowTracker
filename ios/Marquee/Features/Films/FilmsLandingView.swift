import SwiftUI

private struct FilmsLandingCache: Codable {
    var trending: [MediaItem]
    var nowPlaying: [MediaItem]
    var upcoming: [MediaItem]
    var topRated: [MediaItem]
    var onServices: [MediaItem]
    var mood: [MediaItem]
    var moodId: String
}

struct FilmsLandingView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(AppPreferences.self) private var preferences

    @State private var trending: [MediaItem] = []
    @State private var nowPlaying: [MediaItem] = []
    @State private var upcoming: [MediaItem] = []
    @State private var topRated: [MediaItem] = []
    @State private var onServices: [MediaItem] = []
    @State private var moodItems: [MediaItem] = []
    @State private var moodPack = CatalogMood.filmPack()
    @State private var loading = true
    @State private var error: String?
    @State private var loadToken = 0

    private var hasServices: Bool { !preferences.preferredProviderIds.isEmpty }

    private var servicesTitle: String {
        let names = StreamingProviderOption.allCases
            .filter { preferences.preferredProviderIds.contains($0.rawValue) }
            .map(\.title)
        if names.isEmpty { return "On streaming" }
        if names.count == 1 { return "On \(names[0])" }
        if names.count == 2 { return "On \(names[0]) & \(names[1])" }
        return "On your services"
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if loading && trending.isEmpty {
                    LandingSkeleton()
                } else if trending.isEmpty, let error {
                    ErrorStateView(message: error) {
                        Task { await load() }
                    }
                } else {
                    if !trending.isEmpty {
                        HeroCarousel(items: trending, kind: .movie)
                    }

                    ServicesWatchBar()

                    // Ranked = only intentional “different” poster treatment.
                    CatalogShelf(
                        title: "Top 10 trending",
                        items: trending,
                        kind: .movie,
                        style: .ranked,
                        eyebrow: "This week",
                        limit: 10
                    )

                    // Cinema = only landscape break on this page.
                    if hasServices {
                        CatalogShelf(
                            title: servicesTitle,
                            items: onServices,
                            kind: .movie,
                            style: .cinema,
                            eyebrow: "Wide picks · your subscriptions",
                            limit: 12,
                            seeAllLabel: "Browse",
                            seeAllDestination: {
                                AnyView(
                                    MediaBrowseView(
                                        kind: .movie,
                                        initialProviders: preferences.preferredProviderIds
                                    )
                                )
                            }
                        )
                    }

                    CatalogShelf(
                        title: "In theaters",
                        items: nowPlaying,
                        kind: .movie,
                        style: .posters,
                        eyebrow: "Now playing",
                        limit: 14
                    )

                    CatalogShelf(
                        title: "Coming soon",
                        items: upcoming,
                        kind: .movie,
                        style: .posters,
                        eyebrow: "Upcoming",
                        limit: 14
                    )

                    CatalogShelf(
                        title: "Top rated",
                        items: topRated,
                        kind: .movie,
                        style: .posters,
                        eyebrow: "All time favorites",
                        limit: 14
                    )

                    GenreChipRail(kind: .movie, genres: CatalogMood.filmGenreChips())

                    CatalogShelf(
                        title: moodPack.title,
                        items: moodItems,
                        kind: .movie,
                        style: .posters,
                        eyebrow: moodPack.eyebrow,
                        limit: 14,
                        seeAllLabel: "More",
                        seeAllDestination: {
                            AnyView(MediaBrowseView(kind: .movie, initialGenreId: moodPack.genreId))
                        }
                    )

                    browseFooter

                    if let error {
                        InlineErrorBanner(message: error) {
                            Task { await load() }
                        }
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 8)
        }
        .marqueeCanvas()
        .navigationTitle("Films")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MediaBrowseView(kind: .movie)
                } label: {
                    Label("Browse", systemImage: "line.3.horizontal.decrease.circle")
                }
            }
        }
        .task { await load() }
        .refreshable { await load() }
        .onChange(of: preferences.preferredProviderIds) { _, _ in
            Task { await load(servicesOnly: true) }
        }
    }

    private var browseFooter: some View {
        NavigationLink {
            MediaBrowseView(kind: .movie)
        } label: {
            HStack(spacing: 10) {
                Text("Browse all films")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundStyle(theme.olive)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(PressablePosterStyle())
        .padding(.horizontal, 20)
    }

    private func load(servicesOnly: Bool = false) async {
        error = nil
        moodPack = CatalogMood.filmPack()
        loadToken += 1
        let token = loadToken

        if !servicesOnly,
           trending.isEmpty,
           let cached = ResponseCache.load(FilmsLandingCache.self, key: "films.landing.v3") {
            trending = cached.trending
            nowPlaying = cached.nowPlaying
            upcoming = cached.upcoming
            topRated = cached.topRated
            onServices = cached.onServices
            moodItems = cached.moodId == moodPack.id ? cached.mood : cached.mood
            loading = false
        }

        do {
            let region = preferences.resolvedWatchRegion
            let providers = preferences.preferredProviderIds
            let mood = moodPack

            if servicesOnly {
                if providers.isEmpty {
                    onServices = []
                } else {
                    let stream = try await TMDBService.discover(
                        BrowseQuery(
                            kind: .movie,
                            sort: .popular,
                            providerIds: providers,
                            watchRegion: region
                        )
                    )
                    guard token == loadToken else { return }
                    onServices = dedupe(stream.results, against: trending)
                }
                return
            }

            async let t = TMDBService.fetchPaged("trending/movie/week")
            async let n = TMDBService.fetchPaged("movie/now_playing")
            async let u = TMDBService.fetchPaged("movie/upcoming")
            async let r = TMDBService.fetchPaged("movie/top_rated")
            async let moodPage = TMDBService.discover(
                BrowseQuery(kind: .movie, sort: .popular, genreId: mood.genreId, watchRegion: region)
            )

            let trend = try await t.results
            let now = try await n.results
            let soon = try await u.results
            let top = try await r.results
            let moodResults = (try? await moodPage.results) ?? []

            var stream: [MediaItem] = []
            if !providers.isEmpty {
                stream = (try? await TMDBService.discover(
                    BrowseQuery(
                        kind: .movie,
                        sort: .popular,
                        providerIds: providers,
                        watchRegion: region
                    )
                ).results) ?? []
            }

            guard token == loadToken else { return }

            trending = trend
            nowPlaying = now
            upcoming = soon
            topRated = top
            onServices = dedupe(stream, against: trend)
            moodItems = dedupe(moodResults, against: trend + stream)
            ResponseCache.store(
                FilmsLandingCache(
                    trending: trend,
                    nowPlaying: now,
                    upcoming: soon,
                    topRated: top,
                    onServices: onServices,
                    mood: moodItems,
                    moodId: mood.id
                ),
                key: "films.landing.v3"
            )
            loading = false
        } catch {
            if trending.isEmpty {
                self.error = error.localizedDescription
            } else {
                self.error = "Couldn’t refresh. Showing last saved films."
            }
            loading = false
        }
    }

    private func dedupe(_ items: [MediaItem], against existing: [MediaItem]) -> [MediaItem] {
        let seen = Set(existing.map(\.id))
        var out: [MediaItem] = []
        for item in items where !seen.contains(item.id) {
            out.append(item)
            if out.count >= 14 { break }
        }
        return out.isEmpty ? Array(items.prefix(14)) : out
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
