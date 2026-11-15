import SwiftUI

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
                } else {
                    if !trending.isEmpty {
                        HeroCarousel(items: trending, kind: .movie)
                    }
                    NavigationRail(title: "Trending", items: trending, kind: .movie)
                    NavigationRail(title: "Now playing", items: nowPlaying, kind: .movie)
                    NavigationRail(title: "Upcoming", items: upcoming, kind: .movie)
                    NavigationRail(title: "Top rated", items: topRated, kind: .movie)
                }
                if let error {
                    Text(error).font(.footnote).foregroundStyle(theme.inkMuted).padding(.horizontal, 20)
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
            loading = false
        } catch {
            self.error = error.localizedDescription
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
