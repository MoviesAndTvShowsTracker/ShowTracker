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

struct CrewMember: Codable, Hashable, Sendable {
    /// TMDB person id (navigates to PersonView).
    let id: Int
    let credit_id: String
    let name: String?
    let job: String?
    var department: String? = nil
    var profile_path: String? = nil
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

// MARK: - Person / filmography

struct PersonDetail: Decodable, Identifiable, Sendable {
    let id: Int
    let name: String?
    let biography: String?
    let birthday: String?
    let deathday: String?
    let place_of_birth: String?
    let known_for_department: String?
    let profile_path: String?
    let combined_credits: PersonCombinedCredits?

    var displayName: String { name ?? "Untitled" }

    var lifespanLine: String? {
        guard let birthday, birthday.count >= 4 else { return nil }
        let birth = String(birthday.prefix(4))
        if let deathday, deathday.count >= 4 {
            return "\(birth)–\(String(deathday.prefix(4)))"
        }
        return "Born \(birth)"
    }

    /// TMDB's department ("Acting") as a role people say ("Actor").
    var roleLabel: String? {
        guard let dept = known_for_department, !dept.isEmpty else { return nil }
        switch dept {
        case "Acting": return "Actor"
        case "Directing": return "Director"
        case "Writing": return "Writer"
        case "Production": return "Producer"
        case "Sound": return "Composer"
        case "Camera": return "Cinematographer"
        case "Editing": return "Editor"
        default: return dept
        }
    }

    var metaLine: String {
        var parts: [String] = []
        if let roleLabel { parts.append(roleLabel) }
        if let lifespanLine { parts.append(lifespanLine) }
        return parts.joined(separator: " · ")
    }
}

struct PersonCombinedCredits: Decodable, Sendable {
    let cast: [PersonCredit]?
    let crew: [PersonCredit]?
}

struct PersonCredit: Decodable, Hashable, Sendable, Identifiable {
    let id: Int
    let media_type: String?
    let title: String?
    let name: String?
    let poster_path: String?
    let release_date: String?
    let first_air_date: String?
    let character: String?
    let job: String?
    let department: String?
    let vote_average: Double?
    let vote_count: Int?
    let adult: Bool?
    let credit_id: String?
    let episode_count: Int?

    var stableId: String { "\(media_type ?? "x")-\(id)-\(credit_id ?? character ?? job ?? "")" }

    var displayTitle: String { title ?? name ?? "Untitled" }

    var year: String? {
        let date = release_date ?? first_air_date
        guard let date, date.count >= 4 else { return nil }
        return String(date.prefix(4))
    }

    var dateKey: String { release_date ?? first_air_date ?? "" }

    var kind: MediaKind {
        media_type == "tv" ? .tv : .movie
    }

    var isAdult: Bool { adult == true }
}

