import SwiftUI

struct StatsView: View {
    @Environment(\.marqueeTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stats: DashboardStats?
    @State private var loading = true
    @State private var error: String?
    @State private var rangeKey: StatsRangeKey = .week
    @State private var tasteRoom: TasteRoom = .tv
    @State private var didPickInitialRange = false

    private enum TasteRoom: String, CaseIterable, Identifiable {
        case tv = "TV"
        case films = "Films"
        var id: String { rawValue }
    }

    private var range: StatsRange? { stats?.ranges?[rangeKey] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                if loading && stats == nil {
                    skeleton
                } else if let error, stats == nil {
                    ErrorStateView(message: error) {
                        Task { await load(refresh: true) }
                    }
                } else if isEmpty {
                    EmptyDiaryCard(
                        title: "The house lights are still up",
                        message: "Mark a film or an episode and this page becomes your lobby diary: when you watch, what you rewatch, and the nights that stuck.",
                        cta: nil
                    )
                } else {
                    MarqueeHero(
                        rangeKey: rangeKey,
                        range: range,
                        dateLine: StatsDates.rangeLine(rangeKey, start: range?.start, end: range?.end)
                    )
                    .animation(reduceMotion ? nil : MarqueeMotion.standard, value: rangeKey)

                    rangeSections
                        .id(rangeKey)
                        .transition(reduceMotion ? AnyTransition.opacity : AnyTransition(.blurReplace))

                    allTimeSections
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
        .safeAreaInset(edge: .top, spacing: 0) {
            if stats != nil, !isEmpty {
                StatsRangeSwitch(selection: $rangeKey)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
            }
        }
        .refreshable { await load(refresh: true) }
        .task { await load(refresh: false) }
    }

    // MARK: Range-scoped

    @ViewBuilder
    private var rangeSections: some View {
        if let range, !range.isQuiet {
            VStack(alignment: .leading, spacing: 28) {
                if let trend = range.trend, !(trend.buckets ?? []).isEmpty {
                    RunChart(rangeKey: rangeKey, trend: trend)
                        .stageIn(reduceMotion)
                }

                TicketStubRow(activity: stats?.activity, memberSince: stats?.memberSince)
                    .stageIn(reduceMotion)

                if let rhythm = range.rhythm, (rhythm.peakMins ?? 0) > 0 {
                    HouseLightsDial(
                        hours: paddedHours(rhythm.byHour),
                        peakHour: rhythm.peakHour ?? 0,
                        caption: rhythm.caption ?? "Your lobby hours"
                    )
                    .stageIn(reduceMotion)
                }

                if let shows = range.topShows, !shows.isEmpty {
                    TopBillingList(shows: shows)
                        .stageIn(reduceMotion)
                }

                if let films = range.films, !films.isEmpty {
                    FilmsOnMarqueeRail(films: films, total: range.totals?.filmPlays ?? films.count)
                }

                if let night = range.biggestNight, (night.count ?? 0) > 1 {
                    BiggestNightStrip(night: night)
                }

                tasteBlock(range.taste)
                    .stageIn(reduceMotion)

                if let takes = range.hotTakes, !takes.isEmpty {
                    HotTakesBlock(takes: takes)
                        .stageIn(reduceMotion)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: 28) {
                TicketStubRow(activity: stats?.activity, memberSince: stats?.memberSince)
                if let last = stats?.activity?.lastWatchedAt, let day = StatsDates.shortDay(last) {
                    Text("Last in the lobby on \(day). Switch the range to look back.")
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                }
            }
        }
    }

    // MARK: All time

    @ViewBuilder
    private var allTimeSections: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 10) {
                Rectangle().fill(theme.border).frame(height: 1)
                SectionKicker(text: "Across the diary")
                    .fixedSize()
                Rectangle().fill(theme.border).frame(height: 1)
            }
            .padding(.top, 8)
            .accessibilityAddTraits(.isHeader)

            if let lobby = stats?.lobbyType {
                LobbyTypePlaque(lobby: lobby)
                    .stageIn(reduceMotion)
            }
            if let library = stats?.library, (library.totalTracked ?? 0) > 0 {
                ShelvesBlock(library: library)
                    .stageIn(reduceMotion)
            }
            if let arcs = stats?.seasonArcs, !arcs.isEmpty {
                SeasonArcRibbons(arcs: arcs)
            }
            BadgeCabinet(badges: BadgeCatalog.badges(from: stats))
                .stageIn(reduceMotion)
            if let since = memberSinceLine {
                Text(since)
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }

    private var memberSinceLine: String? {
        guard let raw = stats?.memberSince else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) else { return nil }
        return "In the lobby since \(date.formatted(.dateTime.month(.wide).year()))"
    }

    // MARK: Taste

    @ViewBuilder
    private func tasteBlock(_ taste: StatsTaste?) -> some View {
        let tvGenres = taste?.tv?.genreByEpisodes ?? []
        let filmGenres = taste?.films?.genreByCount ?? []
        if !tvGenres.isEmpty || !filmGenres.isEmpty {
            let room: TasteRoom = tvGenres.isEmpty ? .films : (filmGenres.isEmpty ? .tv : tasteRoom)
            VStack(alignment: .leading, spacing: 14) {
                StatsSectionHeader(kicker: "Taste", title: "What filled the screen")
                if !tvGenres.isEmpty && !filmGenres.isEmpty {
                    Picker("Room", selection: $tasteRoom.animation(MarqueeMotion.standard)) {
                        ForEach(TasteRoom.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                GenreMeterList(items: Array((room == .tv ? tvGenres : filmGenres).prefix(6)), tint: theme.olive)
                    .id(room)
                    .transition(.opacity)
            }
        }
    }

    // MARK: Loading

    private var skeleton: some View {
        VStack(spacing: 16) {
            SkeletonBlock(height: 44, radius: 22)
            SkeletonBlock(height: 280, radius: 28)
            SkeletonBlock(height: 200, radius: 20)
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

    private func paddedHours(_ hours: [StatsHourBucket]?) -> [StatsHourBucket] {
        var out = Array(repeating: StatsHourBucket(), count: 24)
        guard let hours else { return out }
        for (i, bucket) in hours.prefix(24).enumerated() {
            out[i] = bucket
        }
        return out
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

    /// Open on the narrowest range that has something in it, so first look is never "0m".
    private func pickInitialRange(_ stats: DashboardStats) {
        guard !didPickInitialRange, let ranges = stats.ranges else { return }
        didPickInitialRange = true
        rangeKey = StatsRangeKey.allCases.first { ranges[$0]?.isQuiet == false } ?? .week
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
