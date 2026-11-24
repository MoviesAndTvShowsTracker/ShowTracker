import SwiftUI

/// All-time diary stats. One "Lately" card carries the week/month/year view;
/// everything else is the whole diary: screen time, TV, films, habits, badges.
struct StatsView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stats: DashboardStats? = DiaryService.cachedDashboardStats()
    @State private var loading = true
    @State private var error: String?
    @State private var rangeKey: StatsRangeKey = .week
    @State private var decadeRoom: Room = .films
    @State private var didPickInitialRange = false

    private enum Room: String, CaseIterable, Identifiable {
        case films = "Films"
        case tv = "TV"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if loading && stats == nil {
                    skeleton
                } else if let error, stats == nil {
                    ErrorStateView(message: error) {
                        Task { await load(refresh: true) }
                    }
                } else if isEmpty {
                    EmptyDiaryCard(
                        title: "The house lights are still up",
                        message: "Mark a film or an episode and your screen time, top shows and favorite genres start filling in here.",
                        cta: nil
                    )
                } else if let stats {
                    ScreenTimeHero(overview: stats.overview, since: sinceLabel)

                    if let ranges = stats.ranges {
                        LatelyCard(ranges: ranges, rangeKey: $rangeKey)
                            .stageIn(reduceMotion)
                    }

                    TicketStubRow(activity: stats.activity, memberSince: stats.memberSince)
                        .stageIn(reduceMotion)

                    tvChapter(stats)
                    filmsChapter(stats)
                    habitsChapter(stats)

                    BadgeCabinet(badges: BadgeCatalog.badges(from: stats))
                        .padding(.top, 8)
                        .stageIn(reduceMotion)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
        .marqueeCanvas()
        .navigationTitle("Stats")
        .navigationBarTitleDisplayMode(.large)
        .refreshable { await load(refresh: true) }
        .task { await load(refresh: false) }
    }

    // MARK: TV

    @ViewBuilder
    private func tvChapter(_ stats: DashboardStats) -> some View {
        let o = stats.overview
        if (o?.episodeCount ?? 0) > 0 || (stats.library?.totalTracked ?? 0) > 0 {
            StatsChapterHeader(
                icon: "tv",
                title: "TV",
                summary: "\((o?.tvShowCount ?? 0).formatted()) shows · \((o?.episodeCount ?? 0).formatted()) episodes"
            )

            FactGrid(facts: [
                StatsFact(label: "Watch time", value: StatsFormat.span(o?.tvMins ?? 0)),
                StatsFact(label: "Avg episode", value: "\(stats.tv?.avgEpisodeMins ?? stats.funFacts?.avgEpisodeMins ?? 0)", unit: "min"),
                StatsFact(label: "Finished", value: "\(stats.library?.finished ?? 0)", unit: "shows"),
                (stats.ratings?.shows?.count ?? 0) > 0
                    ? StatsFact(label: "Your rating", value: ratingValue(stats.ratings?.shows), unit: ratingUnit(stats.ratings?.shows))
                    : StatsFact(label: "Watching", value: "\(stats.library?.watching ?? 0)", unit: "shows"),
            ])
            .stageIn(reduceMotion)

            if let shows = stats.ranges?.all?.topShows, !shows.isEmpty {
                TopBillingList(shows: shows)
                    .stageIn(reduceMotion)
            }

            if let library = stats.library, (library.totalTracked ?? 0) > 0 {
                ShowProgressBar(library: library)
                    .stageIn(reduceMotion)
            }

            if let genres = stats.taste?.tv?.genreByEpisodes, !genres.isEmpty {
                GlassCard(padding: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            SectionKicker(text: "TV genres")
                            Text("By episodes watched")
                                .font(.headline)
                                .foregroundStyle(theme.ink)
                        }
                        GenreMeterList(items: Array(genres.prefix(6)), tint: theme.olive)
                    }
                }
                .stageIn(reduceMotion)
            }

            if let rated = stats.tv?.topRated, !rated.isEmpty {
                RatedPosterRail(kicker: "Your top-rated shows", title: "Five-star television", items: rated, isTV: true)
            }
        }
    }

    // MARK: Films

    @ViewBuilder
    private func filmsChapter(_ stats: DashboardStats) -> some View {
        let o = stats.overview
        if (o?.filmCount ?? 0) > 0 {
            StatsChapterHeader(
                icon: "film",
                title: "Films",
                summary: "\((o?.filmCount ?? 0).formatted()) films · \((stats.films?.thisYear ?? 0).formatted()) this year"
            )

            FactGrid(facts: [
                StatsFact(label: "Watch time", value: StatsFormat.span(o?.filmMins ?? 0)),
                StatsFact(label: "Avg runtime", value: "\(stats.films?.avgRuntime ?? 0)", unit: "min"),
                StatsFact(label: "This year", value: "\(stats.films?.thisYear ?? 0)", unit: "films"),
                (stats.ratings?.films?.count ?? 0) > 0
                    ? StatsFact(label: "Your rating", value: ratingValue(stats.ratings?.films), unit: ratingUnit(stats.ratings?.films))
                    : StatsFact(label: "Total plays", value: "\((o?.filmPlayCount ?? o?.filmCount ?? 0).formatted())"),
            ])
            .stageIn(reduceMotion)

            if let rated = stats.films?.topRated, !rated.isEmpty {
                RatedPosterRail(kicker: "Your top-rated films", title: "The ones you'd see again", items: rated, isTV: false)
            }

            if let dist = stats.films?.ratingDistribution, dist.contains(where: { ($0.count ?? 0) > 0 }) {
                RatingHistogram(
                    buckets: dist,
                    average: stats.ratings?.films?.average,
                    count: stats.ratings?.films?.count
                )
                .stageIn(reduceMotion)
            }

            if let genres = stats.taste?.films?.genreByCount, !genres.isEmpty {
                GenreStack(kicker: "Film genres", genres: genres)
                    .stageIn(reduceMotion)
            }

            if stats.films?.longest != nil || stats.films?.shortest != nil {
                DoubleFeature(longest: stats.films?.longest, shortest: stats.films?.shortest)
                    .stageIn(reduceMotion)
            }

            if let films = stats.ranges?.all?.films, !films.isEmpty {
                FilmsOnMarqueeRail(films: films, total: o?.filmCount ?? films.count)
            }
        }
    }

    // MARK: Habits

    @ViewBuilder
    private func habitsChapter(_ stats: DashboardStats) -> some View {
        let weekday = stats.weekday ?? []
        let night = stats.biggestNight
        let tvDecades = stats.taste?.tv?.decades ?? []
        let filmDecades = stats.taste?.films?.decades ?? []
        let hasWeekday = weekday.contains { $0.totalMins > 0 }
        let hasNight = (night?.count ?? 0) > 1
        let hasDecades = !tvDecades.isEmpty || !filmDecades.isEmpty

        if hasWeekday || hasNight || hasDecades {
            StatsChapterHeader(icon: "calendar", title: "Habits", summary: habitsSummary(stats))

            if hasWeekday {
                WeekdayBars(days: weekday)
                    .stageIn(reduceMotion)
            }

            if let night, hasNight {
                BiggestNightStrip(night: night)
            }

            if hasDecades {
                let room: Room = filmDecades.isEmpty ? .tv : (tvDecades.isEmpty ? .films : decadeRoom)
                GlassCard(padding: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 4) {
                                SectionKicker(text: "Decades")
                                Text(topDecadeLine(room == .films ? filmDecades : tvDecades))
                                    .font(.headline)
                                    .foregroundStyle(theme.ink)
                            }
                            Spacer()
                            if !tvDecades.isEmpty && !filmDecades.isEmpty {
                                Picker("Decades", selection: $decadeRoom.animation(MarqueeMotion.standard)) {
                                    ForEach(Room.allCases) { Text($0.rawValue).tag($0) }
                                }
                                .pickerStyle(.segmented)
                                .frame(width: 130)
                            }
                        }
                        DecadeMeterList(
                            title: "",
                            decades: topDecades(room == .films ? filmDecades : tvDecades),
                            tint: theme.olive
                        )
                        .id(room)
                        .transition(.opacity)
                    }
                }
                .stageIn(reduceMotion)
            }
        }
    }

    /// The six biggest decades, shown in date order.
    private func topDecades(_ decades: [TasteDecade]) -> [TasteDecade] {
        decades
            .sorted { ($0.count ?? 0) > ($1.count ?? 0) }
            .prefix(6)
            .sorted { ($0.decade ?? "") < ($1.decade ?? "") }
    }

    private func habitsSummary(_ stats: DashboardStats) -> String? {
        guard let avg = stats.funFacts?.avgMinsPerActiveDay, avg > 0 else { return nil }
        return "\(StatsFormat.minutes(avg)) on an average watching day"
    }

    private func topDecadeLine(_ decades: [TasteDecade]) -> String {
        guard let top = decades.max(by: { ($0.count ?? 0) < ($1.count ?? 0) }), let d = top.decade else {
            return "Across the eras"
        }
        return "Most at home in the \(d)"
    }

    // MARK: Helpers

    private func ratingValue(_ summary: StatsRatingSummary?) -> String {
        guard let avg = summary?.average, avg > 0 else { return "—" }
        return String(format: "%.1f", avg)
    }

    private func ratingUnit(_ summary: StatsRatingSummary?) -> String? {
        guard let n = summary?.count, n > 0 else { return nil }
        return "★ · \(n)"
    }

    private var sinceLabel: String? {
        let raw = stats?.activity?.firstLoggedOn ?? stats?.memberSince
        guard let raw, let date = StatsDates.date(fromKey: raw) else { return nil }
        return date.formatted(.dateTime.month(.abbreviated).year())
    }

    private var skeleton: some View {
        VStack(spacing: 16) {
            SkeletonBlock(height: 300, radius: 28)
            SkeletonBlock(height: 240, radius: 20)
            HStack(spacing: 10) {
                SkeletonBlock(height: 72, radius: 14)
                SkeletonBlock(height: 72, radius: 14)
                SkeletonBlock(height: 72, radius: 14)
            }
        }
        .accessibilityLabel("Loading stats")
    }

    private var isEmpty: Bool {
        let o = stats?.overview
        return (o?.episodeCount ?? 0) == 0 && (o?.filmCount ?? 0) == 0
            && (stats?.library?.totalTracked ?? 0) == 0
    }

    private func load(refresh: Bool) async {
        if stats == nil { loading = true }
        error = nil
        defer { loading = false }
        do {
            let fresh = try await DiaryService.dashboardStats(refresh: refresh)
            stats = fresh
            pickInitialRange(fresh)
        } catch is CancellationError {
            return
        } catch {
            if stats == nil {
                self.error = error.localizedDescription
            }
        }
    }

    /// Lately opens on the narrowest range that has something in it.
    private func pickInitialRange(_ stats: DashboardStats) {
        guard !didPickInitialRange, let ranges = stats.ranges else { return }
        didPickInitialRange = true
        rangeKey = [StatsRangeKey.week, .month, .year].first { ranges[$0]?.isQuiet == false } ?? .week
    }
}

private extension View {
    /// Cards settle in as they scroll into view: a small lift and fade.
    func stageIn(_ reduceMotion: Bool) -> some View {
        scrollTransition(.animated(MarqueeMotion.standard)) { content, phase in
            content
                .opacity(reduceMotion || phase.isIdentity ? 1 : 0.4)
                .scaleEffect(reduceMotion || phase.isIdentity ? 1 : 0.97)
                .offset(y: reduceMotion || phase.isIdentity ? 0 : (phase == .bottomTrailing ? 16 : 0))
        }
    }
}
