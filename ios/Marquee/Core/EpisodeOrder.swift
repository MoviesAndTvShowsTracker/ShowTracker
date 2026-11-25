import Foundation

/// Which episodes "Mark watched up to here" covers.
enum EpisodeOrder {
    /// Aired, unwatched episodes from the start of the show through (season, episode), in order.
    /// Specials (season 0) only count when the target is itself a special.
    static func upTo(season: Int, episode: Int, catalog: [TVEpisode], watched: Set<String>) -> [TVEpisode] {
        catalog
            .filter { ep in
                let s = ep.season_number ?? 0
                if season > 0 && s == 0 { return false }
                if season == 0 && s != 0 { return false }
                let before = s < season || (s == season && ep.episode_number <= episode)
                return before && ep.hasAired && !watched.contains(ep.diaryKey)
            }
            .sorted {
                let ls = $0.season_number ?? 0, rs = $1.season_number ?? 0
                return ls == rs ? $0.episode_number < $1.episode_number : ls < rs
            }
    }
}
