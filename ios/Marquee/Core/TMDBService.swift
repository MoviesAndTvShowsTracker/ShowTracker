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
        try await discover(
            BrowseQuery(kind: .movie, sort: .popular, genreId: genreIds.first, page: page)
        )
    }

    static func discoverTV(genreIds: [Int], page: Int = 1) async throws -> TMDBPaged<MediaItem> {
        try await discover(
            BrowseQuery(kind: .tv, sort: .popular, genreId: genreIds.first, page: page)
        )
    }

    static func discover(_ browse: BrowseQuery) async throws -> TMDBPaged<MediaItem> {
        let path = browse.kind == .movie ? "/api/tmdb/discover/movie" : "/api/tmdb/discover/tv"
        var query = [
            URLQueryItem(name: "page", value: String(max(1, browse.page))),
            URLQueryItem(name: "sort_by", value: browse.sort.tmdbValue(kind: browse.kind)),
            URLQueryItem(name: "include_adult", value: "false"),
        ]
        if let genreId = browse.genreId {
            query.append(URLQueryItem(name: "with_genres", value: String(genreId)))
        }
        if browse.sort == .topRated {
            // Avoid obscure 10.0 one-vote titles when sorting by rating.
            query.append(URLQueryItem(name: "vote_count.gte", value: "80"))
        }
        if !browse.providerIds.isEmpty {
            let aliases = browse.providerIds.reduce(into: Set<Int>()) { partial, raw in
                if let option = StreamingProviderOption(rawValue: raw) {
                    partial.formUnion(option.aliases)
                } else {
                    partial.insert(raw)
                }
            }
            // Pipe = OR across selected services.
            query.append(
                URLQueryItem(
                    name: "with_watch_providers",
                    value: aliases.map(String.init).sorted().joined(separator: "|")
                )
            )
            query.append(URLQueryItem(name: "watch_region", value: browse.watchRegion))
            query.append(URLQueryItem(name: "with_watch_monetization_types", value: "flatrate|free|ads"))
        }
        return try await APIClient.shared.get(path, query: query, auth: false)
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
