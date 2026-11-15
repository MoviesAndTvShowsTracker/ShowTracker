import Foundation

struct EpisodePointer: Hashable {
    let season: Int
    let episode: Int
    var name: String?
}

struct ShowProgress {
    var watched: Int
    var total: Int
    var next: EpisodePointer?
    var last: EpisodePointer?
    var isComplete: Bool

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, Double(watched) / Double(total))
    }

    var percent: Int { Int((fraction * 100).rounded()) }

    var episodeLine: String {
        if isComplete { return "Finished" }
        if let next {
            return "Season \(next.season) · Episode \(next.episode)"
        }
        if let last {
            return "Season \(last.season) · Episode \(last.episode) watched"
        }
        return "In progress"
    }

    var caption: String {
        if isComplete { return "All \(watched) episodes watched" }
        if total > 0 { return "\(watched) of \(total) episodes" }
        if watched > 0 { return "\(watched) episode\(watched == 1 ? "" : "s") watched" }
        return "Not started"
    }

    static func from(
        track: TrackingRecord?,
        catalogTotal: Int? = nil,
        watchedCount: Int? = nil
    ) -> ShowProgress {
        let watched = watchedCount ?? track?.watchedEpisodeCount ?? 0
        let aired = positive(track?.airedEpisodeCount)
        let listed = positive(track?.totalEpisodes)
        let catalog = positive(catalogTotal)
        let total = aired ?? listed ?? catalog ?? 0
        let complete = track?.status == "completed" || (total > 0 && watched >= total)

        let last: EpisodePointer? = {
            if let s = track?.lastSeason, let e = track?.lastEpisode, s > 0, e > 0 {
                return EpisodePointer(season: s, episode: e)
            }
            return nil
        }()

        let next: EpisodePointer? = {
            if complete { return nil }
            if let s = track?.nextSeason, let e = track?.nextEpisode, s > 0, e > 0 {
                return EpisodePointer(season: s, episode: e, name: track?.nextEpisodeName)
            }
            if let last {
                return EpisodePointer(season: last.season, episode: last.episode + 1)
            }
            if watched > 0 {
                return EpisodePointer(season: 1, episode: watched + 1)
            }
            return EpisodePointer(season: 1, episode: 1)
        }()

        return ShowProgress(
            watched: watched,
            total: total,
            next: next,
            last: last,
            isComplete: complete
        )
    }

    /// First unwatched episode in an ordered season list, used on the show page.
    static func nextInSeason(
        track: TrackingRecord?,
        season: Int,
        episodes: [TVEpisode],
        watchedKeys: Set<String>,
        catalogTotal: Int? = nil
    ) -> ShowProgress {
        var progress = from(track: track, catalogTotal: catalogTotal, watchedCount: max(track?.watchedEpisodeCount ?? 0, watchedKeys.count))
        if let existing = progress.next,
           let match = episodes.first(where: { ($0.season_number ?? season) == existing.season && $0.episode_number == existing.episode }) {
            progress.next?.name = match.name
            return progress
        }
        if progress.next == nil, !progress.isComplete,
           let ep = episodes.first(where: { ep in
               let s = ep.season_number ?? season
               return !watchedKeys.contains("\(s)-\(ep.episode_number)")
           }) {
            progress.next = EpisodePointer(
                season: ep.season_number ?? season,
                episode: ep.episode_number,
                name: ep.name
            )
        }
        return progress
    }
}

private func positive(_ value: Int?) -> Int? {
    guard let value, value > 0 else { return nil }
    return value
}
