import Foundation

/// Loading and diary mutation helpers for `TVDetailView`.
@MainActor
enum TVDetailLoader {
    static func watchedKeySet(from docs: [WatchedEpisodeDoc]) -> Set<String> {
        Set(docs.compactMap { doc in
            guard let s = doc.seasonNumber, let e = doc.episodeNumber else { return nil }
            return "\(s)-\(e)"
        })
    }

    static func ratingMap(from docs: [WatchedEpisodeDoc]) -> [String: Double] {
        Dictionary(uniqueKeysWithValues: docs.compactMap { doc in
            guard let s = doc.seasonNumber, let e = doc.episodeNumber, let rating = doc.rating else { return nil }
            return ("\(s)-\(e)", rating)
        })
    }
}
