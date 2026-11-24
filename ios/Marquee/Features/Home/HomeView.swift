import SwiftUI

struct HomeView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(AppPreferences.self) private var preferences
    @Environment(\.marqueeTheme) private var theme

    @State private var continueItems: [TrackingRecord] = []
    @State private var pausedItems: [TrackingRecord] = []
    @State private var finishedItems: [TrackingRecord] = []
    @State private var catalogTotals: [String: Int] = [:]
    @State private var filmWatchlist: [FavoriteMovieDoc] = []
    @State private var tvWatchlist: [FavoriteTVDoc] = []
    @State private var recap: WeekRecap?
    @State private var loading = true
    @State private var error: String?
    @State private var airingSoon: [ThisWeekItem] = []
    @State private var pausedShows: [ThisWeekItem] = []
    @State private var continuePage = 0

    private var greetingName: String {
        let first = auth.profile?.firstName ?? auth.session?.firstName ?? ""
        return first.isEmpty ? "there" : first
    }

    private var filmQueue: [(id: Int, title: String, poster: String?)] {
        filmWatchlist.map {
            (
                id: Int($0.movieId) ?? abs($0.movieId.hashValue),
                title: $0.movieTitle ?? "Film",
                poster: $0.posterPath
            )
        }
    }

    private var tvQueue: [(id: Int, title: String, poster: String?)] {
        tvWatchlist.map {
            (
                id: Int($0.tvId) ?? abs($0.tvId.hashValue),
                title: $0.tvTitle ?? "Show",
                poster: $0.posterPath
            )
        }
    }

    private var isLobbyEmpty: Bool {
        !loading
            && continueItems.isEmpty
            && airingSoon.isEmpty
            && pausedShows.isEmpty
            && filmWatchlist.isEmpty
            && tvWatchlist.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                if let recap, !isLobbyEmpty {
                    WeekPulseRow(recap: recap)
                }

                if isLobbyEmpty {
                    LobbyEmptyState()
                } else {
                    continueCarousel
                    LobbyTimelineRail(
                        title: "Airing soon",
                        subtitle: "New episodes and season returns",
                        items: airingSoon
                    )
                    LobbyTimelineRail(
                        title: "Paused",
                        subtitle: "Pick up when you’re ready",
                        items: pausedShows
                    )
                    watchlistRails
                    calendarLink
                }

                if isLobbyEmpty, let error {
                    ErrorStateView(message: error) {
                        Task { await load() }
                    }
                } else if let error {
                    InlineErrorBanner(message: error) {
                        Task { await load() }
                    }
                }
            }
            .padding(.vertical, 16)
            .padding(.bottom, 28)
        }
        .marqueeCanvas()
        .marqueeLandingChrome()
        .refreshable { await load() }
        .task {
            if UITestingFixtures.isEnabled {
                continueItems = UITestingFixtures.continueItems
                loading = false
                return
            }
            await load()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hey, \(greetingName)")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(theme.ink)
            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .accessibilityAddTraits(.isHeader)
    }

    private var headerSubtitle: String {
        if airingSoon.contains(where: { $0.kind == .airing && $0.dayLabel == "Today" }) {
            return "Something you track lands tonight."
        }
        if !continueItems.isEmpty {
            return "Pick up where you left off."
        }
        if !airingSoon.isEmpty {
            return "New episodes are lining up."
        }
        if !pausedShows.isEmpty {
            return "A few shows are waiting when you’re ready."
        }
        if !filmQueue.isEmpty || !tvQueue.isEmpty {
            return "Something from your queue is waiting."
        }
        return "Queue something from Films or TV — Lobby fills in."
    }

    @ViewBuilder
    private var continueCarousel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Continue")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                if continueItems.count > 1 {
                    Text("\(continuePage + 1) of \(continueItems.count)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.olive)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(theme.oliveSoft)
                        .clipShape(Capsule())
                        .monospacedDigit()
                }
                Spacer()
                NavigationLink("Library") { TVLibraryView() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.olive)
            }
            .padding(.horizontal, 20)

            if loading && continueItems.isEmpty {
                SkeletonBlock(height: 240, radius: 22)
                    .padding(.horizontal, 20)
            } else if continueItems.isEmpty {
                EmptyDiaryCard(
                    title: "Nothing in progress",
                    message: "Start tracking a show and your next episode will land here.",
                    chip: "Continue"
                )
                .padding(.horizontal, 20)
            } else {
                TabView(selection: $continuePage) {
                    ForEach(Array(continueItems.enumerated()), id: \.element.id) { index, item in
                        NavigationLink {
                            TVContinueView(
                                tvId: Int(item.tvId) ?? 0,
                                seed: item,
                                catalogTotal: catalogTotals[item.tvId]
                            )
                        } label: {
                            ContinueHeroCard(item: item, catalogTotal: catalogTotals[item.tvId])
                        }
                        .buttonStyle(PressablePosterStyle())
                        .padding(.horizontal, 20)
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: continueItems.count > 1 ? .automatic : .never))
                .frame(height: 268)
                .onChange(of: continueItems.map(\.id)) { _, _ in
                    if continuePage >= continueItems.count {
                        continuePage = max(0, continueItems.count - 1)
                    }
                }
            }
        }
    }

    private var calendarLink: some View {
        NavigationLink {
            DiaryActivityView()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.olive)
                    .frame(width: 40, height: 40)
                    .background(theme.oliveSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text("Watch calendar")
                        .font(.headline)
                        .foregroundStyle(theme.ink)
                    Text("See what you marked, day by day.")
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.olive)
            }
            .padding(16)
            .background(theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .accessibilityIdentifier("watch-calendar-link")
    }

    @ViewBuilder
    private var watchlistRails: some View {
        if loading && filmWatchlist.isEmpty && tvWatchlist.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Film watchlist")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 20)
                RailSkeleton()
            }
        } else {
            lobbyWatchlistRail(
                title: "Film watchlist",
                items: Array(filmQueue.prefix(12)),
                kind: .movie,
                scope: .films
            )
            lobbyWatchlistRail(
                title: "TV watchlist",
                items: Array(tvQueue.prefix(12)),
                kind: .tv,
                scope: .tv
            )
        }
    }

    @ViewBuilder
    private func lobbyWatchlistRail(
        title: String,
        items: [(id: Int, title: String, poster: String?)],
        kind: MediaKind,
        scope: WatchlistView.Scope
    ) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    NavigationLink("View all") {
                        WatchlistView(initialScope: scope)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.olive)
                }
                .padding(.horizontal, 20)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(items, id: \.id) { item in
                            MediaNavLink(id: item.id, kind: kind) {
                                PosterTile(
                                    title: item.title,
                                    posterPath: item.poster,
                                    year: nil
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func load() async {
        error = nil
        if continueItems.isEmpty,
           let cached = ResponseCache.load(HomeLandingCache.self, key: "home.landing") {
            continueItems = cached.continueItems
            filmWatchlist = cached.filmWatchlist
            tvWatchlist = cached.tvWatchlist
            recap = cached.recap
            loading = false
        }
        do {
            async let c = DiaryService.continueWatching()
            async let pausedTask = DiaryService.library(tab: "stopped")
            async let finishedTask = DiaryService.library(tab: "finished")
            async let f = DiaryService.movieWatchlist()
            async let t = DiaryService.tvWatchlist()
            async let r = DiaryService.weekRecap()

            let cont = try await c
            let paused = (try? await pausedTask) ?? []
            let finished = (try? await finishedTask) ?? []
            let films = try await f
            let shows = try await t
            let week = try? await r

            continueItems = cont
            pausedItems = paused
            finishedItems = finished
            filmWatchlist = films
            tvWatchlist = shows
            recap = week
            ResponseCache.store(
                HomeLandingCache(
                    continueItems: cont,
                    filmWatchlist: films,
                    tvWatchlist: shows,
                    recap: week
                ),
                key: "home.landing"
            )
            error = nil
            loading = false
            await enrichCatalogTotals()

            let scheduleSeed = cont + paused
            async let upcoming = HomeScheduleBuilder.upcoming(from: scheduleSeed)
            async let returningSoon = HomeScheduleBuilder.returningSoon(from: paused + finished)

            let upcomingItems = await upcoming
            let returningItems = await returningSoon.filter { item in
                !upcomingItems.contains(where: { $0.tvId == item.tvId && $0.airDate == item.airDate })
            }
            let continueIds = Set(cont.compactMap { Int($0.tvId) })
            let timeline = ThisWeekBuilder.build(
                schedule: upcomingItems,
                returning: returningItems,
                paused: paused,
                continueIds: continueIds
            )
            airingSoon = timeline.filter { $0.kind == .airing || $0.kind == .returning }
            pausedShows = timeline.filter { $0.kind == .resume }

            let next = cont.first
            let progress = next.map { ShowProgress.from(track: $0) }
            WidgetSnapshotStore.save(
                continueTitle: next?.tvTitle,
                continueSubtitle: progress?.episodeLine,
                continuePoster: next?.posterPath,
                weekFilms: week?.filmsThisWeek,
                weekEpisodes: week?.episodesThisWeek,
                weekMins: week?.totalMinsThisWeek,
                weekStreak: week?.streak
            )

            await EpisodeAlertScheduler.refresh(
                schedule: upcomingItems,
                enabled: preferences.episodeAlertsEnabled
            )
        } catch {
            if continueItems.isEmpty && filmWatchlist.isEmpty && tvWatchlist.isEmpty {
                self.error = error.localizedDescription
            } else {
                self.error = "Couldn’t refresh. Showing last saved home."
            }
            loading = false
        }
    }

    private func enrichCatalogTotals() async {
        await withTaskGroup(of: (String, Int).self) { group in
            for item in continueItems {
                let needsTotal = (item.airedEpisodeCount ?? 0) == 0 && (item.totalEpisodes ?? 0) == 0
                guard needsTotal, let id = Int(item.tvId) else { continue }
                group.addTask {
                    let count = (try? await TMDBService.tvDetail(id: id))?.number_of_episodes ?? 0
                    return (item.tvId, count)
                }
            }
            for await (tvId, count) in group where count > 0 {
                catalogTotals[tvId] = count
            }
        }
    }
}

private struct HomeLandingCache: Codable {
    var continueItems: [TrackingRecord]
    var filmWatchlist: [FavoriteMovieDoc]
    var tvWatchlist: [FavoriteTVDoc]
    var recap: WeekRecap?
}

struct ContinueHeroCard: View {
    @Environment(\.marqueeTheme) private var theme
    let item: TrackingRecord
    var catalogTotal: Int? = nil

    private var progress: ShowProgress {
        ShowProgress.from(track: item, catalogTotal: catalogTotal)
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            theme.olive

            CachedAsyncImage(
                url: AppConfig.posterURL(path: item.posterPath, size: "w780"),
                contentMode: .fill
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .scaleEffect(1.12)
            .blur(radius: 16)
            .opacity(0.9)

            LinearGradient(
                colors: [.black.opacity(0.2), .black.opacity(0.82)],
                startPoint: .top,
                endPoint: .bottom
            )

            HStack(alignment: .bottom, spacing: 14) {
                CachedAsyncImage(url: AppConfig.posterURL(path: item.posterPath))
                    .frame(width: 88, height: 132)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(alignment: .leading, spacing: 8) {
                    Text("Continue watching")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.85))
                    Text(item.tvTitle ?? "Show")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Text(progress.episodeLine)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(MarqueeColor.saltGrey.opacity(0.85))
                    if let name = progress.next?.name, !name.isEmpty {
                        Text(name)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(2)
                    }
                    HStack(spacing: 8) {
                        ProgressTrack(progress: progress.fraction, completed: progress.isComplete)
                            .frame(maxWidth: 120)
                        Text(progress.total > 0 ? "\(progress.percent)%" : "\(progress.watched) ep")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white.opacity(0.9))
                            .monospacedDigit()
                    }
                    Text("Continue")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(theme.onAccent)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(theme.accent)
                        .clipShape(Capsule())
                }
                Spacer(minLength: 0)
            }
            .padding(16)
        }
        .frame(height: 248)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .compositingGroup()
    }
}

struct ContinueCard: View {
    @Environment(\.marqueeTheme) private var theme
    let item: TrackingRecord
    var catalogTotal: Int? = nil

    private var progress: ShowProgress {
        ShowProgress.from(track: item, catalogTotal: catalogTotal)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            CachedAsyncImage(url: AppConfig.posterURL(path: item.posterPath))
                .frame(width: 72, height: 108)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 6) {
                Text(item.tvTitle ?? "Show")
                    .font(.headline)
                    .foregroundStyle(theme.ink)
                    .lineLimit(2)

                Text(progress.episodeLine)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.olive)

                if let name = progress.next?.name, !name.isEmpty {
                    Text(name)
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)
                        .lineLimit(2)
                } else if let last = progress.last, progress.next != nil {
                    Text("After S\(last.season)E\(last.episode)")
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)
                }

                HStack(spacing: 8) {
                    ProgressTrack(progress: progress.fraction, completed: progress.isComplete)
                    Text(progress.total > 0 ? "\(progress.percent)%" : "\(progress.watched) ep")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(theme.olive)
                        .monospacedDigit()
                }

                Text("Continue")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.onAccent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(theme.accent)
                    .clipShape(Capsule())
            }
            .frame(width: 168, alignment: .leading)
        }
        .padding(12)
        .background(theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

