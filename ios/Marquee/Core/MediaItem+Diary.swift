import Foundation

extension MediaItem {
    /// A catalogue item from a diary row (id, title, poster), so diary rails get the same
    /// long-press actions and badges as catalogue posters.
    static func diary(id: String, title: String, posterPath: String?, kind: MediaKind) -> MediaItem? {
        guard let tmdbId = Int(id) else { return nil }
        return MediaItem(
            id: tmdbId,
            title: kind == .movie ? title : nil,
            name: kind == .tv ? title : nil,
            overview: nil,
            poster_path: posterPath,
            backdrop_path: nil,
            release_date: nil,
            first_air_date: nil,
            vote_average: nil,
            media_type: kind == .movie ? "movie" : "tv",
            genre_ids: nil
        )
    }
}
