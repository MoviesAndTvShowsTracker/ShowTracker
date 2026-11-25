import Foundation

struct ExternalScore: Decodable, Hashable, Sendable {
    let value: Double
    let scale: Int
    var votes: String? = nil

    enum CodingKeys: String, CodingKey {
        case value, scale, votes
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        value = try c.decode(Double.self, forKey: .value)
        scale = try c.decode(Int.self, forKey: .scale)
        if let s = try? c.decode(String.self, forKey: .votes) {
            votes = s
        } else if let n = try? c.decode(Int.self, forKey: .votes) {
            votes = String(n)
        } else {
            votes = nil
        }
    }
}

enum RatingSource: String, Hashable, Sendable {
    case imdb
    case rottenTomatoes
    case metacritic
    case tmdb

    /// Plain source names: scores are shown as text, never with third-party logos.
    var label: String {
        switch self {
        case .imdb: "IMDb"
        case .rottenTomatoes: "Rotten Tomatoes"
        case .metacritic: "Metacritic"
        case .tmdb: "TMDB"
        }
    }
}

struct MediaRatings: Decodable, Hashable, Sendable {
    let id: Int
    let kind: String?
    let imdbId: String?
    let tmdb: ExternalScore?
    let imdb: ExternalScore?
    let rottenTomatoes: ExternalScore?
    let metacritic: ExternalScore?

    /// Order matches Plex / JustWatch: IMDb → Tomatoes → Metascore → TMDB.
    var chips: [RatingsChip] {
        var out: [RatingsChip] = []
        if let imdb {
            let display = String(format: "%.1f", imdb.value)
            out.append(.init(
                id: "imdb",
                source: .imdb,
                display: display,
                numericValue: imdb.value,
                accessibilityLabel: "IMDb \(display) out of \(imdb.scale)"
            ))
        }
        if let rottenTomatoes {
            let pct = Int(rottenTomatoes.value)
            out.append(.init(
                id: "rt",
                source: .rottenTomatoes,
                display: "\(pct)%",
                numericValue: rottenTomatoes.value,
                accessibilityLabel: "Rotten Tomatoes \(pct) percent"
            ))
        }
        if let metacritic {
            let score = Int(metacritic.value)
            out.append(.init(
                id: "mc",
                source: .metacritic,
                display: "\(score)",
                numericValue: metacritic.value,
                accessibilityLabel: "Metascore \(score)"
            ))
        }
        if let tmdb {
            let display = String(format: "%.1f", tmdb.value)
            out.append(.init(
                id: "tmdb",
                source: .tmdb,
                display: display,
                numericValue: tmdb.value,
                accessibilityLabel: "TMDB \(display) out of \(tmdb.scale)"
            ))
        }
        return out
    }
}

struct RatingsChip: Identifiable, Hashable {
    let id: String
    let source: RatingSource
    let display: String
    let numericValue: Double
    let accessibilityLabel: String

    /// The quiet scale after the figure ("/10"); percentages need none.
    var scaleText: String {
        switch source {
        case .imdb, .tmdb: "/10"
        case .metacritic: "/100"
        case .rottenTomatoes: ""
        }
    }
}

enum RatingsService {
    static func load(kind: MediaKind, id: Int) async -> MediaRatings? {
        let path = kind == .movie ? "/api/ratings/movie/\(id)" : "/api/ratings/tv/\(id)"
        return try? await APIClient.shared.get(path, auth: false)
    }
}
