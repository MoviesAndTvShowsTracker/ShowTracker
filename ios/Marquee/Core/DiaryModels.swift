import Foundation

// MARK: - Diary / tracking API payloads

struct MovieIdBody: Encodable, Sendable{
    let movieId: String
    let movieTitle: String?
    let moviePosterImage: String?
    let movieRuntime: String?
}

struct TVIdBody: Encodable, Sendable{
    let tvId: String
    let tvTitle: String?
    let tvPosterImage: String?
}

struct RateMovieBody: Encodable, Sendable{
    let movieId: String
    let rating: Double
}

struct RateTVBody: Encodable, Sendable{
    let tvId: String
    let rating: Double
}

struct FavoritedResponse: Decodable, Sendable{
    let success: Bool?
    let favorited: Bool?
}

struct WatchedResponse: Decodable, Sendable{
    let success: Bool?
    let watched: Bool?
    let watchCount: Int?
    let watchedAt: String?
    let rating: Double?
    let isRewatch: Bool?
    let latestPlayId: String?
}

struct FilmWatchMutationResponse: Decodable, Sendable {
    let success: Bool?
    let watchedAt: String?
    let rating: Double?
    let watchCount: Int?
    let isRewatch: Bool?
    let playId: String?
    let watched: Bool?
    let mode: String?
    let deletedCount: Int?
}

struct WatchlistedResponse: Decodable, Sendable{
    let success: Bool?
    let watchlisted: Bool?
}

struct FavoriteListResponse: Decodable, Sendable{
    let success: Bool?
    let favorites: [FavoriteMovieDoc]?
}

struct FavoriteMovieDoc: Codable, Identifiable, Sendable{
    var id: String { movieId }
    let movieId: String
    let movieTitle: String?
    let moviePost: String?
    let moviePosterImage: String?
    let movieImage: String?

    var posterPath: String? { moviePost ?? moviePosterImage ?? movieImage }
}

struct WatchListResponse: Decodable, Sendable{
    let success: Bool?
    let watch: [WatchMovieDoc]?
    let watches: [WatchMovieDoc]?

    var items: [WatchMovieDoc] { watch ?? watches ?? [] }
}

struct WatchMovieDoc: Decodable, Identifiable, Sendable{
    var id: String { movieId }
    let movieId: String
    let movieTitle: String?
    let moviePost: String?
    let moviePosterImage: String?
    let rating: Double?
    let watchCount: Int?
    let isRewatch: Bool?
    let watchedAt: String?

    var posterPath: String? { moviePost ?? moviePosterImage }
}

struct MovieWatchlistResponse: Decodable, Sendable{
    let success: Bool?
    let watchlist: [FavoriteMovieDoc]?
}

struct TVFavoriteListResponse: Decodable, Sendable{
    let success: Bool?
    let favorites: [FavoriteTVDoc]?
}

struct FavoriteTVDoc: Codable, Identifiable, Sendable{
    var id: String { tvId }
    let tvId: String
    let tvTitle: String?
    let tvPost: String?
    let tvPosterImage: String?

    var posterPath: String? { tvPost ?? tvPosterImage }
}

struct TVWatchlistResponse: Decodable, Sendable{
    let success: Bool?
    let watchlist: [FavoriteTVDoc]?
}

struct TVWatchedListResponse: Decodable, Sendable{
    let success: Bool?
    let watch: [FavoriteTVDoc]?
    let watches: [FavoriteTVDoc]?

    var items: [FavoriteTVDoc] { watch ?? watches ?? [] }
}

struct MarkEpisodeBody: Encodable, Sendable{
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

struct BatchEpisodesBody: Encodable, Sendable{
    let tvId: String
    let episodes: [EpisodeRef]
    var tvTitle: String? = nil
    var tvPosterImage: String? = nil
    var tvBackdropImage: String? = nil
    var totalEpisodes: Int? = nil
    var airedEpisodeCount: Int? = nil
    var nextSeason: Int? = nil
    var nextEpisode: Int? = nil
    var nextEpisodeName: String? = nil
}

struct EpisodeRef: Encodable, Sendable{
    let seasonNumber: Int
    let episodeNumber: Int
    var runtimeMinutes: Int? = nil
    var episodeName: String? = nil
    var tmdbEpisodeId: String? = nil
}

struct EpisodeBatchResponse: Decodable, Sendable{
    let success: Bool?
    let tracking: TrackingRecord?
    let episodes: [WatchedEpisodeDoc]?
}

struct RateEpisodeBody: Encodable, Sendable{
    let tvId: String
    let seasonNumber: Int
    let episodeNumber: Int
    let rating: Double
}

struct WatchedEpisodesResponse: Decodable, Sendable{
    let success: Bool?
    let episodes: [WatchedEpisodeDoc]?
}

struct WatchedEpisodeDoc: Codable, Hashable, Sendable{
    let seasonNumber: Int?
    let episodeNumber: Int?
    let rating: Double?
}

struct TrackingStartBody: Encodable, Sendable{
    let tvId: String
    let tvTitle: String?
    let tvPosterImage: String?
}

struct TrackingStopBody: Encodable, Sendable{
    let tvId: String
    let status: String
}

struct TrackingShowResponse: Decodable, Sendable{
    let success: Bool?
    let tracking: TrackingRecord?
}

struct TrackingStartResponse: Decodable, Sendable {
    let success: Bool?
    let tracking: TrackingRecord?
}

struct TrackingRecord: Codable, Identifiable, Sendable{
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

struct ContinueResponse: Decodable, Sendable{
    let success: Bool?
    let tracks: [TrackingRecord]?
}

struct LibraryCounts: Decodable, Sendable{
    let watching: Int?
    let paused: Int?
    let completed: Int?
}

struct LibrarySummaryResponse: Decodable, Sendable{
    let success: Bool?
    let counts: LibraryCounts?
}

struct LibraryTabResponse: Decodable, Sendable{
    let success: Bool?
    let tracks: [TrackingRecord]?
}

