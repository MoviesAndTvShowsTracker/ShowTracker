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
                if !trending.isEmpty {
                    HeroCarousel(items: trending, kind: .movie)
                }

                NavigationRail(title: "Trending", items: trending, kind: .movie)
                NavigationRail(title: "Now playing", items: nowPlaying, kind: .movie)
                NavigationRail(title: "Upcoming", items: upcoming, kind: .movie)
                NavigationRail(title: "Top rated", items: topRated, kind: .movie)

                if loading {
                    ProgressView().tint(theme.accent).frame(maxWidth: .infinity)
                }
                if let error {
                    Text(error).font(.footnote).foregroundStyle(theme.inkMuted).padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
        }
        .background(theme.surface.ignoresSafeArea())
        .navigationTitle("Films")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(theme.surface, for: .navigationBar)
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            async let t = TMDBService.fetchPaged("trending/movie/week")
            async let n = TMDBService.fetchPaged("movie/now_playing")
            async let u = TMDBService.fetchPaged("movie/upcoming")
            async let r = TMDBService.fetchPaged("movie/top_rated")
            trending = try await t.results
            nowPlaying = try await n.results
            upcoming = try await u.results
            topRated = try await r.results
        } catch {
            self.error = error.localizedDescription
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
