import Foundation

enum DiaryService {
    // MARK: Movies

    static func movieFavorited(id: String) async throws -> Bool {
        let res: FavoritedResponse = try await APIClient.shared.post(
            "/api/favorite/favorited",
            body: ["movieId": id]
        )
        return res.favorited ?? false
    }

    static func addMovieFavorite(_ body: MovieIdBody) async throws {
        let _: SuccessMessage = try await APIClient.shared.post("/api/favorite/addToFavorite", body: body)
    }

    static func removeMovieFavorite(id: String) async throws {
        let _: SuccessMessage = try await APIClient.shared.post("/api/favorite/removeFromFavorite", body: ["movieId": id])
    }

    static func movieWatched(id: String) async throws -> WatchedResponse {
        try await APIClient.shared.post("/api/watch/watched", body: ["movieId": id])
    }

    @discardableResult
    static func addMovieWatched(_ body: MovieIdBody, rating: Double? = nil) async throws -> FilmWatchMutationResponse {
        struct Body: Encodable {
            let movieId: String
            let movieTitle: String?
            let moviePosterImage: String?
            let movieRuntime: String?
            let rating: Double?
        }
        return try await APIClient.shared.post(
            "/api/watch/addToWatch",
            body: Body(
                movieId: body.movieId,
                movieTitle: body.movieTitle,
                moviePosterImage: body.moviePosterImage,
                movieRuntime: body.movieRuntime,
                rating: rating
            )
        )
    }

    static func rateMovie(id: String, rating: Double) async throws {
        let _: SuccessMessage = try await APIClient.shared.post(
            "/api/watch/rate",
            body: RateMovieBody(movieId: id, rating: rating)
        )
    }

    /// `mode`: `"latest"` removes only the newest play; `"all"` clears every play.
    @discardableResult
    static func removeMovieWatched(id: String, mode: String = "latest") async throws -> FilmWatchMutationResponse {
        try await APIClient.shared.post(
            "/api/watch/removeFromWatched",
            body: ["movieId": id, "mode": mode]
        )
    }

    static func movieWatchlisted(id: String) async throws -> Bool {
        let res: WatchlistedResponse = try await APIClient.shared.post(
            "/api/watchlist/watchlisted",
            body: ["movieId": id]
        )
        return res.watchlisted ?? false
    }

    static func addMovieWatchlist(_ body: MovieIdBody) async throws {
        let _: SuccessMessage = try await APIClient.shared.post("/api/watchlist/addToWatchlist", body: body)
    }

    static func removeMovieWatchlist(id: String) async throws {
        let _: SuccessMessage = try await APIClient.shared.post("/api/watchlist/removeFromWatchlist", body: ["movieId": id])
    }

    static func favoriteMovies() async throws -> [FavoriteMovieDoc] {
        let res: FavoriteListResponse = try await APIClient.shared.post("/api/favorite/getFavoriteMovie", body: [String: String]())
        return res.favorites ?? []
    }

    static func watchedMovies() async throws -> [WatchMovieDoc] {
        let res: WatchListResponse = try await APIClient.shared.post("/api/watch/getWatchMovie", body: [String: String]())
        return res.items
    }

    static func movieWatchlist() async throws -> [FavoriteMovieDoc] {
        let res: MovieWatchlistResponse = try await APIClient.shared.post("/api/watchlist/getMovieWatchlist", body: [String: String]())
        return res.watchlist ?? []
    }

    // MARK: TV lists

    static func tvFavorited(id: String) async throws -> Bool {
        let res: FavoritedResponse = try await APIClient.shared.post(
            "/api/tv/favorite/favorited",
            body: ["tvId": id]
        )
        return res.favorited ?? false
    }

    static func addTVFavorite(_ body: TVIdBody) async throws {
        let _: SuccessMessage = try await APIClient.shared.post("/api/tv/favorite/addToFavorite", body: body)
    }

    static func removeTVFavorite(id: String) async throws {
        let _: SuccessMessage = try await APIClient.shared.post("/api/tv/favorite/removeFromFavorite", body: ["tvId": id])
    }

    static func tvWatchlisted(id: String) async throws -> Bool {
        let res: WatchlistedResponse = try await APIClient.shared.post(
            "/api/tv/watchlist/watchlisted",
            body: ["tvId": id]
        )
        return res.watchlisted ?? false
    }

    static func addTVWatchlist(_ body: TVIdBody) async throws {
        let _: SuccessMessage = try await APIClient.shared.post("/api/tv/watchlist/addToWatchlist", body: body)
    }

    static func removeTVWatchlist(id: String) async throws {
        let _: SuccessMessage = try await APIClient.shared.post("/api/tv/watchlist/removeFromWatchlist", body: ["tvId": id])
    }

    static func favoriteTV() async throws -> [FavoriteTVDoc] {
        // Backend reuses movie-style path name for TV favorites.
        let res: TVFavoriteListResponse = try await APIClient.shared.post("/api/tv/favorite/getFavoriteMovie", body: [String: String]())
        return res.favorites ?? []
    }

    static func tvWatchlist() async throws -> [FavoriteTVDoc] {
        let res: TVWatchlistResponse = try await APIClient.shared.post("/api/tv/watchlist/getTvWatchlist", body: [String: String]())
        return res.watchlist ?? []
    }

    static func watchedTV() async throws -> [FavoriteTVDoc] {
        let res: TVWatchedListResponse = try await APIClient.shared.post("/api/tv/watch/getWatchTv", body: [String: String]())
        return res.items
    }

    // MARK: Episodes / tracking

    static func watchedEpisodes(tvId: String) async throws -> [WatchedEpisodeDoc] {
        let res: WatchedEpisodesResponse = try await APIClient.shared.get("/api/tv/episodes/\(tvId)")
        return res.episodes ?? []
    }

    /// Returns the show's updated tracking, so callers don't need a second request.
    @discardableResult
    static func markEpisode(_ body: MarkEpisodeBody) async throws -> TrackingRecord? {
        let res: TrackingShowResponse = try await APIClient.shared.post("/api/tv/episodes/mark", body: body)
        return res.tracking
    }

    static func unmarkEpisode(_ body: MarkEpisodeBody) async throws {
        let _: SuccessMessage = try await APIClient.shared.post("/api/tv/episodes/unmark", body: body)
    }

    static func markBatch(_ body: BatchEpisodesBody) async throws -> EpisodeBatchResponse {
        try await APIClient.shared.post("/api/tv/episodes/mark-batch", body: body)
    }

    static func unmarkBatch(_ body: BatchEpisodesBody) async throws -> EpisodeBatchResponse {
        try await APIClient.shared.post("/api/tv/episodes/unmark-batch", body: body)
    }

    static func rateEpisode(_ body: RateEpisodeBody) async throws {
        let _: SuccessMessage = try await APIClient.shared.post("/api/tv/episodes/rate-episode", body: body)
    }

    @discardableResult
    static func startTracking(_ body: TrackingStartBody) async throws -> TrackingRecord? {
        let res: TrackingStartResponse = try await APIClient.shared.post("/api/tv/tracking/start", body: body)
        return res.tracking
    }

    static func stopTracking(tvId: String, status: String = "paused") async throws {
        let _: SuccessMessage = try await APIClient.shared.post(
            "/api/tv/tracking/stop",
            body: TrackingStopBody(tvId: tvId, status: status)
        )
    }

    static func resumeTracking(tvId: String) async throws {
        let _: SuccessMessage = try await APIClient.shared.post("/api/tv/tracking/resume", body: ["tvId": tvId])
    }

    static func tracking(for tvId: String) async throws -> TrackingRecord? {
        let res: TrackingShowResponse = try await APIClient.shared.get("/api/tv/tracking/show/\(tvId)")
        return res.tracking
    }

    static func activity(limit: Int) async throws -> [DiaryActivityItem] {
        let res: DiaryActivityResponse = try await APIClient.shared.get(
            "/api/diary/activity",
            query: [URLQueryItem(name: "limit", value: String(limit))]
        )
        return res.items ?? []
    }

    static func continueWatching() async throws -> [TrackingRecord] {
        let res: ContinueResponse = try await APIClient.shared.get("/api/tv/tracking/continue")
        return res.tracks ?? []
    }

    static func librarySummary() async throws -> LibrarySummaryResponse {
        try await APIClient.shared.get("/api/tv/tracking/library/summary")
    }

    static func library(tab: String) async throws -> [TrackingRecord] {
        let res: LibraryTabResponse = try await APIClient.shared.get("/api/tv/tracking/library/\(tab)")
        return res.tracks ?? []
    }

    static func rateShow(tvId: String, rating: Double) async throws {
        let _: SuccessMessage = try await APIClient.shared.post(
            "/api/tv/tracking/rate",
            body: RateTVBody(tvId: tvId, rating: rating)
        )
    }

    // MARK: Rewatch sessions

    static func rewatchState(tvId: String) async throws -> RewatchStateResponse {
        try await APIClient.shared.get("/api/tv/rewatch/\(tvId)")
    }

    @discardableResult
    static func startRewatch(_ body: TrackingStartBody, totalEpisodes: Int? = nil, airedEpisodeCount: Int? = nil) async throws -> RewatchMutationResponse {
        struct Body: Encodable {
            let tvId: String
            let tvTitle: String?
            let tvPosterImage: String?
            let totalEpisodes: Int?
            let airedEpisodeCount: Int?
            let nextSeason: Int?
            let nextEpisode: Int?
        }
        return try await APIClient.shared.post(
            "/api/tv/rewatch/start",
            body: Body(
                tvId: body.tvId,
                tvTitle: body.tvTitle,
                tvPosterImage: body.tvPosterImage,
                totalEpisodes: totalEpisodes,
                airedEpisodeCount: airedEpisodeCount,
                nextSeason: 1,
                nextEpisode: 1
            )
        )
    }

    @discardableResult
    static func cancelRewatch(tvId: String) async throws -> RewatchMutationResponse {
        try await APIClient.shared.post("/api/tv/rewatch/cancel", body: ["tvId": tvId])
    }

    @discardableResult
    static func markRewatchEpisode(_ body: MarkEpisodeBody) async throws -> RewatchMutationResponse {
        try await APIClient.shared.post("/api/tv/rewatch/mark", body: body)
    }

    @discardableResult
    static func unmarkRewatchEpisode(_ body: MarkEpisodeBody) async throws -> RewatchMutationResponse {
        try await APIClient.shared.post("/api/tv/rewatch/unmark", body: body)
    }

    @discardableResult
    static func markRewatchBatch(_ body: BatchEpisodesBody) async throws -> RewatchMutationResponse {
        try await APIClient.shared.post("/api/tv/rewatch/mark-batch", body: body)
    }

    @discardableResult
    static func unmarkRewatchBatch(_ body: BatchEpisodesBody) async throws -> RewatchMutationResponse {
        try await APIClient.shared.post("/api/tv/rewatch/unmark-batch", body: body)
    }

    /// Casual rewatch play — does not enter structured rewatching.
    static func logRewatchEpisode(_ body: MarkEpisodeBody) async throws -> RewatchMutationResponse {
        try await APIClient.shared.post("/api/tv/rewatch/log", body: body)
    }

    static func logRewatchBatch(_ body: BatchEpisodesBody) async throws -> RewatchMutationResponse {
        try await APIClient.shared.post("/api/tv/rewatch/log-batch", body: body)
    }

    /// Undo latest rewatch play, then canonical first-watch.
    static func undoEpisodePlay(_ body: MarkEpisodeBody) async throws -> RewatchMutationResponse {
        try await APIClient.shared.post("/api/tv/rewatch/undo-play", body: body)
    }

    static func undoEpisodePlayBatch(_ body: BatchEpisodesBody) async throws -> RewatchMutationResponse {
        try await APIClient.shared.post("/api/tv/rewatch/undo-play-batch", body: body)
    }

    // MARK: Stats / import

    static func weekRecap() async throws -> WeekRecap {
        let env: WeekRecapEnvelope = try await APIClient.shared.get("/api/stats/week-recap")
        return env.recap ?? WeekRecap(
            episodesThisWeek: 0,
            filmsThisWeek: 0,
            tvMinsThisWeek: 0,
            filmMinsThisWeek: 0,
            totalMinsThisWeek: 0,
            streak: 0,
            insight: nil
        )
    }

    private static let dashboardCacheKey = "stats.dashboard.v1"

    /// Last stats seen on this device — shown instantly while a fresh copy loads.
    static func cachedDashboardStats() -> DashboardStats? {
        ResponseCache.load(DashboardStats.self, key: dashboardCacheKey)
    }

    static func dashboardStats(refresh: Bool = false) async throws -> DashboardStats {
        var query: [URLQueryItem] = []
        if refresh { query.append(URLQueryItem(name: "refresh", value: "1")) }
        var env: DashboardStatsEnvelope = try await APIClient.shared.get("/api/stats/dashboard", query: query)
        // Stale answer: the server is rebuilding in the background; ask once more shortly.
        // Callers already show the device's copy, so this wait isn't visible.
        if env.stale == true {
            try? await Task.sleep(for: .milliseconds(1500))
            if let fresh: DashboardStatsEnvelope = try? await APIClient.shared.get("/api/stats/dashboard") {
                env = fresh
            }
        }
        if let stats = env.stats { ResponseCache.store(stats, key: dashboardCacheKey) }
        return env.stats ?? DashboardStats(
            insight: nil, overview: nil, library: nil, taste: nil, year: nil,
            week: nil, activity: nil, funFacts: nil, films: nil, ratings: nil, milestones: nil,
            rhythm: nil, lobbyType: nil, seasonArcs: nil, biggestNight: nil, hotTakes: nil,
            previousYear: nil, memberSince: nil
        )
    }

    static func importStatus() async throws -> ImportStatusResponse {
        try await APIClient.shared.get("/api/import/tvtime/status")
    }

    static func uploadTVTime(fileURL: URL) async throws -> ImportStatusResponse {
        try await APIClient.shared.upload("/api/import/tvtime", fileURL: fileURL)
    }
}
