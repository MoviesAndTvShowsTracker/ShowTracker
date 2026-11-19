import SwiftUI

struct TVLandingView: View {
    @Environment(\.marqueeTheme) private var theme
    @State private var trending: [MediaItem] = []
    @State private var onTheAir: [MediaItem] = []
    @State private var airingToday: [MediaItem] = []
    @State private var topRated: [MediaItem] = []
    @State private var watching: [TrackingRecord] = []
    @State private var paused: [TrackingRecord] = []
    @State private var finished: [TrackingRecord] = []
    @State private var libraryCounts: LibraryCounts?
    @State private var libraryFocus: TVLibraryView.LibraryTab = .watching
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                if loading && trending.isEmpty && watching.isEmpty {
                    LandingSkeleton(showLibrary: true)
                } else if trending.isEmpty && watching.isEmpty, let error {
                    ErrorStateView(message: error) {
                        Task { await load() }
                    }
                } else {
                    if !trending.isEmpty {
                        HeroCarousel(items: trending, kind: .tv)
                    }
                    libraryStudio
                    NavigationRail(title: "On the air", items: onTheAir, kind: .tv)
                    NavigationRail(title: "Airing today", items: airingToday, kind: .tv)
                    NavigationRail(title: "Top rated", items: topRated, kind: .tv)
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
        .navigationTitle("TV")
        .task { await load() }
        .refreshable { await load() }
    }

    private var libraryShelves: [(tab: TVLibraryView.LibraryTab, items: [TrackingRecord], count: Int)] {
        var rows: [(TVLibraryView.LibraryTab, [TrackingRecord], Int)] = []
        if !watching.isEmpty {
            rows.append((.watching, watching, libraryCounts?.watching ?? watching.count))
        }
        if !paused.isEmpty {
            rows.append((.stopped, paused, libraryCounts?.paused ?? paused.count))
        }
        if !finished.isEmpty {
            rows.append((.finished, finished, libraryCounts?.completed ?? finished.count))
        }
        return rows
    }

    @ViewBuilder
    private var libraryStudio: some View {
        if !libraryShelves.isEmpty {
            let active = libraryShelves.first(where: { $0.tab == libraryFocus }) ?? libraryShelves[0]
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    Text("Your shows")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.ink)
                    Text("\(active.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.olive)
                        .monospacedDigit()
                    Spacer()
                    NavigationLink {
                        TVLibraryView(initialTab: active.tab)
                    } label: {
                        Text("See all")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(theme.olive)
                    }
                }

                if libraryShelves.count > 1 {
                    Picker("Library", selection: $libraryFocus) {
                        ForEach(libraryShelves, id: \.tab) { shelf in
                            Text(shelf.tab.label).tag(shelf.tab)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                if active.tab == .watching, let featured = active.items.first {
                    NavigationLink {
                        TVDetailView(tvId: Int(featured.tvId) ?? 0)
                    } label: {
                        WatchingFeatureCard(item: featured)
                    }
                    .buttonStyle(PressablePosterStyle())
                }

                let gridItems = active.tab == .watching ? Array(active.items.dropFirst().prefix(6)) : Array(active.items.prefix(6))
                if !gridItems.isEmpty {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10),
                            GridItem(.flexible(), spacing: 10)
                        ],
                        spacing: 14
                    ) {
                        ForEach(gridItems) { item in
                            NavigationLink {
                                TVDetailView(tvId: Int(item.tvId) ?? 0)
                            } label: {
                                let progress = ShowProgress.from(track: item)
                                PosterGridTile(
                                    title: item.tvTitle ?? "Show",
                                    posterPath: item.posterPath,
                                    caption: active.tab == .finished ? "Finished" : progress.episodeLine,
                                    progress: active.tab == .watching ? progress.fraction : nil
                                )
                            }
                            .buttonStyle(PressablePosterStyle())
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func load() async {
        error = nil
        if trending.isEmpty,
           let cached = ResponseCache.load(TVCatalogCache.self, key: "tv.landing") {
            trending = cached.trending
            onTheAir = cached.onTheAir
            airingToday = cached.airingToday
            topRated = cached.topRated
            loading = false
        }
        do {
            async let t = TMDBService.fetchPaged("trending/tv/week")
            async let o = TMDBService.fetchPaged("tv/on_the_air")
            async let a = TMDBService.fetchPaged("tv/airing_today")
            async let r = TMDBService.fetchPaged("tv/top_rated")
            async let w = DiaryService.library(tab: "watching")
            async let p = DiaryService.library(tab: "stopped")
            async let f = DiaryService.library(tab: "finished")
            async let s = DiaryService.librarySummary()
            let trend = try await t.results
            let onAir = try await o.results
            let today = try await a.results
            let top = try await r.results
            let watch = (try? await w) ?? []
            let hold = (try? await p) ?? []
            let done = (try? await f) ?? []
            let counts = try? await s.counts
            trending = trend
            onTheAir = onAir
            airingToday = today
            topRated = top
            watching = watch
            paused = hold
            finished = done
            libraryCounts = counts
            ResponseCache.store(
                TVCatalogCache(trending: trend, onTheAir: onAir, airingToday: today, topRated: top),
                key: "tv.landing"
            )
            if watching.isEmpty {
                libraryFocus = paused.isEmpty ? .finished : .stopped
            }
            loading = false
        } catch {
            if trending.isEmpty && watching.isEmpty {
                self.error = error.localizedDescription
            } else {
                self.error = "Couldn’t refresh. Showing last saved TV."
            }
            loading = false
        }
    }
}

private struct TVCatalogCache: Codable {
    var trending: [MediaItem]
    var onTheAir: [MediaItem]
    var airingToday: [MediaItem]
    var topRated: [MediaItem]
}

private struct WatchingFeatureCard: View {
    @Environment(\.marqueeTheme) private var theme
    let item: TrackingRecord

    var body: some View {
        let progress = ShowProgress.from(track: item)
        HStack(alignment: .top, spacing: 14) {
            CachedAsyncImage(url: AppConfig.posterURL(path: item.posterPath))
                .frame(width: 86, height: 129)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                SectionKicker(text: "Up next", accented: true)
                Text(item.tvTitle ?? "Show")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Text(progress.episodeLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.olive)
                if let name = progress.next?.name, !name.isEmpty {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)
                        .lineLimit(2)
                }
                HStack(spacing: 8) {
                    ProgressTrack(progress: progress.fraction)
                    Text(progress.total > 0 ? "\(progress.percent)%" : "\(progress.watched) ep")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.olive)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .background(theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
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
