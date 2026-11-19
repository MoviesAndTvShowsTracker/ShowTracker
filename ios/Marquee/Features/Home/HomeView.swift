import SwiftUI

struct HomeView: View {
    @Environment(AuthStore.self) private var auth
    @Environment(\.marqueeTheme) private var theme

    @State private var continueItems: [TrackingRecord] = []
    @State private var catalogTotals: [String: Int] = [:]
    @State private var filmWatchlist: [FavoriteMovieDoc] = []
    @State private var tvWatchlist: [FavoriteTVDoc] = []
    @State private var recap: WeekRecap?
    @State private var loading = true
    @State private var error: String?
    @State private var watchlistFilter: WatchlistFilter = .all
    @State private var schedule: [ScheduleEpisode] = []
    @State private var recommendations: [MediaItem] = []
    @State private var continuePage = 0

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
        switch watchlistFilter {
        case .all: return films + shows
        case .films: return films
        case .tv: return shows
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                continueCarousel

                if let recap {
                    NavigationLink { StatsView() } label: {
                        WeekRecapCard(recap: recap)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                }

                scheduleSection
                watchlistSection

                if !recommendations.isEmpty {
                    NavigationRail(title: "For you", items: recommendations, kind: .movie)
                }

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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionKicker(text: "Lobby", accented: true)
            Text("Hey, \(greetingName)")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(theme.olive)
            Text(continueItems.isEmpty
                  ? "Nothing in progress — start a show from TV."
                  : "Swipe to switch shows you’re mid-season.")
                .foregroundStyle(theme.inkMuted)
        }
        .padding(.horizontal, 20)
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

    @ViewBuilder
    private var scheduleSection: some View {
        if !schedule.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Coming up")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 20)
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(schedule.prefix(12)) { item in
                            NavigationLink {
                                TVDetailView(tvId: item.tvId)
                            } label: {
                                HStack(spacing: 10) {
                                    CachedAsyncImage(url: AppConfig.posterURL(path: item.posterPath))
                                        .frame(width: 48, height: 72)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.title)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(theme.ink)
                                            .lineLimit(2)
                                        Text("S\(item.season)E\(item.episode)")
                                            .font(.caption.weight(.bold))
                                            .foregroundStyle(theme.accent)
                                        Text(item.airDate)
                                            .font(.caption2)
                                            .foregroundStyle(theme.inkMuted)
                                    }
                                    .frame(width: 140, alignment: .leading)
                                }
                                .padding(10)
                                .background(theme.surfaceElevated)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(theme.border, lineWidth: 1)
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
                if !mergedWatchlist.isEmpty {
                    NavigationLink("View all") {
                        ProfileListView(kind: watchlistFilter == .tv ? .tvWatchlist : .filmWatchlist)
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

            if loading && mergedWatchlist.isEmpty {
                RailSkeleton()
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
        switch watchlistFilter {
        case .all: return "Nothing queued — browse films or TV and bookmark something."
        case .films: return "Nothing queued — browse films and bookmark something."
        case .tv: return "Save a show for later from search or TV."
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
            async let f = DiaryService.movieWatchlist()
            async let t = DiaryService.tvWatchlist()
            async let r = DiaryService.weekRecap()
            let cont = try await c
            let films = try await f
            let shows = try await t
            let week = try? await r
            continueItems = cont
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
            async let upcoming = HomeScheduleBuilder.upcoming(from: cont)
            async let recs = loadRecommendations()
            schedule = await upcoming
            recommendations = await recs
            WidgetSnapshotStore.save(
                continueTitle: cont.first?.tvTitle,
                continuePoster: cont.first?.posterPath,
                weekFilms: week?.filmsThisWeek,
                weekEpisodes: week?.episodesThisWeek,
                weekMins: week?.totalMinsThisWeek
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

    private func loadRecommendations() async -> [MediaItem] {
        let stats = try? await DiaryService.dashboardStats()
        let names = (stats?.taste?.genres ?? []).prefix(3).compactMap(\.name)
        let genreIds = names.compactMap { TMDBGenreMap.id(for: $0) }
        let page = try? await TMDBService.discoverMovies(genreIds: Array(genreIds))
        return Array((page?.results ?? []).prefix(12))
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

    private var shareText: String {
        var parts = ["My week on Marquee"]
        if let films = recap.filmsThisWeek { parts.append("\(films) films") }
        if let eps = recap.episodesThisWeek { parts.append("\(eps) episodes") }
        if let mins = recap.totalMinsThisWeek { parts.append("\(mins) minutes") }
        if let streak = recap.streak, streak > 0 { parts.append("\(streak)-day streak") }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionKicker(text: "This week", accented: true)
                    Spacer()
                    ShareLink(item: shareText) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(theme.olive)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(theme.olive)
                }
                HStack(spacing: 12) {
                    metric("Films", recap.filmsThisWeek ?? 0)
                    metric("Episodes", recap.episodesThisWeek ?? 0)
                    metric("Min", recap.totalMinsThisWeek ?? 0)
                }
                if let streak = recap.streak, streak > 0 {
                    Text("\(streak)-day streak")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.olive)
                }
            }
        }
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(value)")
                .font(.title3.weight(.bold))
                .foregroundStyle(theme.accent)
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
