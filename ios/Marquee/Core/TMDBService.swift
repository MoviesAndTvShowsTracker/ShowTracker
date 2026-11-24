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

    static func person(id: Int) async throws -> PersonDetail {
        try await APIClient.shared.get(
            "/api/tmdb/person/\(id)",
            query: [URLQueryItem(name: "append_to_response", value: "combined_credits")],
            auth: false
        )
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

    /// Raw movie discover for curated shelves (params are TMDB discover keys).
    static func discoverMovies(_ params: [String: String]) async throws -> [MediaItem] {
        var query = [URLQueryItem(name: "include_adult", value: "false")]
        query += params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        let page: TMDBPaged<MediaItem> = try await APIClient.shared.get("/api/tmdb/discover/movie", query: query, auth: false)
        return page.results
    }

    /// Raw TV discover for curated shelves (params are TMDB discover keys).
    static func discoverTV(_ params: [String: String]) async throws -> [MediaItem] {
        var query = [URLQueryItem(name: "include_adult", value: "false")]
        query += params.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
        let page: TMDBPaged<MediaItem> = try await APIClient.shared.get("/api/tmdb/discover/tv", query: query, auth: false)
        return page.results
    }

    static func trendingPeople() async throws -> [TrendingPerson] {
        let page: TMDBPaged<TrendingPerson> = try await APIClient.shared.get("/api/tmdb/trending/person/week", auth: false)
        return page.results
    }

    static func trailerURL(id: Int, kind: MediaKind) async -> URL? {
        let path = kind == .movie ? "movie" : "tv"
        guard let res: TMDBVideoList = try? await APIClient.shared.get("/api/tmdb/\(path)/\(id)/videos", auth: false) else { return nil }
        let youtube = (res.results ?? []).filter { $0.site == "YouTube" && $0.type == "Trailer" }
        guard let pick = youtube.first(where: { $0.official == true }) ?? youtube.first else { return nil }
        return URL(string: "https://www.youtube.com/watch?v=\(pick.key)")
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
        if let years = browse.years {
            let field = browse.kind == .movie ? "primary_release_date" : "first_air_date"
            query.append(URLQueryItem(name: "\(field).gte", value: "\(years.lowerBound)-01-01"))
            query.append(URLQueryItem(name: "\(field).lte", value: "\(years.upperBound)-12-31"))
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
        case .person: path = "search/person"
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
        case multi, movie, tv, person
        var id: String { rawValue }
        var label: String {
            switch self {
            case .multi: return "All"
            case .movie: return "Films"
            case .tv: return "TV"
            case .person: return "People"
            }
        }
    }
}
