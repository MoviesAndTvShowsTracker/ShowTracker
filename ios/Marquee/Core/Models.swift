import Foundation

struct AuthSession: Codable, Equatable {
    var token: String
    var userId: String
    var email: String
    var firstName: String
    var username: String?
}

struct LoginResponse: Decodable {
    let success: Bool?
    let token: String?
    let userId: FlexibleID?
    let email: String?
    let firstName: String?
    let username: String?
    let message: String?

    var userIdString: String? {
        userId?.stringValue
    }
}

enum FlexibleID: Decodable, Equatable, Hashable {
    case string(String)
    case int(Int)

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if let s = try? c.decode(String.self) {
            self = .string(s)
        } else if let i = try? c.decode(Int.self) {
            self = .int(i)
        } else {
            throw DecodingError.typeMismatch(FlexibleID.self, .init(codingPath: decoder.codingPath, debugDescription: "Expected string or int id"))
        }
    }

    var stringValue: String {
        switch self {
        case .string(let s): return s
        case .int(let i): return String(i)
        }
    }
}

struct UserEnvelope: Decodable {
    let success: Bool?
    let found: UserProfile?
}

struct UserProfile: Decodable, Equatable, Identifiable {
    var id: String { _id.stringValue }
    let _id: FlexibleID
    var email: String?
    var firstName: String?
    var lastName: String?
    var username: String?
    var phonenumber: String?
}

struct SuccessMessage: Decodable {
    let success: Bool?
    let message: String?
}

struct TMDBPaged<T: Decodable>: Decodable {
    let page: Int?
    let results: [T]
    let total_pages: Int?
    let total_results: Int?
}

struct MediaItem: Codable, Identifiable, Hashable {
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let release_date: String?
    let first_air_date: String?
    let vote_average: Double?
    let media_type: String?
    let genre_ids: [Int]?

    var displayTitle: String { title ?? name ?? "Untitled" }
    var year: String? {
        let date = release_date ?? first_air_date
        guard let date, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
}

struct Genre: Codable, Hashable, Identifiable {
    let id: Int
    let name: String
}

struct Credits: Codable {
    let cast: [CastMember]?
    let crew: [CrewMember]?
}

struct CastMember: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let character: String?
    let profile_path: String?
}

struct CrewMember: Codable, Identifiable, Hashable {
    var id: String { credit_id }
    let credit_id: String
    let name: String?
    let job: String?
}

struct MovieDetail: Decodable, Identifiable {
    let id: Int
    let title: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let release_date: String?
    let runtime: Int?
    let vote_average: Double?
    let genres: [Genre]?
    let credits: Credits?
    let similar: TMDBPaged<MediaItem>?

    var displayTitle: String { title ?? "Untitled" }
    var year: String? {
        guard let release_date, release_date.count >= 4 else { return nil }
        return String(release_date.prefix(4))
    }
}

struct Network: Decodable, Hashable {
    let id: Int?
    let name: String?
}

struct TVDetail: Decodable, Identifiable {
    let id: Int
    let name: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let first_air_date: String?
    let last_air_date: String?
    let vote_average: Double?
    let genres: [Genre]?
    let status: String?
    let episode_run_time: [Int]?
    let number_of_seasons: Int?
    let number_of_episodes: Int?
    let networks: [Network]?
    let seasons: [TVSeason]?
    let credits: Credits?
    let similar: TMDBPaged<MediaItem>?

    var displayTitle: String { name ?? "Untitled" }
    var typicalRuntime: Int? { episode_run_time?.first }
    var networkNames: String? {
        let names = (networks ?? []).compactMap(\.name)
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }
}

struct TVSeason: Codable, Identifiable, Hashable {
    var id: Int { season_number }
    let season_number: Int
    let name: String?
    let episode_count: Int?
    let poster_path: String?
}

struct SeasonDetail: Codable {
    let id: Int?
    let season_number: Int?
    let name: String?
    let episodes: [TVEpisode]?
}

struct TVEpisode: Codable, Identifiable, Hashable {
    let id: Int
    let name: String?
    let overview: String?
    let still_path: String?
    let episode_number: Int
    let season_number: Int?
    let runtime: Int?
    let air_date: String?
}

// MARK: - Diary / tracking API payloads

struct MovieIdBody: Encodable {
    let movieId: String
    let movieTitle: String?
    let moviePosterImage: String?
    let movieRuntime: String?
}

struct TVIdBody: Encodable {
    let tvId: String
    let tvTitle: String?
    let tvPosterImage: String?
}

struct RateMovieBody: Encodable {
    let movieId: String
    let rating: Double
}

struct RateTVBody: Encodable {
    let tvId: String
    let rating: Double
}

struct FavoritedResponse: Decodable {
    let success: Bool?
    let favorited: Bool?
}

struct WatchedResponse: Decodable {
    let success: Bool?
    let watched: Bool?
    let rating: Double?
}

struct WatchlistedResponse: Decodable {
    let success: Bool?
    let watchlisted: Bool?
}

struct FavoriteListResponse: Decodable {
    let success: Bool?
    let favorites: [FavoriteMovieDoc]?
}

struct FavoriteMovieDoc: Decodable, Identifiable {
    var id: String { movieId }
    let movieId: String
    let movieTitle: String?
    let moviePost: String?
    let moviePosterImage: String?
    let movieImage: String?

    var posterPath: String? { moviePost ?? moviePosterImage ?? movieImage }
}

struct WatchListResponse: Decodable {
    let success: Bool?
    let watch: [WatchMovieDoc]?
    let watches: [WatchMovieDoc]?

    var items: [WatchMovieDoc] { watch ?? watches ?? [] }
}

struct WatchMovieDoc: Decodable, Identifiable {
    var id: String { movieId }
    let movieId: String
    let movieTitle: String?
    let moviePost: String?
    let moviePosterImage: String?
    let rating: Double?

    var posterPath: String? { moviePost ?? moviePosterImage }
}

struct MovieWatchlistResponse: Decodable {
    let success: Bool?
    let watchlist: [FavoriteMovieDoc]?
}

struct TVFavoriteListResponse: Decodable {
    let success: Bool?
    let favorites: [FavoriteTVDoc]?
}

struct FavoriteTVDoc: Decodable, Identifiable {
    var id: String { tvId }
    let tvId: String
    let tvTitle: String?
    let tvPost: String?
    let tvPosterImage: String?

    var posterPath: String? { tvPost ?? tvPosterImage }
}

struct TVWatchlistResponse: Decodable {
    let success: Bool?
    let watchlist: [FavoriteTVDoc]?
}

struct TVWatchedListResponse: Decodable {
    let success: Bool?
    let watch: [FavoriteTVDoc]?
    let watches: [FavoriteTVDoc]?

    var items: [FavoriteTVDoc] { watch ?? watches ?? [] }
}

struct MarkEpisodeBody: Encodable {
    let tvId: String
    let seasonNumber: Int
    let episodeNumber: Int
    let runtimeMinutes: Int?
    let episodeName: String?
    let tvTitle: String?
    let tvPosterImage: String?
    var totalEpisodes: Int? = nil
    var airedEpisodeCount: Int? = nil
    var nextSeason: Int? = nil
    var nextEpisode: Int? = nil
    var nextEpisodeName: String? = nil
}

struct BatchEpisodesBody: Encodable {
    let tvId: String
    let episodes: [EpisodeRef]
}

struct EpisodeRef: Encodable {
    let seasonNumber: Int
    let episodeNumber: Int
    let runtimeMinutes: Int?
    let episodeName: String?
}

struct RateEpisodeBody: Encodable {
    let tvId: String
    let seasonNumber: Int
    let episodeNumber: Int
    let rating: Double
}

struct WatchedEpisodesResponse: Decodable {
    let success: Bool?
    let episodes: [WatchedEpisodeDoc]?
}

struct WatchedEpisodeDoc: Codable, Hashable {
    let seasonNumber: Int?
    let episodeNumber: Int?
    let rating: Double?
}

struct TrackingStartBody: Encodable {
    let tvId: String
    let tvTitle: String?
    let tvPosterImage: String?
}

struct TrackingStopBody: Encodable {
    let tvId: String
    let status: String
}

struct TrackingShowResponse: Decodable {
    let success: Bool?
    let tracking: TrackingRecord?
}

struct TrackingRecord: Codable, Identifiable {
    var id: String { tvId }
    let tvId: String
    let status: String?
    let tvTitle: String?
    let tvPosterImage: String?
    let tvPost: String?
    let rating: Double?
    let nextSeason: Int?
    let nextEpisode: Int?
    let nextEpisodeName: String?
    let lastSeason: Int?
    let lastEpisode: Int?
    let watchedEpisodeCount: Int?
    let totalEpisodes: Int?
    let airedEpisodeCount: Int?

    var posterPath: String? { tvPosterImage ?? tvPost }

    var showProgress: ShowProgress { ShowProgress.from(track: self) }

    var progressFraction: Double { showProgress.fraction }
    var progressPercent: Int { showProgress.percent }
}

struct ContinueResponse: Decodable {
    let success: Bool?
    let tracks: [TrackingRecord]?
}

struct LibraryCounts: Decodable {
    let watching: Int?
    let paused: Int?
    let completed: Int?
}

struct LibrarySummaryResponse: Decodable {
    let success: Bool?
    let counts: LibraryCounts?
}

struct LibraryTabResponse: Decodable {
    let success: Bool?
    let tracks: [TrackingRecord]?
}

struct WeekRecapEnvelope: Decodable {
    let success: Bool?
    let recap: WeekRecap?
}

struct RecapInsight: Decodable {
    let kind: String?
    let text: String?
}

struct WeekRecap: Decodable {
    let episodesThisWeek: Int?
    let filmsThisWeek: Int?
    let tvMinsThisWeek: Int?
    let filmMinsThisWeek: Int?
    let totalMinsThisWeek: Int?
    let streak: Int?
    let insight: RecapInsight?
}

struct DashboardStatsEnvelope: Decodable {
    let success: Bool?
    let stats: DashboardStats?
}

struct DashboardStats: Decodable {
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

struct StatsOverview: Decodable {
    let episodeCount: Int?
    let filmCount: Int?
    let tvShowCount: Int?
    let totalMins: Int?
    let filmMins: Int?
    let tvMins: Int?
    let filmShare: Int?
    let tvShare: Int?
}

struct StatsLibrary: Decodable {
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

struct StatsTaste: Decodable {
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

struct StatsTasteBucket: Decodable {
    let genreByEpisodes: [TasteGenre]?
    let genreByCount: [TasteGenre]?
    let decades: [TasteDecade]?
}

struct TasteDecade: Decodable, Identifiable {
    var id: String { decade ?? UUID().uuidString }
    let decade: String?
    let count: Int?
    let minutes: Int?
}

struct TasteGenre: Decodable, Identifiable {
    var id: String { name ?? UUID().uuidString }
    let name: String?
    let count: Int?
    let value: Double?
    let pct: Int?

    var amount: Int { count ?? Int((value ?? 0).rounded()) }
}

struct StatsPeriod: Decodable {
    let episodeCount: Int?
    let filmCount: Int?
    let totalMins: Int?
    let tvMins: Int?
    let filmMins: Int?
}

struct StatsActivity: Decodable {
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

struct StatsBusiestMonth: Decodable {
    let month: String?
    let count: Int?
    let minutes: Int?
}

struct StatsTrendBucket: Decodable, Identifiable {
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

struct StatsDayBucket: Decodable, Identifiable {
    var id: String { date ?? UUID().uuidString }
    let date: String?
    let episodes: Int?
    let films: Int?
    let minutes: Int?
    let tvMinutes: Int?
    let filmMinutes: Int?
}

struct StatsBusiestDay: Decodable {
    let day: String?
    let count: Int?
}

struct StatsFunFacts: Decodable {
    let biggestBinge: StatsBinge?
    let mostWatchedShow: StatsMostWatched?
    let avgMinsPerActiveDay: Int?
    let avgEpisodeMins: Int?
    let avgPerActiveDay: Double?
}

struct StatsBinge: Decodable {
    let date: String?
    let count: Int?
    let episodes: Int?
    let films: Int?
    let minutes: Int?
}

struct StatsMostWatched: Decodable {
    let tvId: FlexibleID?
    let tvTitle: String?
    let tvPosterImage: String?
    let episodeCount: Int?
    let minutes: Int?
}

struct StatsFilmsBlock: Decodable {
    let count: Int?
    let filmMins: Int?
    let longest: StatsFilmExtreme?
    let shortest: StatsFilmExtreme?
    let avgRuntime: Int?
    let thisWeek: Int?
    let thisYear: Int?
}

struct StatsFilmExtreme: Decodable {
    let movieId: String?
    let movieTitle: String?
    let minutes: Int?
}

struct StatsRatings: Decodable {
    let films: StatsRatingSummary?
    let shows: StatsRatingSummary?
}

struct StatsRatingSummary: Decodable {
    let count: Int?
    let average: Double?
}

struct StatsMilestone: Decodable, Identifiable {
    var id: String { key ?? label ?? UUID().uuidString }
    let key: String?
    let label: String?
}

struct ImportStatusResponse: Decodable {
    let success: Bool?
    let job: ImportJob?
}

struct ImportJob: Decodable {
    let status: String?
    let message: String?
    let report: String?
}
