import SwiftUI

struct StatsView: View {
    @Environment(\.marqueeTheme) private var theme
    @State private var stats: DashboardStats?
    @State private var recap: WeekRecap?
    @State private var loading = true
    @State private var error: String?
    @State private var tasteRoom: TasteRoom = .tv

    private enum TasteRoom: String, CaseIterable, Identifiable {
        case tv = "TV"
        case films = "Films"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if loading && stats == nil {
                    VStack(spacing: 14) {
                        HStack(spacing: 10) {
                            SkeletonBlock(height: 150, radius: 22)
                            SkeletonBlock(height: 150, radius: 22)
                        }
                        SkeletonBlock(height: 180, radius: 20)
                        SkeletonBlock(height: 140, radius: 20)
                    }
                } else if let error, stats == nil {
                    EmptyDiaryCard(title: "Couldn’t load stats", message: error, cta: "Try again") {
                        Task { await load(refresh: true) }
                    }
                } else if isEmpty {
                    EmptyDiaryCard(
                        title: "The house lights are still up",
                        message: "Mark a film or an episode and this page becomes two diaries — TV hours, film hours, badges, and the days you actually sat down.",
                        cta: nil
                    )
                } else {
                    twinReels
                    if let recap { weekStrip(recap) }
                    if !weekdayPoints.isEmpty {
                        WeekdayRhythmChart(days: weekdayPoints)
                    }
                    if !weekTrendPoints.isEmpty {
                        TwelveWeekChart(points: weekTrendPoints)
                    }
                    spotlight
                    tasteBlock
                    libraryBlock
                    BadgeCabinet(badges: BadgeCatalog.badges(from: stats))
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .marqueeCanvas()
        .navigationTitle("Stats")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await load(refresh: true) }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(theme.olive)
                }
            }
        }
        .task { await load(refresh: false) }
    }

    private var isEmpty: Bool {
        let o = stats?.overview
        return (o?.episodeCount ?? 0) == 0 && (o?.filmCount ?? 0) == 0
            && (stats?.library?.totalTracked ?? 0) == 0
    }

    private var twinReels: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let text = stats?.insight?.text, !text.isEmpty {
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(theme.inkMuted)
            }
            HStack(alignment: .top, spacing: 10) {
                ReelCard(
                    kicker: "TV",
                    time: StatsFormat.span(stats?.overview?.tvMins ?? stats?.year?.tvMins ?? 0),
                    line: tvReelLine,
                    tint: theme.olive,
                    symbol: "tv.fill"
                )
                ReelCard(
                    kicker: "Films",
                    time: StatsFormat.span(stats?.overview?.filmMins ?? stats?.films?.filmMins ?? 0),
                    line: filmReelLine,
                    tint: theme.accent,
                    symbol: "film.fill"
                )
            }
        }
    }

    private var tvReelLine: String {
        let eps = stats?.overview?.episodeCount ?? 0
        let shows = stats?.overview?.tvShowCount ?? 0
        var parts: [String] = []
        if eps > 0 { parts.append("\(eps) episodes") }
        if shows > 0 { parts.append("\(shows) shows") }
        return parts.isEmpty ? "No episodes yet" : parts.joined(separator: " · ")
    }

    private var filmReelLine: String {
        let films = stats?.overview?.filmCount ?? stats?.films?.count ?? 0
        if films == 0 { return "No films yet" }
        if let avg = stats?.films?.avgRuntime, avg > 0 {
            return "\(films) films · \(avg)m typical"
        }
        return "\(films) films"
    }

    private func weekStrip(_ recap: WeekRecap) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionKicker(text: "This week", accented: true)
            HStack(spacing: 10) {
                weekCell(
                    "TV",
                    recap.episodesThisWeek ?? 0,
                    StatsFormat.minutes(recap.tvMinsThisWeek ?? stats?.activity?.tvMinsThisWeek ?? 0),
                    theme.olive
                )
                weekCell(
                    "Films",
                    recap.filmsThisWeek ?? 0,
                    StatsFormat.minutes(recap.filmMinsThisWeek ?? stats?.activity?.filmMinsThisWeek ?? 0),
                    theme.accent
                )
            }
        }
    }

    private func weekCell(_ kind: String, _ count: Int, _ time: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kind)
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(tint)
            Text("\(count)")
                .font(.title.weight(.bold))
                .foregroundStyle(theme.ink)
                .monospacedDigit()
            Text(kind == "TV" ? "episodes" : "films")
                .font(.caption)
                .foregroundStyle(theme.inkMuted)
            Text(time)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var weekdayPoints: [WeekdayPoint] {
        let names = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        let labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var tv = Array(repeating: 0, count: 7)
        var films = Array(repeating: 0, count: 7)
        for day in stats?.activity?.dailyActivity ?? [] {
            guard let key = day.date, let idx = StatsFormat.weekdayIndex(for: key) else { continue }
            let tvMins = day.tvMinutes ?? 0
            let filmMins = day.filmMinutes ?? 0
            if tvMins + filmMins > 0 {
                tv[idx] += tvMins
                films[idx] += filmMins
            } else {
                tv[idx] += (day.episodes ?? 0) * 42
                films[idx] += (day.films ?? 0) * 110
            }
        }
        return zip(labels, zip(names, zip(tv, films))).map { label, rest in
            WeekdayPoint(label: label, fullName: rest.0, tvMins: rest.1.0, filmMins: rest.1.1)
        }
    }

    private var weekTrendPoints: [TrendPoint] {
        let weeks = stats?.activity?.weeklyTrend ?? []
        return weeks.suffix(12).enumerated().flatMap { index, bucket -> [TrendPoint] in
            let label = bucket.weekStart ?? "\(index)"
            let tv = bucket.tvMinutes ?? max(0, (bucket.minutes ?? 0) - (bucket.filmMinutes ?? 0))
            let films = bucket.filmMinutes ?? 0
            return [
                TrendPoint(id: "tv-\(label)", label: label, kind: "TV", minutes: tv),
                TrendPoint(id: "film-\(label)", label: label, kind: "Films", minutes: films)
            ]
        }
    }

    @ViewBuilder
    private var spotlight: some View {
        let show = stats?.funFacts?.mostWatchedShow
        let longest = stats?.films?.longest
        let shortest = stats?.films?.shortest
        if show != nil || longest != nil {
            VStack(alignment: .leading, spacing: 12) {
                Text("On a loop")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                if let show, (show.episodeCount ?? 0) > 0 {
                    HStack(spacing: 14) {
                        CachedAsyncImage(url: AppConfig.posterURL(path: show.tvPosterImage))
                            .frame(width: 56, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        VStack(alignment: .leading, spacing: 4) {
                            SectionKicker(text: "Most watched show")
                            Text(show.tvTitle ?? "Show")
                                .font(.headline)
                                .foregroundStyle(theme.ink)
                            Text("\(show.episodeCount ?? 0) episodes · \(StatsFormat.minutes(show.minutes ?? 0))")
                                .font(.caption)
                                .foregroundStyle(theme.olive)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(12)
                    .background(theme.oliveSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                if longest != nil || shortest != nil {
                    HStack(spacing: 10) {
                        if let longest {
                            filmFact("Longest film", longest.movieTitle ?? "Film", StatsFormat.minutes(longest.minutes ?? 0), theme.accent)
                        }
                        if let shortest, shortest.movieId != longest?.movieId {
                            filmFact("Shortest film", shortest.movieTitle ?? "Film", StatsFormat.minutes(shortest.minutes ?? 0), theme.olive)
                        }
                    }
                }
                ratingsRow
            }
        }
    }

    private func filmFact(_ kicker: String, _ title: String, _ meta: String, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(kicker)
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .textCase(.uppercase)
                .foregroundStyle(tint)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(theme.ink)
                .lineLimit(2)
                .frame(minHeight: 36, alignment: .top)
            Text(meta)
                .font(.caption.weight(.bold))
                .foregroundStyle(tint)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var ratingsRow: some View {
        let filmAvg = stats?.ratings?.films?.average ?? 0
        let showAvg = stats?.ratings?.shows?.average ?? 0
        if filmAvg > 0 || showAvg > 0 {
            HStack(spacing: 10) {
                if filmAvg > 0 {
                    ratingCard("Film ratings", filmAvg, stats?.ratings?.films?.count ?? 0, theme.accent)
                }
                if showAvg > 0 {
                    ratingCard("Show ratings", showAvg, stats?.ratings?.shows?.count ?? 0, theme.olive)
                }
            }
        }
    }

    private func ratingCard(_ title: String, _ avg: Double, _ count: Int, _ tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2.weight(.bold))
                .tracking(0.7)
                .textCase(.uppercase)
                .foregroundStyle(theme.inkMuted)
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(String(format: "%.1f", avg))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(theme.ink)
                    .monospacedDigit()
            }
            Text("\(count) rated")
                .font(.caption)
                .foregroundStyle(theme.inkMuted)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var tasteBlock: some View {
        let tvGenres = stats?.taste?.tv?.genreByEpisodes ?? []
        let filmGenres = stats?.taste?.films?.genreByCount ?? []
        let tvDecades = stats?.taste?.tv?.decades ?? []
        let filmDecades = stats?.taste?.films?.decades ?? []
        if !tvGenres.isEmpty || !filmGenres.isEmpty || tvDecades.count > 1 || filmDecades.count > 1 {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Taste")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Picker("Taste", selection: $tasteRoom) {
                        ForEach(TasteRoom.allCases) { room in
                            Text(room.rawValue).tag(room)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 160)
                }
                if tasteRoom == .tv {
                    if tvGenres.isEmpty {
                        Text("Log more episodes to see TV taste.")
                            .font(.caption)
                            .foregroundStyle(theme.inkMuted)
                    } else {
                        GenreMeterList(items: tvGenres, tint: theme.olive)
                    }
                    if tvDecades.count > 1 {
                        DecadeMeterList(title: "First-aired decades", decades: tvDecades, tint: theme.olive)
                    }
                } else {
                    if filmGenres.isEmpty {
                        Text("Log more films to see movie taste.")
                            .font(.caption)
                            .foregroundStyle(theme.inkMuted)
                    } else {
                        GenreMeterList(items: filmGenres, tint: theme.accent)
                    }
                    if filmDecades.count > 1 {
                        DecadeMeterList(title: "Release decades", decades: filmDecades, tint: theme.accent)
                    }
                }
            }
            .padding(16)
            .background(theme.surfaceElevated.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(theme.border, lineWidth: 1)
            )
        }
    }

    private var libraryBlock: some View {
        let lib = stats?.library
        return VStack(alignment: .leading, spacing: 12) {
            Text("The shelves")
                .font(.title3.weight(.semibold))
                .foregroundStyle(theme.ink)
            HStack(spacing: 10) {
                libTile("Watching", lib?.watching ?? 0)
                libTile("Paused", lib?.pausedCount ?? 0)
                libTile("Finished", lib?.finished ?? 0)
            }
            if let rate = lib?.completionRate, (lib?.totalTracked ?? 0) > 0 {
                Text("\(rate)% of tracked shows finished")
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
            }
        }
    }

    private func libTile(_ title: String, _ count: Int) -> some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.title.weight(.bold))
                .foregroundStyle(theme.olive)
                .monospacedDigit()
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func load(refresh: Bool) async {
        if stats == nil { loading = true }
        do {
            async let s = DiaryService.dashboardStats(refresh: refresh)
            async let r = DiaryService.weekRecap()
            let dash = try await s
            let week = try? await r
            stats = dash
            recap = week
            error = nil
            loading = false
        } catch {
            self.error = error.localizedDescription
            loading = false
        }
    }
}

private struct ReelCard: View {
    @Environment(\.marqueeTheme) private var theme
    let kicker: String
    let time: String
    let line: String
    let tint: Color
    let symbol: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: symbol)
                    .font(.caption.weight(.bold))
                Text(kicker)
                    .font(.caption.weight(.bold))
                    .tracking(1.1)
                    .textCase(.uppercase)
            }
            .foregroundStyle(MarqueeColor.saltGrey.opacity(0.78))

            Text(time)
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(MarqueeColor.saltGrey)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(line)
                .font(.caption)
                .foregroundStyle(MarqueeColor.saltGrey.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(tint)
        }
    }
}
