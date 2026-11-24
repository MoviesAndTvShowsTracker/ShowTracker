import Foundation

/// Marks the next episode of a tracked show. Shared by Home and TVContinueView.
enum EpisodeMarker {
    struct Result: Sendable {
        let body: MarkEpisodeBody
        let updated: TrackingRecord?
    }

    /// The episode after `current`, given that season's episodes.
    static func following(after current: EpisodePointer, seasonEpisodes: [TVEpisode]?) -> EpisodePointer {
        guard let episodes = seasonEpisodes else {
            return EpisodePointer(season: current.season, episode: current.episode + 1)
        }
        if let later = episodes
            .filter({ $0.episode_number > current.episode })
            .min(by: { $0.episode_number < $1.episode_number }) {
            return EpisodePointer(season: later.season_number ?? current.season, episode: later.episode_number, name: later.name)
        }
        return EpisodePointer(season: current.season + 1, episode: 1)
    }

    static func markNext(
        track: TrackingRecord,
        catalogTotal: Int?,
        runtime: Int?,
        episodeName: String?
    ) async throws -> Result {
        guard let tvId = Int(track.tvId),
              let next = ShowProgress.from(track: track, catalogTotal: catalogTotal).next
        else { throw APIError.empty }

        let season = try? await TMDBService.season(tvId: tvId, season: next.season)
        let after = following(after: next, seasonEpisodes: season?.episodes)
        let current = season?.episodes?.first { $0.episode_number == next.episode }
        let total = catalogTotal ?? track.totalEpisodes ?? track.airedEpisodeCount

        let body = MarkEpisodeBody(
            tvId: track.tvId,
            seasonNumber: next.season,
            episodeNumber: next.episode,
            runtimeMinutes: runtime ?? current?.runtime,
            episodeName: episodeName ?? current?.name ?? next.name,
            tvTitle: track.tvTitle,
            tvPosterImage: track.posterPath,
            totalEpisodes: total,
            airedEpisodeCount: total,
            nextSeason: after.season,
            nextEpisode: after.episode,
            nextEpisodeName: after.name
        )
        try await DiaryService.markEpisode(body)
        let updated = try? await DiaryService.tracking(for: track.tvId)
        return Result(body: body, updated: updated)
    }

    static func undo(_ body: MarkEpisodeBody) async throws {
        try await DiaryService.unmarkEpisode(body)
    }
}
