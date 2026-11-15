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

struct BadgeCabinet: View {
    @Environment(\.marqueeTheme) private var theme
    let badges: [DiaryBadge]
    @State private var expanded = false

    private var earnedCount: Int { badges.filter(\.earned).count }

    private var visible: [DiaryBadge] {
        if expanded { return badges }
        let earned = badges.filter(\.earned)
        let next = badges.filter { !$0.earned }.prefix(2)
        let mix = earned + Array(next)
        return Array(mix.prefix(6))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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

            if expanded {
                ForEach(DiaryBadge.Kind.allCases, id: \.rawValue) { kind in
                    let group = badges.filter { $0.kind == kind }
                    if !group.isEmpty {
                        Text(kind.rawValue)
                            .font(.caption.weight(.bold))
                            .tracking(0.8)
                            .textCase(.uppercase)
                            .foregroundStyle(kind == .film ? theme.accent : theme.olive)
                            .padding(.top, 4)
                        VStack(spacing: 0) {
                            ForEach(group) { badge in
                                BadgeRow(badge: badge)
                                if badge.id != group.last?.id {
                                    Divider().overlay(theme.border)
                                }
                            }
                        }
                        .padding(.horizontal, 4)
                        .background(theme.surfaceElevated.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(visible) { badge in
                        BadgeRow(badge: badge)
                        if badge.id != visible.last?.id {
                            Divider().overlay(theme.border)
                        }
                    }
                }
                .padding(.horizontal, 4)
                .background(theme.surfaceElevated.opacity(0.72))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if badges.count > 6 || expanded {
                Button {
                    withAnimation(MarqueeMotion.standard) { expanded.toggle() }
                } label: {
                    Text(expanded ? "Show less" : "Show all \(badges.count)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(theme.olive)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(PressablePosterStyle())
            }
        }
    }
}

extension DiaryBadge.Kind: CaseIterable {}

private struct BadgeRow: View {
    @Environment(\.marqueeTheme) private var theme
    let badge: DiaryBadge

    private var ink: Color {
        badge.kind == .film ? theme.accent : theme.olive
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(badge.earned ? ink : ink.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: badge.symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(badge.earned ? MarqueeColor.saltGrey : ink)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(badge.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(theme.ink)
                Text(badge.earned ? badge.detail : remainingLine)
                    .font(.caption)
                    .foregroundStyle(theme.inkMuted)
            }

            Spacer(minLength: 8)

            if badge.earned {
                Image(systemName: "checkmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(ink)
            } else {
                CircularProgress(progress: badge.progress, tint: ink)
                    .frame(width: 22, height: 22)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge.title). \(badge.earned ? "Earned. \(badge.detail)" : remainingLine)")
    }

    private var remainingLine: String {
        if badge.id.contains("tv-") || badge.id.contains("film-24") || badge.id.contains("film-100h") {
            return "\(StatsFormat.minutes(badge.current)) / \(StatsFormat.minutes(badge.target))"
        }
        return "\(badge.current) / \(badge.target)"
    }
}

private struct CircularProgress: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle().stroke(tint.opacity(0.18), lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: max(0.04, progress))
                .stroke(tint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}
