import Foundation

struct ExternalScore: Decodable, Hashable, Sendable {
    let value: Double
    let scale: Int
    var votes: String? = nil
}

struct MediaRatings: Decodable, Hashable, Sendable {
    let id: Int
    let kind: String?
    let imdbId: String?
    let tmdb: ExternalScore?
    let imdb: ExternalScore?
    let rottenTomatoes: ExternalScore?
    let metacritic: ExternalScore?

    var chips: [RatingsChip] {
        var out: [RatingsChip] = []
        if let tmdb {
            out.append(.init(id: "tmdb", label: "TMDB", display: String(format: "%.1f", tmdb.value), detail: "/\(tmdb.scale)"))
        }
        if let imdb {
            out.append(.init(id: "imdb", label: "IMDb", display: String(format: "%.1f", imdb.value), detail: "/\(imdb.scale)"))
        }
        if let rottenTomatoes {
            out.append(.init(id: "rt", label: "Tomatoes", display: "\(Int(rottenTomatoes.value))%", detail: nil))
        }
        if let metacritic {
            out.append(.init(id: "mc", label: "Metascore", display: "\(Int(metacritic.value))", detail: nil))
        }
        return out
    }
}

struct RatingsChip: Identifiable, Hashable {
    let id: String
    let label: String
    let display: String
    let detail: String?
}

enum RatingsService {
    static func load(kind: MediaKind, id: Int) async -> MediaRatings? {
        let path = kind == .movie ? "/api/ratings/movie/\(id)" : "/api/ratings/tv/\(id)"
        return try? await APIClient.shared.get(path, auth: false)
    }
}
