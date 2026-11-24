import Foundation

struct WeekRecapEnvelope: Codable, Sendable{
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

struct DashboardStatsEnvelope: Codable, Sendable{
    let success: Bool?
    let stats: DashboardStats?
}

struct DashboardStats: Codable, Sendable{
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
    let rhythm: StatsRhythm?
    let lobbyType: StatsLobbyType?
    let seasonArcs: [StatsSeasonArc]?
    let biggestNight: StatsBiggestNight?
    let hotTakes: [StatsHotTake]?
    let previousYear: StatsPeriod?
    let memberSince: String?
    var ranges: StatsRanges? = nil
    var tv: StatsTVBlock? = nil
    var weekday: [StatsWeekdayBucket]? = nil
}

struct StatsTVBlock: Codable, Sendable {
    let showCount: Int?
    let episodeCount: Int?
    let tvMins: Int?
    let avgEpisodeMins: Int?
    let topRated: [StatsRatedTitle]?
    let ratingDistribution: [StatsRatingBucket]?
}

/// A film or show from your own top-rated list (stars 0.5…5).
struct StatsRatedTitle: Codable, Identifiable, Sendable {
    var id: String { movieId ?? tvId ?? displayTitle }
    let movieId: String?
    let tvId: String?
    let title: String?
    let tvTitle: String?
    let poster: String?
    let tvPosterImage: String?
    let rating: Double?

    var displayTitle: String { title ?? tvTitle ?? "" }
    var posterPath: String? { poster ?? tvPosterImage }
}

struct StatsRatingBucket: Codable, Identifiable, Sendable {
    var id: Double { stars ?? 0 }
    let stars: Double?
    let count: Int?
}

struct StatsWeekdayBucket: Codable, Identifiable, Sendable {
    var id: String { label ?? "" }
    let label: String?
    let tvMins: Int?
    let filmMins: Int?
    let plays: Int?
    let days: Int?

    var totalMins: Int { (tvMins ?? 0) + (filmMins ?? 0) }
}

// MARK: - Range-scoped stats (week / month / year / all)

enum StatsRangeKey: String, CaseIterable, Identifiable, Sendable {
    case week, month, year, all
    var id: String { rawValue }

    var title: String {
        switch self {
        case .week: "Week"
        case .month: "Month"
        case .year: "Year"
        case .all: "All"
        }
    }

    var heroKicker: String {
        switch self {
        case .week: "This week"
        case .month: "This month"
        case .year: "This year"
        case .all: "All time"
        }
    }

    var previousPhrase: String {
        switch self {
        case .week: "this point last week"
        case .month: "this point last month"
        case .year: "this point last year"
        case .all: ""
        }
    }

    var quietLine: String {
        switch self {
        case .week: "Quiet week so far. The lobby's open."
        case .month: "Nothing on the bill this month yet."
        case .year: "A fresh year. First ticket's on you."
        case .all: "Nothing logged yet."
        }
    }
}

struct StatsRanges: Codable, Sendable {
    let week: StatsRange?
    let month: StatsRange?
    let year: StatsRange?
    let all: StatsRange?

    subscript(key: StatsRangeKey) -> StatsRange? {
        switch key {
        case .week: week
        case .month: month
        case .year: year
        case .all: all
        }
    }
}

struct StatsRange: Codable, Sendable {
    let key: String?
    let start: String?
    let end: String?
    let totals: StatsRangeTotals?
    let previous: StatsRangePrevious?
    let trend: StatsRangeTrend?
    let rhythm: StatsRhythm?
    let biggestNight: StatsBiggestNight?
    let topShows: [StatsTopShow]?
    let films: [StatsRangeFilm]?
    let hotTakes: [StatsHotTake]?
    let taste: StatsTaste?

    var isQuiet: Bool { (totals?.episodePlays ?? 0) + (totals?.filmPlays ?? 0) == 0 }
}

struct StatsRangeTotals: Codable, Sendable {
    let totalMins: Int?
    let tvMins: Int?
    let filmMins: Int?
    let episodeCount: Int?
    let episodePlays: Int?
    let rewatchPlays: Int?
    let filmCount: Int?
    let filmPlays: Int?
    let showCount: Int?
    let activeDays: Int?
}

struct StatsRangePrevious: Codable, Sendable {
    let start: String?
    let end: String?
    let totalMins: Int?
    let plays: Int?
}

struct StatsRangeTrend: Codable, Sendable {
    let unit: String?
    let buckets: [StatsRangeBucket]?
}

struct StatsRangeBucket: Codable, Identifiable, Sendable, Equatable {
    var id: String { key ?? label ?? "" }
    let key: String?
    let label: String?
    let tvMins: Int?
    let filmMins: Int?
    let plays: Int?
    let future: Bool?

    var totalMins: Int { (tvMins ?? 0) + (filmMins ?? 0) }
}

struct StatsTopShow: Codable, Identifiable, Sendable {
    var id: String { tvId?.stringValue ?? tvTitle ?? "" }
    let tvId: FlexibleID?
    let tvTitle: String?
    let tvPosterImage: String?
    let plays: Int?
    let mins: Int?
}

struct StatsRangeFilm: Codable, Identifiable, Sendable {
    var id: String { "\(movieId ?? "")-\(watchedAt ?? "")" }
    let movieId: String?
    let title: String?
    let poster: String?
    let watchedAt: String?
    let rating: Double?
}

struct StatsOverview: Codable, Sendable{
    let episodeCount: Int?
    let filmCount: Int?
    let tvShowCount: Int?
    let episodePlayCount: Int?
    let episodeRewatchPlays: Int?
    let filmPlayCount: Int?
    let totalMins: Int?
    let filmMins: Int?
    let tvMins: Int?
    let filmShare: Int?
    let tvShare: Int?
}

struct StatsRhythm: Codable, Sendable {
    let byHour: [StatsHourBucket]?
    let peakHour: Int?
    let peakMins: Int?
    let persona: String?
    let caption: String?
}

struct StatsHourBucket: Codable, Sendable {
    let mins: Int?
    let filmMins: Int?
    let tvMins: Int?
    let playCount: Int?

    init(mins: Int? = 0, filmMins: Int? = 0, tvMins: Int? = 0, playCount: Int? = 0) {
        self.mins = mins
        self.filmMins = filmMins
        self.tvMins = tvMins
        self.playCount = playCount
    }
}

struct StatsLobbyType: Codable, Sendable {
    let schedule: String?
    let scheduleLabel: String?
    let pass: String?
    let passLabel: String?
    let finish: String?
    let finishLabel: String?
    let media: String?
    let mediaLabel: String?
    let label: String?
    let blurb: String?
    let rewatchRate: Int?
}

struct StatsSeasonArc: Codable, Identifiable, Sendable {
    var id: String { tvId?.stringValue ?? tvTitle ?? UUID().uuidString }
    let tvId: FlexibleID?
    let tvTitle: String?
    let tvPosterImage: String?
    let passes: [StatsSeasonPass]?
    let passCount: Int?
    let totalMins: Int?
    let totalPlays: Int?
}

struct StatsSeasonPass: Codable, Identifiable, Sendable {
    var id: String { "\(kind ?? "")-\(label ?? "")-\(episodes ?? 0)" }
    let kind: String?
    let label: String?
    let episodes: Int?
    let mins: Int?
    let start: String?
    let end: String?
}

struct StatsBiggestNight: Codable, Sendable {
    let date: String?
    let count: Int?
    let minutes: Int?
    let items: [StatsNightItem]?
}

struct StatsNightItem: Codable, Identifiable, Sendable {
    var id: String { "\(kind ?? "")-\(mediaId ?? title ?? "")-\(watchedAt ?? "")" }
    let kind: String?
    let mediaId: String?
    let title: String?
    let subtitle: String?
    let stillOrPoster: String?
    let watchedAt: String?
    let mins: Int?

    enum CodingKeys: String, CodingKey {
        case kind, mediaId = "id", title, subtitle, stillOrPoster, watchedAt, mins
    }
}

struct StatsHotTake: Codable, Identifiable, Sendable {
    var id: String { "\(kind ?? "")-\(mediaId ?? title ?? UUID().uuidString)" }
    let kind: String?
    let mediaId: String?
    let title: String?
    let poster: String?
    let userRating: Double?
    let communityRating: Double?
    let delta: Double?

    enum CodingKeys: String, CodingKey {
        case kind, mediaId = "id", title, poster, userRating, communityRating, delta
    }
}

struct StatsLibrary: Codable, Sendable{
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

struct StatsTaste: Codable, Sendable{
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

struct StatsTasteBucket: Codable, Sendable{
    let genreByEpisodes: [TasteGenre]?
    let genreByCount: [TasteGenre]?
    let decades: [TasteDecade]?
}

struct TasteDecade: Codable, Identifiable, Sendable{
    var id: String { decade ?? UUID().uuidString }
    let decade: String?
    let count: Int?
    let minutes: Int?
}

struct TasteGenre: Codable, Identifiable, Sendable{
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let count: Int?
    let value: Double?
    let pct: Int?

    var amount: Int { count ?? Int((value ?? 0).rounded()) }
}

struct StatsPeriod: Codable, Sendable{
    let episodeCount: Int?
    let filmCount: Int?
    let totalMins: Int?
    let tvMins: Int?
    let filmMins: Int?
}

struct StatsActivity: Codable, Sendable{
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

struct StatsBusiestMonth: Codable, Sendable{
    let month: String?
    let count: Int?
    let minutes: Int?
}

struct StatsTrendBucket: Codable, Identifiable, Sendable{
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

struct StatsDayBucket: Codable, Identifiable, Sendable{
    var id: String { date ?? UUID().uuidString }
    let date: String?
    let episodes: Int?
    let films: Int?
    let minutes: Int?
    let tvMinutes: Int?
    let filmMinutes: Int?
}

struct StatsBusiestDay: Codable, Sendable{
    let day: String?
    let count: Int?
}

struct StatsFunFacts: Codable, Sendable{
    let biggestBinge: StatsBinge?
    let mostWatchedShow: StatsMostWatched?
    let avgMinsPerActiveDay: Int?
    let avgEpisodeMins: Int?
    let avgPerActiveDay: Double?
}

struct StatsBinge: Codable, Sendable{
    let date: String?
    let count: Int?
    let episodes: Int?
    let films: Int?
    let minutes: Int?
}

struct StatsMostWatched: Codable, Sendable{
    let tvId: FlexibleID?
    let tvTitle: String?
    let tvPosterImage: String?
    let episodeCount: Int?
    let minutes: Int?
}

struct StatsFilmsBlock: Codable, Sendable{
    let count: Int?
    let filmMins: Int?
    let longest: StatsFilmExtreme?
    let shortest: StatsFilmExtreme?
    let avgRuntime: Int?
    let thisWeek: Int?
    let thisYear: Int?
    var topRated: [StatsRatedTitle]? = nil
    var ratingDistribution: [StatsRatingBucket]? = nil
}

struct StatsFilmExtreme: Codable, Sendable{
    let movieId: String?
    let movieTitle: String?
    let minutes: Int?
}

struct StatsRatings: Codable, Sendable{
    let films: StatsRatingSummary?
    let shows: StatsRatingSummary?
}

struct StatsRatingSummary: Codable, Sendable{
    let count: Int?
    let average: Double?
}

struct StatsMilestone: Codable, Identifiable, Sendable{
    var id: String { key ?? label ?? UUID().uuidString }
    let key: String?
    let label: String?
}

struct ImportStatusResponse: Codable, Sendable{
    let success: Bool?
    let job: ImportJob?
}

struct ImportJob: Codable, Sendable{
    let status: String?
    let message: String?
    let report: String?
}
