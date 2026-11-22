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
    @State private var watchlistFilter: WatchlistFilter = .all
    @State private var schedule: [ScheduleEpisode] = []
    @State private var returning: [ScheduleEpisode] = []
    @State private var recommendations: [HomeRecommendation] = []
    @State private var tonight: TonightPick?
    @State private var continuePage = 0
    @State private var providerFilter = WatchlistProviderFilter()
    @State private var streamingMatchedKeys: Set<String>? = nil
    @State private var streamingFilterBusy = false
    /// Local to Lobby — don’t steal Browse’s “my services” prefs and empty the rail.
    @State private var watchlistProviderIds: Set<Int> = []

    private enum WatchlistFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case films = "Films"
        case tv = "TV"
        var id: String { rawValue }
    }

    private var greetingName: String {
        let first = auth.profile?.firstName ?? auth.session?.firstName ?? ""
        return first.isEmpty ? "there" : first
    }

    private var mergedWatchlist: [(id: Int, title: String, poster: String?, kind: MediaKind)] {
        let films = filmWatchlist.map {
            (
                id: Int($0.movieId) ?? abs($0.movieId.hashValue),
                title: $0.movieTitle ?? "Film",
                poster: $0.posterPath,
                kind: MediaKind.movie
            )
        }
        let shows = tvWatchlist.map {
            (
                id: Int($0.tvId) ?? abs($0.tvId.hashValue),
                title: $0.tvTitle ?? "Show",
                poster: $0.posterPath,
                kind: MediaKind.tv
            )
        }
        let base: [(id: Int, title: String, poster: String?, kind: MediaKind)]
        switch watchlistFilter {
        case .all: base = films + shows
        case .films: base = films
        case .tv: base = shows
        }
        guard let matched = streamingMatchedKeys else { return base }
        return base.filter { matched.contains(Self.watchlistKey(kind: $0.kind, id: $0.id)) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                if let recap {
                    NavigationLink { StatsView() } label: {
                        WeekRecapCard(recap: recap)
                    }
                    .buttonStyle(PressablePosterStyle())
                    .padding(.horizontal, 20)
                }

                // Tonight only when it isn’t the same job as Continue
                // (airs tonight elsewhere, or empty-lobby nudge).
                if let tonight {
                    TonightCard(pick: tonight)
                        .padding(.horizontal, 20)
                }

                continueCarousel

                HomeShowRail(
                    title: "Catch up",
                    subtitle: "Paused where you left off",
                    items: pausedItems,
                    destinationTab: .stopped
                )

                HomeScheduleRail(
                    title: "Returning soon",
                    subtitle: "New seasons from your library",
                    items: returning
                )

                HomeScheduleRail(
                    title: "Coming up",
                    subtitle: "Episodes airing on shows you track",
                    items: schedule
                )

                watchlistSection
                ForYouRail(items: recommendations)
                calendarLink

                if continueItems.isEmpty, filmWatchlist.isEmpty, tvWatchlist.isEmpty, !loading, let error {
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
        }
        .marqueeCanvas()
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task {
            if UITestingFixtures.isEnabled {
                continueItems = UITestingFixtures.continueItems
                loading = false
                return
            }
            await load()
        }
        .onChange(of: watchlistProviderIds) { _, _ in
            Task { await refreshStreamingFilter() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionKicker(text: "Lobby", accented: true)
            Text("Hey, \(greetingName)")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(theme.olive)
            Text(headerSubtitle)
                .foregroundStyle(theme.inkMuted)
        }
        .padding(.horizontal, 20)
    }

    private var headerSubtitle: String {
        if tonight?.kind == .airingTonight {
            return "Something you track lands tonight."
        }
        if !continueItems.isEmpty {
            return "Swipe to switch shows you’re mid-season."
        }
        if !pausedItems.isEmpty {
            return "A few shows are waiting when you’re ready."
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

    private var watchlistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Watchlist")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                if !mergedWatchlist.isEmpty || !filmWatchlist.isEmpty || !tvWatchlist.isEmpty {
                    NavigationLink("View all") {
                        WatchlistView(initialScope: watchlistViewScope)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.olive)
                }
            }
            .padding(.horizontal, 20)

            Picker("Watchlist", selection: $watchlistFilter) {
                ForEach(WatchlistFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            StreamingFilterBar(selected: $watchlistProviderIds)

            if loading && filmWatchlist.isEmpty && tvWatchlist.isEmpty {
                RailSkeleton()
            } else if streamingFilterBusy && !watchlistProviderIds.isEmpty {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking what’s on your services…")
                        .font(.caption)
                        .foregroundStyle(theme.inkMuted)
                }
                .padding(.horizontal, 20)
            } else if mergedWatchlist.isEmpty {
                Text(watchlistEmptyCopy)
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(mergedWatchlist, id: \.id) { item in
                            MediaNavLink(id: item.id, kind: item.kind) {
                                PosterTile(title: item.title, posterPath: item.poster, year: nil)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private var watchlistEmptyCopy: String {
        if !watchlistProviderIds.isEmpty {
            return "Nothing on those services in your queue — try Any service or add more titles."
        }
        switch watchlistFilter {
        case .all: return "Nothing queued — browse films or TV and bookmark something."
        case .films: return "Nothing queued — browse films and bookmark something."
        case .tv: return "Save a show for later from search or TV."
        }
    }

    private var watchlistViewScope: WatchlistView.Scope {
        switch watchlistFilter {
        case .all: return .all
        case .films: return .films
        case .tv: return .tv
        }
    }

    private nonisolated static func watchlistKey(kind: MediaKind, id: Int) -> String {
        "\(kind == .movie ? "m" : "t")-\(id)"
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
            async let recs = loadRecommendations(continueItems: cont)

            let upcomingItems = await upcoming
            let returningItems = await returningSoon
            schedule = upcomingItems
            returning = returningItems.filter { item in
                !upcomingItems.contains(where: { $0.tvId == item.tvId && $0.airDate == item.airDate })
            }
            recommendations = await recs

            tonight = TonightPicker.pick(
                continueItems: cont,
                paused: paused,
                schedule: upcomingItems,
                tvWatchlist: shows,
                filmWatchlist: films
            )

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
            await refreshStreamingFilter()
        } catch {
            if continueItems.isEmpty && filmWatchlist.isEmpty && tvWatchlist.isEmpty {
                self.error = error.localizedDescription
            } else {
                self.error = "Couldn’t refresh. Showing last saved home."
            }
            loading = false
        }
    }

    private func loadRecommendations(continueItems: [TrackingRecord]) async -> [HomeRecommendation] {
        let stats = try? await DiaryService.dashboardStats()
        let tasteNames = (stats?.taste?.genres ?? []).prefix(3).compactMap(\.name)
        let genreIds = tasteNames.compactMap { TMDBGenreMap.id(for: $0) }

        // One quiet section line — never repeated under every poster.
        let sectionReason: String = {
            if let title = continueItems.first?.tvTitle, !title.isEmpty {
                return "Nearby \(title)"
            }
            if let genre = tasteNames.first {
                return "In the mood for \(genre.lowercased())"
            }
            return "Fresh picks for your lobby"
        }()

        async let moviesPage = TMDBService.discoverMovies(genreIds: Array(genreIds))
        async let showsPage = TMDBService.discoverTV(genreIds: Array(genreIds))

        let movies = Array((try? await moviesPage)?.results ?? []).prefix(8)
        let shows = Array(((try? await showsPage)?.results ?? []).filter { show in
            let tracked = Set(continueItems.compactMap { Int($0.tvId) })
                .union(pausedItems.compactMap { Int($0.tvId) })
                .union(finishedItems.compactMap { Int($0.tvId) })
            return !tracked.contains(show.id)
        }).prefix(8)

        // Interleave so the rail doesn’t read as “all TV, then all films”.
        var out: [HomeRecommendation] = []
        let showList = Array(shows)
        let filmList = Array(movies)
        let maxCount = max(showList.count, filmList.count)
        for index in 0..<maxCount {
            if index < showList.count {
                out.append(HomeRecommendation(item: showList[index], kind: .tv, reason: sectionReason))
            }
            if index < filmList.count {
                out.append(HomeRecommendation(item: filmList[index], kind: .movie, reason: sectionReason))
            }
        }
        return Array(out.prefix(14))
    }

    private func refreshStreamingFilter() async {
        let preferred = watchlistProviderIds
        guard !preferred.isEmpty else {
            streamingMatchedKeys = nil
            streamingFilterBusy = false
            return
        }
        streamingFilterBusy = true
        defer { streamingFilterBusy = false }

        let candidates: [(kind: MediaKind, id: Int)] =
            filmWatchlist.compactMap { doc in Int(doc.movieId).map { (.movie, $0) } }
            + tvWatchlist.compactMap { doc in Int(doc.tvId).map { (.tv, $0) } }

        var matched = Set<String>()
        await withTaskGroup(of: (String, Bool).self) { group in
            for candidate in candidates.prefix(40) {
                group.addTask {
                    let ok = await providerFilter.matches(
                        kind: candidate.kind,
                        id: candidate.id,
                        preferred: preferred
                    )
                    return (Self.watchlistKey(kind: candidate.kind, id: candidate.id), ok)
                }
            }
            for await (key, ok) in group where ok {
                matched.insert(key)
            }
        }
        streamingMatchedKeys = matched
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
                        .foregroundStyle(theme.accent)
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

struct WeekRecapCard: View {
    @Environment(\.marqueeTheme) private var theme
    let recap: WeekRecap

    private var minutes: Int { recap.totalMinsThisWeek ?? 0 }
    private var films: Int { recap.filmsThisWeek ?? 0 }
    private var episodes: Int { recap.episodesThisWeek ?? 0 }
    private var streak: Int { recap.streak ?? 0 }

    private var shareText: String {
        var parts = ["My week on Marquee"]
        parts.append("\(films) films")
        parts.append("\(episodes) episodes")
        parts.append(StatsFormat.minutes(minutes))
        if streak > 0 { parts.append("\(streak)-day streak") }
        return parts.joined(separator: " · ")
    }

    /// Week-scoped copy only — ignore year insights that used to leak in from dashboard cache.
    private var insightLine: String {
        if let kind = recap.insight?.kind,
           kind == "year" || kind == "genre" || kind == "show" || kind == "total" || kind == "binge" {
            return weekFallbackInsight
        }
        if let text = recap.insight?.text, !text.isEmpty, !text.localizedCaseInsensitiveContains("this year") {
            return text
        }
        return weekFallbackInsight
    }

    private var weekFallbackInsight: String {
        if films == 0 && episodes == 0 && minutes == 0 {
            return "Mark a film or episode and this week fills in."
        }
        switch (films > 0, episodes > 0) {
        case (true, true):
            return "\(films) film\(films == 1 ? "" : "s") and \(episodes) episode\(episodes == 1 ? "" : "s") this week."
        case (true, false):
            return "\(films) film\(films == 1 ? "" : "s") logged this week."
        case (false, true):
            return "\(episodes) episode\(episodes == 1 ? "" : "s") this week. No films yet."
        default:
            return "Time is on the clock — keep going."
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                SectionKicker(text: "This week", accented: true)
                Spacer(minLength: 8)
                ShareLink(item: shareText) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.olive)
                        .frame(width: 30, height: 30)
                        .background(theme.oliveSoft, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Share this week")
            }

            // One hero number — don’t also put “Time” in a third mini-card.
            Text(StatsFormat.minutes(minutes))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(theme.ink)
                .monospacedDigit()
                .contentTransition(.numericText())

            Text(insightLine)
                .font(.subheadline)
                .foregroundStyle(theme.inkMuted)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 0) {
                weekStat(value: "\(films)", label: films == 1 ? "Film" : "Films")
                Rectangle()
                    .fill(theme.border)
                    .frame(width: 1, height: 28)
                    .padding(.horizontal, 16)
                weekStat(value: "\(episodes)", label: episodes == 1 ? "Episode" : "Episodes")
                Spacer(minLength: 0)
                if streak > 0 {
                    HStack(spacing: 5) {
                        Image(systemName: "flame.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.accent)
                        Text(streak == 1 ? "1-day" : "\(streak)-day")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.ink)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(theme.accent.opacity(0.12), in: Capsule(style: .continuous))
                    .accessibilityLabel(streak == 1 ? "1-day streak" : "\(streak)-day streak")
                }
            }
            .padding(.top, 2)
        }
        .padding(18)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(theme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(theme.border, lineWidth: 1)
                )
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("This week. \(StatsFormat.minutes(minutes)). \(films) films. \(episodes) episodes.\(streak > 0 ? " \(streak) day streak." : "") Opens stats.")
        .accessibilityHint("Opens your full stats")
    }

    private func weekStat(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.ink)
                .monospacedDigit()
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.inkMuted)
        }
    }
}
