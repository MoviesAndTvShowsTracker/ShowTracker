import Foundation

/// What your episode ratings say about a show: per-season averages and your best episodes.
struct EpisodeRatingsSummary {
    struct Entry: Equatable {
        let key: String
        let season: Int
        let episode: Int
        let stars: Double
        let name: String?
        var label: String { "S\(season) · E\(episode)" }
    }

    /// Stored ratings (1–10, half-stars doubled) by "season-episode", and names where known.
    let ratings: [String: Double]
    let names: [String: String]

    private var entries: [Entry] {
        ratings.compactMap { key, stored in
            guard stored > 0 else { return nil }
            let parts = key.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2 else { return nil }
            return Entry(key: key, season: parts[0], episode: parts[1], stars: stored / 2, name: names[key])
        }
    }

    /// Average stars across the season's rated episodes; nil when none are rated.
    func average(season: Int) -> Double? {
        let rated = entries.filter { $0.season == season }
        guard !rated.isEmpty else { return nil }
        return rated.map(\.stars).reduce(0, +) / Double(rated.count)
    }

    /// Highest rated first; ties go to the earlier episode.
    func best(limit: Int = 3) -> [Entry] {
        Array(entries.sorted {
            if $0.stars != $1.stars { return $0.stars > $1.stars }
            return ($0.season, $0.episode) < ($1.season, $1.episode)
        }.prefix(limit))
    }

    /// "Best episodes" needs a few ratings to mean anything.
    var hasBest: Bool { entries.count >= 3 }
}
