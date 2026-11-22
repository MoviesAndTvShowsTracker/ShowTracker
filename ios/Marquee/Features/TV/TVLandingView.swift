import SwiftUI

struct TVLandingView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(AppPreferences.self) private var preferences

    @State private var trending: [MediaItem] = []
    @State private var onTheAir: [MediaItem] = []
    @State private var airingToday: [MediaItem] = []
    @State private var topRated: [MediaItem] = []
    @State private var onServices: [MediaItem] = []
    @State private var moodItems: [MediaItem] = []
    @State private var moodPack = CatalogMood.tvPack()
    @State private var watching: [TrackingRecord] = []
    @State private var paused: [TrackingRecord] = []
    @State private var finished: [TrackingRecord] = []
    @State private var libraryCounts: LibraryCounts?
    @State private var libraryFocus: TVLibraryView.LibraryTab = .watching
    @State private var loading = true
    @State private var error: String?
    @State private var loadToken = 0

    private var hasServices: Bool { !preferences.preferredProviderIds.isEmpty }

    private var servicesTitle: String {
        let names = StreamingProviderOption.allCases
            .filter { preferences.preferredProviderIds.contains($0.rawValue) }
            .map(\.title)
        if names.count == 1 { return "On \(names[0])" }
        if names.count == 2 { return "On \(names[0]) & \(names[1])" }
        return "On your services"
    }

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

                    ServicesWatchBar()

                    CatalogShelf(
                        title: "Top 10 trending",
                        items: trending,
                        kind: .tv,
                        style: .ranked,
                        eyebrow: "This week",
                        limit: 10
                    )

                    // One cinema break: live TV schedule.
                    CatalogShelf(
                        title: "Airing this week",
                        items: onTheAir,
                        kind: .tv,
                        style: .cinema,
                        eyebrow: "Wide picks · fresh episodes",
                        limit: 12
                    )

                    if hasServices {
                        CatalogShelf(
                            title: servicesTitle,
                            items: onServices,
                            kind: .tv,
                            style: .posters,
                            eyebrow: "Your subscriptions",
                            limit: 14,
                            seeAllLabel: "Browse",
                            seeAllDestination: {
                                AnyView(
                                    MediaBrowseView(
                                        kind: .tv,
                                        initialProviders: preferences.preferredProviderIds
                                    )
                                )
                            }
                        )
                    }

                    CatalogShelf(
                        title: "Airing today",
                        items: airingToday,
                        kind: .tv,
                        style: .posters,
                        eyebrow: "On tonight",
                        limit: 14
                    )

                    CatalogShelf(
                        title: "Top rated",
                        items: topRated,
                        kind: .tv,
                        style: .posters,
                        eyebrow: "All time favorites",
                        limit: 14
                    )

                    GenreChipRail(kind: .tv, genres: CatalogMood.tvGenreChips())

                    CatalogShelf(
                        title: moodPack.title,
                        items: moodItems,
                        kind: .tv,
                        style: .posters,
                        eyebrow: moodPack.eyebrow,
                        limit: 14,
                        seeAllLabel: "More",
                        seeAllDestination: {
                            AnyView(MediaBrowseView(kind: .tv, initialGenreId: moodPack.genreId))
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
        .navigationTitle("TV")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MediaBrowseView(kind: .tv)
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
            MediaBrowseView(kind: .tv)
        } label: {
            HStack(spacing: 10) {
                Text("Browse all TV")
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
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your library")
                            .font(.caption2.weight(.bold))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(theme.accent)
                        Text("Your shows")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(theme.ink)
                    }
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

                if active.tab == .watching {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(Array(active.items.prefix(8))) { item in
                                NavigationLink {
                                    TVDetailView(tvId: Int(item.tvId) ?? 0)
                                } label: {
                                    WatchingFeatureCard(item: item)
                                        .frame(width: 300)
                                }
                                .buttonStyle(PressablePosterStyle())
                            }
                        }
                    }
                    .padding(.horizontal, -20)
                    .padding(.leading, 20)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(alignment: .top, spacing: 12) {
                            ForEach(Array(active.items.prefix(12))) { item in
                                NavigationLink {
                                    TVDetailView(tvId: Int(item.tvId) ?? 0)
                                } label: {
                                    let progress = ShowProgress.from(track: item)
                                    PosterTile(
                                        title: item.tvTitle ?? "Show",
                                        posterPath: item.posterPath,
                                        width: 118,
                                        year: active.tab == .finished ? "Finished" : progress.episodeLine
                                    )
                                }
                                .buttonStyle(PressablePosterStyle())
                            }
                        }
                    }
                    .padding(.horizontal, -20)
                    .padding(.leading, 20)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func load(servicesOnly: Bool = false) async {
        error = nil
        moodPack = CatalogMood.tvPack()
        loadToken += 1
        let token = loadToken

        if !servicesOnly,
           trending.isEmpty,
           let cached = ResponseCache.load(TVCatalogCache.self, key: "tv.landing.v3") {
            trending = cached.trending
            onTheAir = cached.onTheAir
            airingToday = cached.airingToday
            topRated = cached.topRated
            onServices = cached.onServices
            moodItems = cached.mood
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
                            kind: .tv,
                            sort: .popular,
                            providerIds: providers,
                            watchRegion: region
                        )
                    )
                    guard token == loadToken else { return }
                    onServices = dedupe(stream.results, against: trending + onTheAir)
                }
                return
            }

            async let t = TMDBService.fetchPaged("trending/tv/week")
            async let o = TMDBService.fetchPaged("tv/on_the_air")
            async let a = TMDBService.fetchPaged("tv/airing_today")
            async let r = TMDBService.fetchPaged("tv/top_rated")
            async let moodPage = TMDBService.discover(
                BrowseQuery(kind: .tv, sort: .popular, genreId: mood.genreId, watchRegion: region)
            )
            async let w = DiaryService.library(tab: "watching")
            async let p = DiaryService.library(tab: "stopped")
            async let f = DiaryService.library(tab: "finished")
            async let s = DiaryService.librarySummary()

            let trend = try await t.results
            let onAir = try await o.results
            let today = try await a.results
            let top = try await r.results
            let moodResults = (try? await moodPage.results) ?? []
            let watch = (try? await w) ?? []
            let hold = (try? await p) ?? []
            let done = (try? await f) ?? []
            let counts = try? await s.counts

            var stream: [MediaItem] = []
            if !providers.isEmpty {
                stream = (try? await TMDBService.discover(
                    BrowseQuery(
                        kind: .tv,
                        sort: .popular,
                        providerIds: providers,
                        watchRegion: region
                    )
                ).results) ?? []
            }

            guard token == loadToken else { return }

            trending = trend
            onTheAir = onAir
            airingToday = today
            topRated = top
            onServices = dedupe(stream, against: trend + onAir)
            moodItems = dedupe(moodResults, against: trend + onAir + stream)
            watching = watch
            paused = hold
            finished = done
            libraryCounts = counts
            ResponseCache.store(
                TVCatalogCache(
                    trending: trend,
                    onTheAir: onAir,
                    airingToday: today,
                    topRated: top,
                    onServices: onServices,
                    mood: moodItems
                ),
                key: "tv.landing.v3"
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

private struct TVCatalogCache: Codable {
    var trending: [MediaItem]
    var onTheAir: [MediaItem]
    var airingToday: [MediaItem]
    var topRated: [MediaItem]
    var onServices: [MediaItem]
    var mood: [MediaItem]
}

private struct WatchingFeatureCard: View {
    @Environment(\.marqueeTheme) private var theme
    let item: TrackingRecord

    var body: some View {
        let progress = ShowProgress.from(track: item)
        HStack(alignment: .top, spacing: 14) {
            CachedAsyncImage(url: AppConfig.posterURL(path: item.posterPath))
                .frame(width: 72, height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                SectionKicker(text: "Up next", accented: true)
                Text(item.tvTitle ?? "Show")
                    .font(.headline.weight(.bold))
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
                        .lineLimit(1)
                }
                ProgressTrack(progress: progress.fraction)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceElevated, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
