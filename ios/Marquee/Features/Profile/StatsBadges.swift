import SwiftUI

struct DiaryBadge: Identifiable {
    enum Kind { case tv, film, habit }

    let id: String
    let title: String
    let detail: String
    let symbol: String
    let kind: Kind
    let current: Int
    let target: Int

    var earned: Bool { current >= target }
    var progress: Double {
        guard target > 0 else { return 0 }
        return min(1, Double(current) / Double(target))
    }
}

enum BadgeCatalog {
    static func badges(from stats: DashboardStats?) -> [DiaryBadge] {
        let o = stats?.overview
        let lib = stats?.library
        let films = stats?.films
        let activity = stats?.activity
        let binge = stats?.funFacts?.biggestBinge
        let filmRatings = stats?.ratings?.films?.count ?? 0
        let showRatings = stats?.ratings?.shows?.count ?? 0

        let episodes = o?.episodeCount ?? 0
        let filmCount = o?.filmCount ?? films?.count ?? 0
        let tvMins = o?.tvMins ?? 0
        let filmMins = o?.filmMins ?? 0
        let finished = lib?.finished ?? 0
        let streakBest = max(activity?.streak ?? 0, activity?.longestStreak ?? 0)
        let bingeCount = binge?.count ?? 0

        return [
            DiaryBadge(id: "ep-1", title: "Lights down", detail: "Log your first episode", symbol: "tv", kind: .tv, current: episodes, target: 1),
            DiaryBadge(id: "ep-100", title: "Hundredth seat", detail: "100 episodes", symbol: "tv.fill", kind: .tv, current: episodes, target: 100),
            DiaryBadge(id: "ep-500", title: "Season regular", detail: "500 episodes", symbol: "play.rectangle.fill", kind: .tv, current: episodes, target: 500),
            DiaryBadge(id: "ep-1000", title: "Marathon member", detail: "1,000 episodes", symbol: "rectangle.stack.fill", kind: .tv, current: episodes, target: 1000),
            DiaryBadge(id: "finish-1", title: "Series closed", detail: "Finish a show", symbol: "checkmark.seal.fill", kind: .tv, current: finished, target: 1),
            DiaryBadge(id: "finish-10", title: "Ten finales", detail: "Finish 10 shows", symbol: "flag.checkered", kind: .tv, current: finished, target: 10),
            DiaryBadge(id: "tv-24h", title: "A day of TV", detail: "24 hours of episodes", symbol: "moon.stars.fill", kind: .tv, current: tvMins, target: 24 * 60),
            DiaryBadge(id: "tv-100h", title: "TV resident", detail: "100 hours of episodes", symbol: "sofa.fill", kind: .tv, current: tvMins, target: 100 * 60),

            DiaryBadge(id: "film-1", title: "First screening", detail: "Log your first film", symbol: "film", kind: .film, current: filmCount, target: 1),
            DiaryBadge(id: "film-25", title: "Short stack", detail: "25 films", symbol: "film.fill", kind: .film, current: filmCount, target: 25),
            DiaryBadge(id: "film-50", title: "Half century", detail: "50 films", symbol: "ticket.fill", kind: .film, current: filmCount, target: 50),
            DiaryBadge(id: "film-100", title: "Century club", detail: "100 films", symbol: "star.square.fill", kind: .film, current: filmCount, target: 100),
            DiaryBadge(id: "film-24h", title: "A day of films", detail: "24 hours of movies", symbol: "popcorn.fill", kind: .film, current: filmMins, target: 24 * 60),
            DiaryBadge(id: "film-100h", title: "Cinema regular", detail: "100 hours of movies", symbol: "theatermasks.fill", kind: .film, current: filmMins, target: 100 * 60),
            DiaryBadge(id: "critic", title: "House critic", detail: "Rate 10 films", symbol: "star.fill", kind: .film, current: filmRatings, target: 10),
            DiaryBadge(id: "show-critic", title: "Series critic", detail: "Rate 5 shows", symbol: "text.badge.star", kind: .tv, current: showRatings, target: 5),

            DiaryBadge(id: "streak-7", title: "Week in a row", detail: "7-day logging streak", symbol: "flame.fill", kind: .habit, current: streakBest, target: 7),
            DiaryBadge(id: "streak-30", title: "Month in the dark", detail: "30-day streak", symbol: "bolt.fill", kind: .habit, current: streakBest, target: 30),
            DiaryBadge(id: "binge", title: "One more episode", detail: "5 titles in a day", symbol: "forward.end.fill", kind: .habit, current: bingeCount, target: 5),
        ]
    }
}

struct BadgeCabinet: View {
    @Environment(\.marqueeTheme) private var theme
    let badges: [DiaryBadge]

    private var earnedCount: Int { badges.filter(\.earned).count }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Badges")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Text("\(earnedCount) of \(badges.count)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.olive)
                    .monospacedDigit()
            }

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                spacing: 16
            ) {
                ForEach(badges) { badge in
                    BadgeMedal(badge: badge)
                }
            }
        }
    }
}

private struct BadgeMedal: View {
    @Environment(\.marqueeTheme) private var theme
    let badge: DiaryBadge

    private var ink: Color {
        switch badge.kind {
        case .tv: return theme.olive
        case .film: return theme.accent
        case .habit: return theme.olive
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(ink.opacity(badge.earned ? 0 : 0.25), style: StrokeStyle(lineWidth: 2, dash: badge.earned ? [] : [4, 3]))
                    .frame(width: 64, height: 64)

                Circle()
                    .trim(from: 0, to: badge.earned ? 1 : badge.progress)
                    .stroke(ink, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 64, height: 64)

                Circle()
                    .fill(badge.earned ? ink : ink.opacity(0.10))
                    .frame(width: 52, height: 52)

                Image(systemName: badge.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(badge.earned ? MarqueeColor.saltGrey : ink.opacity(0.55))
            }
            .accessibilityHidden(true)

            Text(badge.title)
                .font(.caption.weight(.bold))
                .foregroundStyle(badge.earned ? theme.ink : theme.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 32, alignment: .top)

            Text(badge.earned ? badge.detail : remainingLine)
                .font(.caption2)
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 28, alignment: .top)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge.title). \(badge.earned ? "Earned. \(badge.detail)" : remainingLine)")
    }

    private var remainingLine: String {
        let left = max(badge.target - badge.current, 0)
        if badge.id.contains("tv-") || badge.id.contains("film-24") || badge.id.contains("film-100h") {
            return "\(StatsFormat.minutes(badge.current)) / \(StatsFormat.minutes(badge.target))"
        }
        return "\(badge.current)/\(badge.target)" + (left == 0 ? "" : "")
    }
}
