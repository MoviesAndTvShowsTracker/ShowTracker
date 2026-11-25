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
    var note: String? = nil
    /// Every dated watch, newest first (newer servers).
    var plays: [FilmPlay]? = nil
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
    var plays: [FilmPlay]? = nil
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
    /// When it was watched (default: now) and an optional note.
    var watchedAt: String? = nil
    var note: String? = nil
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
    var watchedAt: String? = nil
    var note: String? = nil
}

struct EpisodeLogUpdateResponse: Decodable, Sendable {
    let success: Bool?
    let episode: WatchedEpisodeDoc?
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
    let timesCompleted: Int?
    let activeRewatchSessionId: String?

    init(
        tvId: String,
        status: String? = nil,
        tvTitle: String? = nil,
        tvPosterImage: String? = nil,
        tvPost: String? = nil,
        rating: Double? = nil,
        nextSeason: Int? = nil,
        nextEpisode: Int? = nil,
        nextEpisodeName: String? = nil,
        lastSeason: Int? = nil,
        lastEpisode: Int? = nil,
        watchedEpisodeCount: Int? = nil,
        totalEpisodes: Int? = nil,
        airedEpisodeCount: Int? = nil,
        timesCompleted: Int? = nil,
        activeRewatchSessionId: String? = nil
    ) {
        self.tvId = tvId
        self.status = status
        self.tvTitle = tvTitle
        self.tvPosterImage = tvPosterImage
        self.tvPost = tvPost
        self.rating = rating
        self.nextSeason = nextSeason
        self.nextEpisode = nextEpisode
        self.nextEpisodeName = nextEpisodeName
        self.lastSeason = lastSeason
        self.lastEpisode = lastEpisode
        self.watchedEpisodeCount = watchedEpisodeCount
        self.totalEpisodes = totalEpisodes
        self.airedEpisodeCount = airedEpisodeCount
        self.timesCompleted = timesCompleted
        self.activeRewatchSessionId = activeRewatchSessionId
    }

    var posterPath: String? { tvPosterImage ?? tvPost }

    var isRewatching: Bool { status == "rewatching" }

    var showProgress: ShowProgress { ShowProgress.from(track: self) }

    var progressFraction: Double { showProgress.fraction }
    var progressPercent: Int { showProgress.percent }
}

struct RewatchSessionDoc: Decodable, Identifiable, Sendable {
    var id: String { _id ?? fallbackId }
    let _id: String?
    let tvId: String?
    let sessionNumber: Int?
    let status: String?
    let watchedEpisodeCount: Int?
    let totalEpisodes: Int?
    let airedEpisodeCount: Int?
    let nextSeason: Int?
    let nextEpisode: Int?
    let nextEpisodeName: String?
    let episodes: [WatchedEpisodeDoc]?

    private var fallbackId: String { "session-\(sessionNumber ?? 0)" }
}

/// GET /api/diary/index — catalogue badge data: [movieId, plays] pairs, watchlist ids, the loved film.
struct DiaryIndexResponse: Decodable, Sendable {
    struct Loved: Decodable, Sendable { let id: String; let title: String }

    let watchCounts: [Int: Int]
    let watchlistIds: Set<Int>
    let loved: Loved?

    private enum CodingKeys: String, CodingKey { case films, filmWatchlist, loved }

    private struct Pair: Decodable {
        let id: String
        let plays: Int
        init(from decoder: Decoder) throws {
            var c = try decoder.unkeyedContainer()
            id = try c.decode(String.self)
            plays = try c.decode(Int.self)
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let films = try c.decodeIfPresent([Pair].self, forKey: .films) ?? []
        watchCounts = Dictionary(
            films.compactMap { p in Int(p.id).map { ($0, max(1, p.plays)) } },
            uniquingKeysWith: { a, _ in a }
        )
        watchlistIds = Set((try c.decodeIfPresent([String].self, forKey: .filmWatchlist) ?? []).compactMap(Int.init))
        loved = try c.decodeIfPresent(Loved.self, forKey: .loved)
    }
}

/// GET /api/me/tv/:id — everything the show page knows about the user, in one call.
struct TVUserState: Decodable, Sendable {
    var favorited: Bool?
    var watchlisted: Bool?
    var tracking: TrackingRecord?
    var episodes: [WatchedEpisodeDoc]?
    var rewatch: RewatchStateResponse?
}

/// GET /api/me/movie/:id — favorite, watchlist and watch summary for the film page.
struct MovieUserState: Decodable, Sendable {
    var favorited: Bool?
    var watchlisted: Bool?
    var watched: WatchedResponse?
}

struct RewatchStateResponse: Decodable, Sendable {
    let success: Bool?
    let tracking: TrackingRecord?
    let activeSession: RewatchSessionDoc?
    let timesCompleted: Int?
    let completedRewatches: Int?
    let playCounts: [String: Int]?
    /// "S-E" → ISO timestamps, oldest → newest.
    let playDates: [String: [String]]?
    let rewatchPlayTotal: Int?
}

struct RewatchMutationResponse: Decodable, Sendable {
    let success: Bool?
    let tracking: TrackingRecord?
    let session: RewatchSessionDoc?
    let episodes: [WatchedEpisodeDoc]?
    let completed: Bool?
    let resumed: Bool?
    let playCounts: [String: Int]?
    let playDates: [String: [String]]?
    let rewatchPlayTotal: Int?
    let removedRewatch: Bool?
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

