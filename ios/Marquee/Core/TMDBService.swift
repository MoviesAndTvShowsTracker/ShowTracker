import Foundation

enum TMDBService {
    static func fetchPaged(_ path: String, page: Int = 1) async throws -> TMDBPaged<MediaItem> {
        try await APIClient.shared.get(
            "/api/tmdb/\(path)",
            query: [URLQueryItem(name: "page", value: String(page))],
            auth: false
        )
    }

    static func movieDetail(id: Int) async throws -> MovieDetail {
        try await APIClient.shared.get(
            "/api/tmdb/movie/\(id)",
            query: [URLQueryItem(name: "append_to_response", value: "credits,similar")],
            auth: false
        )
    }

    static func tvDetail(id: Int) async throws -> TVDetail {
        try await APIClient.shared.get(
            "/api/tmdb/tv/\(id)",
            query: [URLQueryItem(name: "append_to_response", value: "credits,similar")],
            auth: false
        )
    }

    static func season(tvId: Int, season: Int) async throws -> SeasonDetail {
        try await APIClient.shared.get("/api/tmdb/tv/\(tvId)/season/\(season)", auth: false)
    }

    static func discoverMovies(genreIds: [Int], page: Int = 1) async throws -> TMDBPaged<MediaItem> {
        var query = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
        ]
        if !genreIds.isEmpty {
            query.append(URLQueryItem(name: "with_genres", value: genreIds.map(String.init).joined(separator: ",")))
        }
        return try await APIClient.shared.get("/api/tmdb/discover/movie", query: query, auth: false)
    }

    static func discoverTV(genreIds: [Int], page: Int = 1) async throws -> TMDBPaged<MediaItem> {
        var query = [
            URLQueryItem(name: "page", value: String(page)),
            URLQueryItem(name: "sort_by", value: "popularity.desc"),
        ]
        if !genreIds.isEmpty {
            query.append(URLQueryItem(name: "with_genres", value: genreIds.map(String.init).joined(separator: ",")))
        }
        return try await APIClient.shared.get("/api/tmdb/discover/tv", query: query, auth: false)
    }

    static func search(query: String, type: SearchType, page: Int = 1) async throws -> TMDBPaged<MediaItem> {
        let path: String
        switch type {
        case .multi: path = "search/multi"
        case .movie: path = "search/movie"
        case .tv: path = "search/tv"
        }
        return try await APIClient.shared.get(
            "/api/tmdb/\(path)",
            query: [
                URLQueryItem(name: "query", value: query),
                URLQueryItem(name: "page", value: String(page)),
            ],
            auth: false
        )
    }

    enum SearchType: String, CaseIterable, Identifiable {
        case multi, movie, tv
        var id: String { rawValue }
        var label: String {
            switch self {
            case .multi: return "All"
            case .movie: return "Films"
            case .tv: return "TV"
            }
        }
    }
}
