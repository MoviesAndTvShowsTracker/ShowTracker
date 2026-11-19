import SwiftUI

private struct FilmsLandingCache: Codable {
    var trending: [MediaItem]
    var nowPlaying: [MediaItem]
    var upcoming: [MediaItem]
    var topRated: [MediaItem]
}

struct FilmsLandingView: View {
    @Environment(\.marqueeTheme) private var theme
    @State private var trending: [MediaItem] = []
    @State private var nowPlaying: [MediaItem] = []
    @State private var upcoming: [MediaItem] = []
    @State private var topRated: [MediaItem] = []
    @State private var loading = true
    @State private var error: String?

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
                    NavigationRail(title: "Trending", items: trending, kind: .movie)
                    NavigationRail(title: "Now playing", items: nowPlaying, kind: .movie)
                    NavigationRail(title: "Upcoming", items: upcoming, kind: .movie)
                    NavigationRail(title: "Top rated", items: topRated, kind: .movie)
                    if let error {
                        InlineErrorBanner(message: error) {
                            Task { await load() }
                        }
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .marqueeCanvas()
        .navigationTitle("Films")
        .navigationBarTitleDisplayMode(.large)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        error = nil
        if trending.isEmpty,
           let cached = ResponseCache.load(FilmsLandingCache.self, key: "films.landing") {
            trending = cached.trending
            nowPlaying = cached.nowPlaying
            upcoming = cached.upcoming
            topRated = cached.topRated
            loading = false
        }
        do {
            async let t = TMDBService.fetchPaged("trending/movie/week")
            async let n = TMDBService.fetchPaged("movie/now_playing")
            async let u = TMDBService.fetchPaged("movie/upcoming")
            async let r = TMDBService.fetchPaged("movie/top_rated")
            let trend = try await t.results
            let now = try await n.results
            let soon = try await u.results
            let top = try await r.results
            trending = trend
            nowPlaying = now
            upcoming = soon
            topRated = top
            ResponseCache.store(
                FilmsLandingCache(trending: trend, nowPlaying: now, upcoming: soon, topRated: top),
                key: "films.landing"
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
}

enum MediaKind { case movie, tv }

struct NavigationRail: View {
    @Environment(\.marqueeTheme) private var theme
    let title: String
    let items: [MediaItem]
    let kind: MediaKind

    var body: some View {
        if items.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(items) { item in
                            MediaNavLink(id: item.id, kind: kind) {
                                PosterTile(title: item.displayTitle, posterPath: item.poster_path, year: item.year)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }
}
