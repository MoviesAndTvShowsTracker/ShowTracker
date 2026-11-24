import SwiftUI

struct DiaryBadge: Identifiable {
    enum Kind: String { case tv = "TV", film = "Films", habit = "Habits" }

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
            DiaryBadge(id: "ep-1", title: "Lights down", detail: "First episode", symbol: "lightbulb.fill", kind: .tv, current: episodes, target: 1),
            DiaryBadge(id: "ep-100", title: "Hundredth seat", detail: "100 episodes", symbol: "number", kind: .tv, current: episodes, target: 100),
            DiaryBadge(id: "ep-500", title: "Season regular", detail: "500 episodes", symbol: "rectangle.stack.fill", kind: .tv, current: episodes, target: 500),
            DiaryBadge(id: "ep-1000", title: "Marathon member", detail: "1,000 episodes", symbol: "infinity", kind: .tv, current: episodes, target: 1000),
            DiaryBadge(id: "finish-1", title: "Series closed", detail: "Finish a show", symbol: "checkmark.seal.fill", kind: .tv, current: finished, target: 1),
            DiaryBadge(id: "finish-10", title: "Ten finales", detail: "10 shows finished", symbol: "flag.checkered", kind: .tv, current: finished, target: 10),
            DiaryBadge(id: "tv-24h", title: "A day of TV", detail: "24 hours of episodes", symbol: "moon.stars.fill", kind: .tv, current: tvMins, target: 24 * 60),
            DiaryBadge(id: "tv-100h", title: "TV resident", detail: "100 hours of episodes", symbol: "hourglass", kind: .tv, current: tvMins, target: 100 * 60),
            DiaryBadge(id: "show-critic", title: "Series critic", detail: "Rate 5 shows", symbol: "star.circle.fill", kind: .tv, current: showRatings, target: 5),

            DiaryBadge(id: "film-1", title: "First screening", detail: "First film", symbol: "film.fill", kind: .film, current: filmCount, target: 1),
            DiaryBadge(id: "film-25", title: "Short stack", detail: "25 films", symbol: "square.stack.3d.up.fill", kind: .film, current: filmCount, target: 25),
            DiaryBadge(id: "film-50", title: "Half century", detail: "50 films", symbol: "ticket.fill", kind: .film, current: filmCount, target: 50),
            DiaryBadge(id: "film-100", title: "Century club", detail: "100 films", symbol: "play.square.fill", kind: .film, current: filmCount, target: 100),
            DiaryBadge(id: "film-24h", title: "A day of films", detail: "24 hours of movies", symbol: "popcorn.fill", kind: .film, current: filmMins, target: 24 * 60),
            DiaryBadge(id: "film-100h", title: "Cinema regular", detail: "100 hours of movies", symbol: "theatermasks.fill", kind: .film, current: filmMins, target: 100 * 60),
            DiaryBadge(id: "critic", title: "House critic", detail: "Rate 10 films", symbol: "star.fill", kind: .film, current: filmRatings, target: 10),

            DiaryBadge(id: "streak-7", title: "Week in a row", detail: "7-day streak", symbol: "flame.fill", kind: .habit, current: streakBest, target: 7),
            DiaryBadge(id: "streak-30", title: "Month in the dark", detail: "30-day streak", symbol: "bolt.fill", kind: .habit, current: streakBest, target: 30),
            DiaryBadge(id: "binge", title: "One more", detail: "5 titles in a day", symbol: "forward.end.fill", kind: .habit, current: bingeCount, target: 5),
        ]
    }
}

/// A round medal: olive when earned, faint with a progress ring when not.
struct BadgeMedal: View {
    @Environment(\.marqueeTheme) private var theme
    let badge: DiaryBadge
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            Circle().fill(badge.earned ? theme.olive : theme.surfaceElevated)
            if !badge.earned {
                Circle().stroke(theme.border, lineWidth: 2)
                Circle()
                    .trim(from: 0, to: badge.progress)
                    .stroke(theme.olive.opacity(0.55), style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            Image(systemName: badge.symbol)
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(badge.earned ? MarqueeColor.saltGrey : theme.inkMuted.opacity(0.6))
        }
        .frame(width: size, height: size)
        .overlay(Circle().stroke(theme.surfaceElevated, lineWidth: size < 48 ? 2 : 0))
        .accessibilityHidden(true)
    }
}

/// All badges as a medal grid, Apple Fitness style. Tap one for what it takes.
struct BadgeCabinet: View {
    @Environment(\.marqueeTheme) private var theme
    let badges: [DiaryBadge]
    @State private var selected: DiaryBadge?

    private var earnedCount: Int { badges.filter(\.earned).count }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text("Badges")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Text("\(earnedCount) of \(badges.count)")
                    .font(.subheadline)
                    .foregroundStyle(theme.inkMuted)
                    .monospacedDigit()
            }

            LazyVGrid(columns: columns, spacing: 18) {
                ForEach(badges.sorted { $0.earned && !$1.earned }) { badge in
                    Button { selected = badge } label: {
                        VStack(spacing: 6) {
                            BadgeMedal(badge: badge)
                            Text(badge.title)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(badge.earned ? theme.ink : theme.inkMuted)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(PressablePosterStyle())
                    .accessibilityLabel("\(badge.title). \(badge.detail). \(badge.earned ? "Earned" : "Not yet earned")")
                }
            }
        }
        .sheet(item: $selected) { badge in
            BadgeDetailSheet(badge: badge)
                .presentationDetents([.height(300)])
        }
    }
}

private struct BadgeDetailSheet: View {
    @Environment(\.marqueeTheme) private var theme
    let badge: DiaryBadge

    var body: some View {
        VStack(spacing: 14) {
            BadgeMedal(badge: badge, size: 84)
            Text(badge.title)
                .font(.title2.weight(.bold))
                .foregroundStyle(theme.ink)
            Text(badge.detail)
                .font(.body)
                .foregroundStyle(theme.inkMuted)
            if badge.earned {
                Label("Earned", systemImage: "checkmark.seal.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.olive)
            } else {
                VStack(spacing: 6) {
                    ProgressTrack(progress: badge.progress)
                        .frame(width: 180)
                    Text("\(Int(badge.progress * 100))% of the way")
                        .font(.subheadline)
                        .foregroundStyle(theme.inkMuted)
                        .monospacedDigit()
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .marqueeCanvas()
    }
}
