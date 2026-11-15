import SwiftUI

struct StatsView: View {
    @Environment(\.marqueeTheme) private var theme
    @State private var stats: DashboardStats?
    @State private var recap: WeekRecap?
    @State private var loading = true
    @State private var error: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if loading && stats == nil {
                    VStack(spacing: 14) {
                        SkeletonBlock(height: 180, radius: 24)
                        SkeletonBlock(height: 90, radius: 18)
                        SkeletonBlock(height: 140, radius: 18)
                    }
                } else if let error, stats == nil {
                    EmptyDiaryCard(title: "Couldn’t load stats", message: error, cta: "Try again") {
                        Task { await load(refresh: true) }
                    }
                } else if isEmpty {
                    EmptyDiaryCard(
                        title: "The house lights are still up",
                        message: "Mark a film or an episode and this page becomes your screening log — hours in the dark, habits, taste.",
                        cta: nil
                    )
                } else {
                    marqueeHero
                    if let recap { weekTickets(recap) }
                    habitRow
                    libraryBlock
                    mostWatched
                    tasteBlock
                    funFacts
                    milestones
                }
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .background(theme.surface.ignoresSafeArea())
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

    private var marqueeHero: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(theme.olive)
            Circle()
                .fill(theme.accent.opacity(0.38))
                .frame(width: 180, height: 180)
                .blur(radius: 46)
                .offset(x: 210, y: -50)

            VStack(alignment: .leading, spacing: 10) {
                Text("IN THE DARK")
                    .font(.caption.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(MarqueeColor.saltGrey.opacity(0.7))
                Text(formatMinutes(stats?.overview?.totalMins ?? stats?.year?.totalMins ?? 0))
                    .font(.system(size: 44, weight: .bold, design: .serif))
                    .foregroundStyle(MarqueeColor.saltGrey)
                Text(screenDaysLine)
                    .font(.subheadline)
                    .foregroundStyle(MarqueeColor.saltGrey.opacity(0.78))
                Text(stats?.insight?.text ?? heroSubtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(MarqueeColor.saltGrey.opacity(0.88))
                    .padding(.top, 4)

                HStack(spacing: 8) {
                    heroChip("\(stats?.overview?.filmCount ?? 0) films")
                    heroChip("\(stats?.overview?.episodeCount ?? 0) episodes")
                    if let shows = stats?.overview?.tvShowCount, shows > 0 {
                        heroChip("\(shows) shows")
                    }
                }
                .padding(.top, 6)
            }
            .padding(22)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var heroSubtitle: String {
        let films = stats?.overview?.filmCount ?? 0
        let eps = stats?.overview?.episodeCount ?? 0
        return "\(films) films · \(eps) episodes logged"
    }

    private var screenDaysLine: String {
        let mins = stats?.overview?.totalMins ?? 0
        guard mins >= 60 else { return "Estimated watch time so far" }
        let days = Double(mins) / (60 * 24)
        if days < 1 {
            let hours = Int((Double(mins) / 60).rounded())
            return "About \(hours) hour\(hours == 1 ? "" : "s") of continuous watching"
        }
        let rounded = days < 10 ? (days * 10).rounded() / 10 : days.rounded()
        let label = rounded == 1 ? "1 day" : "\(rounded.clean) days"
        return "About \(label) of continuous watching"
    }

    private func heroChip(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(MarqueeColor.saltGrey)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(MarqueeColor.saltGrey.opacity(0.16))
            .clipShape(Capsule())
    }

    private func weekTickets(_ recap: WeekRecap) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionKicker(text: "This week", accented: true)
            HStack(spacing: 10) {
                weekCell("Films", recap.filmsThisWeek ?? 0)
                weekCell("Episodes", recap.episodesThisWeek ?? 0)
                weekCell("Minutes", recap.totalMinsThisWeek ?? 0)
            }
        }
    }

    private func weekCell(_ label: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(value)")
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.accent)
            Text(label)
                .font(.caption)
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(theme.surfaceElevated)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var habitRow: some View {
        let tickets = habitTickets
        if !tickets.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Habits")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(tickets, id: \.kicker) { ticket in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(ticket.kicker)
                                .font(.caption2.weight(.bold))
                                .tracking(0.8)
                                .textCase(.uppercase)
                                .foregroundStyle(theme.accent)
                            Text(ticket.headline)
                                .font(.title2.weight(.bold))
                                .foregroundStyle(theme.olive)
                            Text(ticket.line)
                                .font(.caption)
                                .foregroundStyle(theme.inkMuted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(theme.oliveSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            }
        }
    }

    private var habitTickets: [(kicker: String, headline: String, line: String)] {
        var out: [(kicker: String, headline: String, line: String)] = []
        if let day = stats?.activity?.busiestDay?.day {
            out.append(("Habit", day, weekdayQuirk(day)))
        }
        if let streak = stats?.activity?.streak, streak > 1 {
            let best = stats?.activity?.longestStreak ?? streak
            out.append(("On a run", "\(streak)d", best > streak ? "Best ever \(best) days" : "Consecutive days logged"))
        } else if let best = stats?.activity?.longestStreak, best > 1 {
            out.append(("Personal best", "\(best)d", "Longest stretch of daily logging"))
        }
        if let binge = stats?.funFacts?.biggestBinge, (binge.count ?? 0) > 1 {
            out.append(("Biggest day", "\(binge.count ?? 0)", "Titles in a single sitting"))
        }
        if let avg = stats?.funFacts?.avgMinsPerActiveDay, avg > 0 {
            out.append(("Typical night", "\(avg)m", "Average minutes on days you log"))
        }
        return Array(out.prefix(4))
    }

    private func weekdayQuirk(_ day: String) -> String {
        switch day {
        case "Monday": return "You ease into the week on the couch"
        case "Tuesday": return "Tuesdays are when you actually press play"
        case "Wednesday": return "Midweek is your sweet spot"
        case "Thursday": return "Almost-weekend energy"
        case "Friday": return "Friday nights belong to your queue"
        case "Saturday": return "Saturdays are for settling in"
        case "Sunday": return "Sundays are your screening day"
        default: return "\(day)s show up most in your diary"
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
            if let backlog = lib?.backlog, backlog > 0 {
                Text("\(backlog) aired episodes still waiting")
                    .font(.caption)
                    .foregroundStyle(theme.olive)
            }
        }
    }

    private func libTile(_ title: String, _ count: Int) -> some View {
        VStack(spacing: 6) {
            Text("\(count)")
                .font(.title.weight(.bold))
                .foregroundStyle(theme.olive)
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

    @ViewBuilder
    private var mostWatched: some View {
        if let show = stats?.funFacts?.mostWatchedShow, (show.episodeCount ?? 0) > 1 {
            VStack(alignment: .leading, spacing: 12) {
                Text("Most watched")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                HStack(spacing: 14) {
                    CachedAsyncImage(url: AppConfig.posterURL(path: show.tvPosterImage))
                        .frame(width: 64, height: 96)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    VStack(alignment: .leading, spacing: 6) {
                        Text(show.tvTitle ?? "Show")
                            .font(.headline)
                            .foregroundStyle(theme.ink)
                        Text("\(show.episodeCount ?? 0) episodes")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(theme.olive)
                        if let mins = show.minutes, mins > 0 {
                            Text(formatMinutes(mins))
                                .font(.caption)
                                .foregroundStyle(theme.inkMuted)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(14)
                .background(theme.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
        }
    }

    @ViewBuilder
    private var tasteBlock: some View {
        let genres = stats?.taste?.genres ?? []
        if !genres.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Taste")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                let maxCount = max(genres.prefix(6).map(\.amount).max() ?? 1, 1)
                ForEach(Array(genres.prefix(6))) { g in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(g.name ?? "Genre")
                                .foregroundStyle(theme.ink)
                            Spacer()
                            Text("\(g.amount)")
                                .fontWeight(.semibold)
                                .foregroundStyle(theme.olive)
                        }
                        GeometryReader { geo in
                            Capsule()
                                .fill(theme.olive.opacity(0.18))
                                .overlay(alignment: .leading) {
                                    Capsule()
                                        .fill(theme.olive)
                                        .frame(width: geo.size.width * CGFloat(g.amount) / CGFloat(maxCount))
                                }
                        }
                        .frame(height: 7)
                    }
                }
            }
            .padding(16)
            .background(theme.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder
    private var funFacts: some View {
        let longest = stats?.films?.longest
        let avg = stats?.ratings?.films?.average
        if longest != nil || (avg ?? 0) > 0 {
            VStack(alignment: .leading, spacing: 12) {
                Text("In the booth")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                if let longest, let title = longest.movieTitle {
                    factRow("Longest film", title, longest.minutes.map { formatMinutes($0) })
                }
                if let avg, avg > 0 {
                    factRow("Film ratings", String(format: "%.1f / 5", avg), "\(stats?.ratings?.films?.count ?? 0) rated")
                }
                if let showAvg = stats?.ratings?.shows?.average, showAvg > 0 {
                    factRow("Show ratings", String(format: "%.1f / 5", showAvg), "\(stats?.ratings?.shows?.count ?? 0) rated")
                }
            }
        }
    }

    private func factRow(_ kicker: String, _ title: String, _ meta: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(kicker)
                .font(.caption2.weight(.bold))
                .tracking(0.8)
                .textCase(.uppercase)
                .foregroundStyle(theme.olive)
            Text(title)
                .font(.headline)
                .foregroundStyle(theme.ink)
            if let meta {
                Text(meta)
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.oliveSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var milestones: some View {
        if let items = stats?.milestones, !items.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Punched tickets")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                FlexibleChipWrap(items: items.compactMap(\.label))
            }
        }
    }

    private func formatMinutes(_ mins: Int) -> String {
        if mins <= 0 { return "—" }
        let h = mins / 60
        let m = mins % 60
        if h >= 24 {
            let d = h / 24
            let rh = h % 24
            return rh == 0 ? "\(d)d" : "\(d)d \(rh)h"
        }
        if h == 0 { return "\(m)m" }
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func load(refresh: Bool) async {
        loading = true
        defer { loading = false }
        do {
            async let s = DiaryService.dashboardStats(refresh: refresh)
            async let r = DiaryService.weekRecap()
            stats = try await s
            recap = try? await r
            error = nil
        } catch {
            self.error = error.localizedDescription
        }
    }
}

private struct FlexibleChipWrap: View {
    @Environment(\.marqueeTheme) private var theme
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                Text(item)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(theme.olive)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(theme.oliveSoft)
                    .clipShape(Capsule())
            }
        }
    }
}

private extension Double {
    var clean: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self)
    }
}
