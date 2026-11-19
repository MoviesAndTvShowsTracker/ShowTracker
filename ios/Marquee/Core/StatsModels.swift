import Foundation

struct WeekRecapEnvelope: Decodable, Sendable{
    let success: Bool?
    let recap: WeekRecap?
}

struct RecapInsight: Codable, Sendable{
    let kind: String?
    let text: String?
}

struct WeekRecap: Codable, Sendable{
    let episodesThisWeek: Int?
    let filmsThisWeek: Int?
    let tvMinsThisWeek: Int?
    let filmMinsThisWeek: Int?
    let totalMinsThisWeek: Int?
    let streak: Int?
    let insight: RecapInsight?
}

struct DashboardStatsEnvelope: Decodable, Sendable{
    let success: Bool?
    let stats: DashboardStats?
}

struct DashboardStats: Decodable, Sendable{
    let insight: RecapInsight?
    let overview: StatsOverview?
    let library: StatsLibrary?
    let taste: StatsTaste?
    let year: StatsPeriod?
    let week: StatsPeriod?
    let activity: StatsActivity?
    let funFacts: StatsFunFacts?
    let films: StatsFilmsBlock?
    let ratings: StatsRatings?
    let milestones: [StatsMilestone]?
}

struct StatsOverview: Decodable, Sendable{
    let episodeCount: Int?
    let filmCount: Int?
    let tvShowCount: Int?
    let totalMins: Int?
    let filmMins: Int?
    let tvMins: Int?
    let filmShare: Int?
    let tvShare: Int?
}

struct StatsLibrary: Decodable, Sendable{
    let watching: Int?
    let paused: Int?
    let stopped: Int?
    let finished: Int?
    let caughtUp: Int?
    let backlog: Int?
    let totalTracked: Int?
    let completionRate: Int?

    var pausedCount: Int { paused ?? stopped ?? 0 }
}

struct StatsTaste: Decodable, Sendable{
    let topGenres: [TasteGenre]?
    let tv: StatsTasteBucket?
    let films: StatsTasteBucket?

    var genres: [TasteGenre] {
        if let topGenres, !topGenres.isEmpty { return topGenres }
        let tvGenres = tv?.genreByEpisodes ?? []
        let filmGenres = films?.genreByCount ?? []
        if !tvGenres.isEmpty { return tvGenres }
        return filmGenres
    }
}

struct StatsTasteBucket: Decodable, Sendable{
    let genreByEpisodes: [TasteGenre]?
    let genreByCount: [TasteGenre]?
    let decades: [TasteDecade]?
}

struct TasteDecade: Decodable, Identifiable, Sendable{
    var id: String { decade ?? UUID().uuidString }
    let decade: String?
    let count: Int?
    let minutes: Int?
}

struct TasteGenre: Decodable, Identifiable, Sendable{
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let count: Int?
    let value: Double?
    let pct: Int?

    var amount: Int { count ?? Int((value ?? 0).rounded()) }
}

struct StatsPeriod: Decodable, Sendable{
    let episodeCount: Int?
    let filmCount: Int?
    let totalMins: Int?
    let tvMins: Int?
    let filmMins: Int?
}

struct StatsActivity: Decodable, Sendable{
    let streak: Int?
    let longestStreak: Int?
    let busiestDay: StatsBusiestDay?
    let busiestMonth: StatsBusiestMonth?
    let lastWatchedAt: String?
    let firstLoggedOn: String?
    let activeDays: Int?
    let episodesThisWeek: Int?
    let filmsThisWeek: Int?
    let tvMinsThisWeek: Int?
    let filmMinsThisWeek: Int?
    let totalMinsThisWeek: Int?
    let weeklyTrend: [StatsTrendBucket]?
    let monthlyTrend: [StatsTrendBucket]?
    let dailyActivity: [StatsDayBucket]?
}

struct StatsBusiestMonth: Decodable, Sendable{
    let month: String?
    let count: Int?
    let minutes: Int?
}

struct StatsTrendBucket: Decodable, Identifiable, Sendable{
    var id: String { weekStart ?? month ?? UUID().uuidString }
    let weekStart: String?
    let weekEnd: String?
    let month: String?
    let episodes: Int?
    let films: Int?
    let minutes: Int?
    let tvMinutes: Int?
    let filmMinutes: Int?
}

struct StatsDayBucket: Decodable, Identifiable, Sendable{
    var id: String { date ?? UUID().uuidString }
    let date: String?
    let episodes: Int?
    let films: Int?
    let minutes: Int?
    let tvMinutes: Int?
    let filmMinutes: Int?
}

struct StatsBusiestDay: Decodable, Sendable{
    let day: String?
    let count: Int?
}

struct StatsFunFacts: Decodable, Sendable{
    let biggestBinge: StatsBinge?
    let mostWatchedShow: StatsMostWatched?
    let avgMinsPerActiveDay: Int?
    let avgEpisodeMins: Int?
    let avgPerActiveDay: Double?
}

struct StatsBinge: Decodable, Sendable{
    let date: String?
    let count: Int?
    let episodes: Int?
    let films: Int?
    let minutes: Int?
}

struct StatsMostWatched: Decodable, Sendable{
    let tvId: FlexibleID?
    let tvTitle: String?
    let tvPosterImage: String?
    let episodeCount: Int?
    let minutes: Int?
}

struct StatsFilmsBlock: Decodable, Sendable{
    let count: Int?
    let filmMins: Int?
    let longest: StatsFilmExtreme?
    let shortest: StatsFilmExtreme?
    let avgRuntime: Int?
    let thisWeek: Int?
    let thisYear: Int?
}

struct StatsFilmExtreme: Decodable, Sendable{
    let movieId: String?
    let movieTitle: String?
    let minutes: Int?
}

struct StatsRatings: Decodable, Sendable{
    let films: StatsRatingSummary?
    let shows: StatsRatingSummary?
}

struct StatsRatingSummary: Decodable, Sendable{
    let count: Int?
    let average: Double?
}

struct StatsMilestone: Decodable, Identifiable, Sendable{
    var id: String { key ?? label ?? UUID().uuidString }
    let key: String?
    let label: String?
}

struct ImportStatusResponse: Decodable, Sendable{
    let success: Bool?
    let job: ImportJob?
}

struct ImportJob: Decodable, Sendable{
    let status: String?
    let message: String?
    let report: String?
}
