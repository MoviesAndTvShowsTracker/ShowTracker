import Foundation

enum MediaKind: String, Hashable, Sendable {
    case movie
    case tv
}

struct TMDBPaged<T: Decodable & Sendable>: Decodable, Sendable {
    let page: Int?
    let results: [T]
    let total_pages: Int?
    let total_results: Int?
}

struct MediaItem: Codable, Identifiable, Hashable, Sendable{
    let id: Int
    let title: String?
    let name: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let release_date: String?
    let first_air_date: String?
    let vote_average: Double?
    let media_type: String?
    let genre_ids: [Int]?

    var displayTitle: String { title ?? name ?? "Untitled" }
    var year: String? {
        let date = release_date ?? first_air_date
        guard let date, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }
}

struct Genre: Codable, Hashable, Identifiable, Sendable{
    let id: Int
    let name: String
}

struct Credits: Codable, Sendable{
    let cast: [CastMember]?
    let crew: [CrewMember]?
}

struct CastMember: Codable, Identifiable, Hashable, Sendable{
    let id: Int
    let name: String?
    let character: String?
    let profile_path: String?
}

struct CrewMember: Codable, Identifiable, Hashable, Sendable{
    var id: String { credit_id }
    let credit_id: String
    let name: String?
    let job: String?
}

struct MovieDetail: Decodable, Identifiable, Sendable{
    let id: Int
    let title: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let release_date: String?
    let runtime: Int?
    let vote_average: Double?
    let genres: [Genre]?
    let credits: Credits?
    let similar: TMDBPaged<MediaItem>?

    var displayTitle: String { title ?? "Untitled" }
    var year: String? {
        guard let release_date, release_date.count >= 4 else { return nil }
        return String(release_date.prefix(4))
    }
}

struct Network: Decodable, Hashable, Sendable{
    let id: Int?
    let name: String?
}

struct TVDetail: Decodable, Identifiable, Sendable{
    let id: Int
    let name: String?
    let overview: String?
    let poster_path: String?
    let backdrop_path: String?
    let first_air_date: String?
    let last_air_date: String?
    let vote_average: Double?
    let genres: [Genre]?
    let status: String?
    let episode_run_time: [Int]?
    let number_of_seasons: Int?
    let number_of_episodes: Int?
    let networks: [Network]?
    let seasons: [TVSeason]?
    let credits: Credits?
    let similar: TMDBPaged<MediaItem>?

    var displayTitle: String { name ?? "Untitled" }
    var typicalRuntime: Int? { episode_run_time?.first }
    var networkNames: String? {
        let names = (networks ?? []).compactMap(\.name)
        return names.isEmpty ? nil : names.joined(separator: ", ")
    }
}

struct TVSeason: Codable, Identifiable, Hashable, Sendable{
    var id: Int { season_number }
    let season_number: Int
    let name: String?
    let episode_count: Int?
    let poster_path: String?
}

struct SeasonDetail: Codable, Sendable{
    let id: Int?
    let season_number: Int?
    let name: String?
    let episodes: [TVEpisode]?
}

struct TVEpisode: Codable, Identifiable, Hashable, Sendable{
    let id: Int
    let name: String?
    let overview: String?
    let still_path: String?
    let episode_number: Int
    let season_number: Int?
    let runtime: Int?
    let air_date: String?

    var diaryKey: String { "\(season_number ?? 0)-\(episode_number)" }

    /// Released today or earlier. Missing dates count as aired, matching the web diary.
    var hasAired: Bool {
        guard let air_date, air_date.count >= 10 else { return true }
        let parts = air_date.split(separator: "-")
        guard parts.count >= 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else {
            return true
        }
        var comps = DateComponents()
        comps.year = y
        comps.month = m
        comps.day = d
        guard let date = Calendar.current.date(from: comps) else { return true }
        return Calendar.current.startOfDay(for: date) <= Calendar.current.startOfDay(for: Date())
    }
}

