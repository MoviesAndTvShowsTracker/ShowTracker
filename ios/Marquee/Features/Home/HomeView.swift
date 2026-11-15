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

    private var greetingName: String {
        let first = auth.profile?.firstName ?? auth.session?.firstName ?? ""
        return first.isEmpty ? "there" : first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header

                if let recap {
                    NavigationLink { StatsView() } label: {
                        WeekRecapCard(recap: recap)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 20)
                } else if loading {
                    SkeletonBlock(height: 110, radius: 18)
                        .padding(.horizontal, 20)
                }

                continueSection
                watchlistSection(
                    title: "Film watchlist",
                    empty: "Nothing queued — browse films and bookmark something.",
                    viewAll: .filmWatchlist,
                    items: filmWatchlist.map {
                        MediaItem(
                            id: Int($0.movieId) ?? abs($0.movieId.hashValue),
                            title: $0.movieTitle, name: nil, overview: nil,
                            poster_path: $0.posterPath, backdrop_path: nil,
                            release_date: nil, first_air_date: nil,
                            vote_average: nil, media_type: "movie", genre_ids: nil
                        )
                    },
                    isTV: false
                )
                watchlistSection(
                    title: "TV watchlist",
                    empty: "Save a show for later from search or TV.",
                    viewAll: .tvWatchlist,
                    items: tvWatchlist.map {
                        MediaItem(
                            id: Int($0.tvId) ?? abs($0.tvId.hashValue),
                            title: nil, name: $0.tvTitle, overview: nil,
                            poster_path: $0.posterPath, backdrop_path: nil,
                            release_date: nil, first_air_date: nil,
                            vote_average: nil, media_type: "tv", genre_ids: nil
                        )
                    },
                    isTV: true
                )

                if let error {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(theme.inkMuted)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
        }
        .background(theme.surface.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionKicker(text: "Your diary", accented: true)
            Text("Hey, \(greetingName)")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(theme.olive)
            Text("Pick up where you left off.")
                .foregroundStyle(theme.inkMuted)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var continueSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Continue watching")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                NavigationLink("Library") { TVLibraryView() }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.olive)
            }
            .padding(.horizontal, 20)

            if loading && continueItems.isEmpty {
                RailSkeleton()
            } else if continueItems.isEmpty {
                EmptyDiaryCard(
                    title: "Nothing in progress",
                    message: "Start tracking a show and your next episode will land here."
                )
                .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 14) {
                        ForEach(continueItems) { item in
                            NavigationLink {
                                TVContinueView(tvId: Int(item.tvId) ?? 0, seed: item, catalogTotal: catalogTotals[item.tvId])
                            } label: {
                                ContinueCard(item: item, catalogTotal: catalogTotals[item.tvId])
                            }
                            .buttonStyle(PressablePosterStyle())
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func watchlistSection(
        title: String,
        empty: String,
        viewAll: ProfileListKind,
        items: [MediaItem],
        isTV: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                if !items.isEmpty {
                    NavigationLink("View all") {
                        ProfileListView(kind: viewAll)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.olive)
                }
            }
            .padding(.horizontal, 20)

            if loading && items.isEmpty {
                RailSkeleton()
            } else if items.isEmpty {
                Text(empty)
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
                    .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 12) {
                        ForEach(items) { item in
                            MediaNavLink(id: item.id, kind: isTV ? .tv : .movie) {
                                PosterTile(title: item.displayTitle, posterPath: item.poster_path, year: item.year)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    private func load() async {
        loading = true
        defer { loading = false }
        do {
            async let c = DiaryService.continueWatching()
            async let f = DiaryService.movieWatchlist()
            async let t = DiaryService.tvWatchlist()
            async let r = DiaryService.weekRecap()
            continueItems = try await c
            filmWatchlist = try await f
            tvWatchlist = try await t
            recap = try? await r
            error = nil
            await enrichCatalogTotals()
        } catch {
            self.error = error.localizedDescription
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

    var body: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    SectionKicker(text: "This week", accented: true)
                    Spacer()
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
