import SwiftUI

struct TVLandingView: View {
    @Environment(\.marqueeTheme) private var theme
    @State private var trending: [MediaItem] = []
    @State private var onTheAir: [MediaItem] = []
    @State private var airingToday: [MediaItem] = []
    @State private var topRated: [MediaItem] = []
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                NavigationLink {
                    TVLibraryView()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your TV library")
                                .font(.headline)
                                .foregroundStyle(theme.ink)
                            Text("Watching · Paused · Finished")
                                .font(.subheadline)
                                .foregroundStyle(theme.inkMuted)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.olive)
                    }
                    .padding(16)
                    .background(theme.surfaceElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(theme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressablePosterStyle())
                .padding(.horizontal, 20)

                if !trending.isEmpty {
                    HeroCarousel(items: trending, kind: .tv)
                }

                NavigationRail(title: "Trending", items: trending, kind: .tv)
                NavigationRail(title: "On the air", items: onTheAir, kind: .tv)
                NavigationRail(title: "Airing today", items: airingToday, kind: .tv)
                NavigationRail(title: "Top rated", items: topRated, kind: .tv)

                if loading { ProgressView().tint(theme.accent).frame(maxWidth: .infinity) }
                if let error {
                    Text(error).font(.footnote).foregroundStyle(theme.inkMuted).padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
        }
        .background(theme.surface.ignoresSafeArea())
        .navigationTitle("TV")
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        loading = true
        error = nil
        defer { loading = false }
        do {
            async let t = TMDBService.fetchPaged("trending/tv/week")
            async let o = TMDBService.fetchPaged("tv/on_the_air")
            async let a = TMDBService.fetchPaged("tv/airing_today")
            async let r = TMDBService.fetchPaged("tv/top_rated")
            trending = try await t.results
            onTheAir = try await o.results
            airingToday = try await a.results
            topRated = try await r.results
        } catch {
            self.error = error.localizedDescription
        }
    }
}
