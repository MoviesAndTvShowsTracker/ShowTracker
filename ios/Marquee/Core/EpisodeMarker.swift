import Foundation

/// Marks the next episode of a tracked show. Shared by Home and TVContinueView.
///
/// The server owns "what comes next": it reads TMDB's catalog after every mark and returns the
/// updated tracking. This client never guesses across seasons; it only names a later episode
/// in the same season when TMDB's season list confirms it.
enum EpisodeMarker {
    struct Result: Sendable {
        let body: MarkEpisodeBody
        let updated: TrackingRecord?
    }

    enum MarkError: LocalizedError {
        case noNextEpisode
        var errorDescription: String? { "No next episode to log." }
    }

    /// The next listed episode in the same season, or nil when unknown or the season is over.
    static func laterInSeason(after current: EpisodePointer, seasonEpisodes: [TVEpisode]?) -> EpisodePointer? {
        guard let later = seasonEpisodes?
            .filter({ $0.episode_number > current.episode })
            .min(by: { $0.episode_number < $1.episode_number })
        else { return nil }
        return EpisodePointer(season: current.season, episode: later.episode_number, name: later.name)
    }

    static func markNext(
        track: TrackingRecord,
        catalogTotal: Int?,
        runtime: Int?,
        episodeName: String?,
        watchedAt: Date? = nil,
        note: String? = nil
    ) async throws -> Result {
        guard let tvId = Int(track.tvId),
              let next = ShowProgress.from(track: track, catalogTotal: catalogTotal).next
        else { throw MarkError.noNextEpisode }

        let episodes = await seasonEpisodes(tvId: tvId, season: next.season)
        // TMDB has no such season, or the season doesn't list it: refuse rather than log a phantom episode.
        guard let episodes, let current = episodes.first(where: { $0.episode_number == next.episode }) else {
            throw MarkError.noNextEpisode
        }
        let later = laterInSeason(after: next, seasonEpisodes: episodes)

        var body = MarkEpisodeBody(
            tvId: track.tvId,
            seasonNumber: next.season,
            episodeNumber: next.episode,
            runtimeMinutes: runtime ?? current.runtime,
            episodeName: episodeName ?? current.name ?? next.name,
            tvTitle: track.tvTitle,
            tvPosterImage: track.posterPath,
            nextSeason: later?.season,
            nextEpisode: later?.episode,
            nextEpisodeName: later?.name
        )
        body.watchedAt = watchedAt.map(ISODate.string)
        body.note = note
        let updated = try await DiaryService.markEpisode(body)
        return Result(body: body, updated: updated)
    }

    static func undo(_ body: MarkEpisodeBody) async throws {
        try await DiaryService.unmarkEpisode(body)
    }

    // MARK: Season cache

    private actor SeasonStore {
        private var episodes: [String: [TVEpisode]] = [:]
        func get(_ key: String) -> [TVEpisode]? { episodes[key] }
        func set(_ key: String, _ value: [TVEpisode]) { episodes[key] = value }
    }

    private static let store = SeasonStore()

    private static func key(_ tvId: Int, _ season: Int) -> String { "\(tvId)-\(season)" }

    /// That season's episodes, from memory when we've already fetched them. Nil if TMDB has no such season.
    static func seasonEpisodes(tvId: Int, season: Int) async -> [TVEpisode]? {
        if let hit = await store.get(key(tvId, season)) { return hit }
        guard let episodes = try? await TMDBService.season(tvId: tvId, season: season).episodes else { return nil }
        await store.set(key(tvId, season), episodes)
        return episodes
    }

    /// Warms the season cache for each show's next episode so a tap can advance instantly.
    static func prefetch(_ tracks: [TrackingRecord]) async {
        await withTaskGroup(of: Void.self) { group in
            for track in tracks {
                guard let tvId = Int(track.tvId), let next = ShowProgress.from(track: track).next else { continue }
                group.addTask { _ = await seasonEpisodes(tvId: tvId, season: next.season) }
            }
        }
    }

    /// The row right after marking, for an instant update. Only when the cached season list confirms
    /// a later episode; otherwise nil and the row waits for the server's answer.
    static func preview(track: TrackingRecord) async -> TrackingRecord? {
        guard let tvId = Int(track.tvId), let next = ShowProgress.from(track: track).next,
              let cached = await store.get(key(tvId, next.season)),
              cached.contains(where: { $0.episode_number == next.episode }),
              let later = laterInSeason(after: next, seasonEpisodes: cached)
        else { return nil }
        return advanced(track, watched: next, next: later)
    }

    static func advanced(_ t: TrackingRecord, watched: EpisodePointer, next: EpisodePointer?) -> TrackingRecord {
        TrackingRecord(
            tvId: t.tvId, status: t.status, tvTitle: t.tvTitle, tvPosterImage: t.tvPosterImage, tvPost: t.tvPost,
            rating: t.rating, nextSeason: next?.season, nextEpisode: next?.episode,
            nextEpisodeName: next?.name, lastSeason: watched.season, lastEpisode: watched.episode,
            watchedEpisodeCount: (t.watchedEpisodeCount ?? 0) + 1, totalEpisodes: t.totalEpisodes,
            airedEpisodeCount: t.airedEpisodeCount, timesCompleted: t.timesCompleted,
            activeRewatchSessionId: t.activeRewatchSessionId
        )
    }
}
