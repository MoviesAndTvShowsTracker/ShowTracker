import Foundation

enum UITestingFixtures {
    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTesting")
            || ProcessInfo.processInfo.environment["MARQUEE_UI_TESTING"] == "1"
    }

    static let continueItems: [TrackingRecord] = [
        TrackingRecord(
            tvId: "1396",
            status: "watching",
            tvTitle: "Breaking Bad",
            tvPosterImage: "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg",
            tvPost: nil,
            rating: nil,
            nextSeason: 2,
            nextEpisode: 4,
            nextEpisodeName: "Down",
            lastSeason: 2,
            lastEpisode: 3,
            watchedEpisodeCount: 16,
            totalEpisodes: 62,
            airedEpisodeCount: 62
        ),
        TrackingRecord(
            tvId: "66732",
            status: "watching",
            tvTitle: "Stranger Things",
            tvPosterImage: "/49WJfeN0moxb9IPfGn8AIqMGskD.jpg",
            tvPost: nil,
            rating: nil,
            nextSeason: 4,
            nextEpisode: 2,
            nextEpisodeName: "Vecna's Curse",
            lastSeason: 4,
            lastEpisode: 1,
            watchedEpisodeCount: 26,
            totalEpisodes: 34,
            airedEpisodeCount: 34
        ),
        TrackingRecord(
            tvId: "94997",
            status: "watching",
            tvTitle: "House of the Dragon",
            tvPosterImage: "/z2yahl2uefxDCl0nogcRBstwruJ.jpg",
            tvPost: nil,
            rating: nil,
            nextSeason: 1,
            nextEpisode: 6,
            nextEpisodeName: "The Princess and the Queen",
            lastSeason: 1,
            lastEpisode: 5,
            watchedEpisodeCount: 5,
            totalEpisodes: 10,
            airedEpisodeCount: 10
        ),
    ]

    static var diaryItems: [DiaryActivityItem] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        func day(_ offset: Int) -> String {
            let d = cal.date(byAdding: .day, value: offset, to: today) ?? today
            let c = cal.dateComponents([.year, .month, .day], from: d)
            return String(format: "%04d-%02d-%02dT20:00:00.000Z", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        }
        return [
            DiaryActivityItem(id: "1", kind: "episode", mediaId: "1396", title: "Breaking Bad", posterPath: "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg", subtitle: "S2E3 · Bit by a Dead Bee", watchedAt: day(0), rating: 8),
            DiaryActivityItem(id: "2", kind: "film", mediaId: "27205", title: "Inception", posterPath: "/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg", subtitle: nil, watchedAt: day(0), rating: 9),
            DiaryActivityItem(id: "3", kind: "episode", mediaId: "66732", title: "Stranger Things", posterPath: "/49WJfeN0moxb9IPfGn8AIqMGskD.jpg", subtitle: "S4E1 · The Hellfire Club", watchedAt: day(-1), rating: nil),
            DiaryActivityItem(id: "4", kind: "episode", mediaId: "66732", title: "Stranger Things", posterPath: "/49WJfeN0moxb9IPfGn8AIqMGskD.jpg", subtitle: "S4E2 · Vecna's Curse", watchedAt: day(-1), rating: 7),
            DiaryActivityItem(id: "5", kind: "film", mediaId: "157336", title: "Interstellar", posterPath: "/gEU2QniE6E77NI6lCU6MxlNBvIx.jpg", subtitle: nil, watchedAt: day(-3), rating: 10),
            DiaryActivityItem(id: "6", kind: "episode", mediaId: "94997", title: "House of the Dragon", posterPath: "/z2yahl2uefxDCl0nogcRBstwruJ.jpg", subtitle: "S1E5 · We Light the Way", watchedAt: day(-5), rating: nil),
            DiaryActivityItem(id: "7", kind: "episode", mediaId: "1396", title: "Breaking Bad", posterPath: "/ggFHVNu6YYI5L9pCfOacjizRGt.jpg", subtitle: "S2E2 · Grilled", watchedAt: day(-8), rating: 8),
            DiaryActivityItem(id: "8", kind: "film", mediaId: "27205", title: "Inception", posterPath: "/9gk7adHYeDvHkCSEqAvQNLV5Uge.jpg", subtitle: nil, watchedAt: day(-12), rating: 9),
        ]
    }
}
