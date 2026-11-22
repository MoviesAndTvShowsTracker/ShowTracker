import Foundation

enum BrowseSort: String, CaseIterable, Identifiable {
    case popular
    case topRated
    case newest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .popular: return "Popular"
        case .topRated: return "Top rated"
        case .newest: return "Newest"
        }
    }

    func tmdbValue(kind: MediaKind) -> String {
        switch (self, kind) {
        case (.popular, _):
            return "popularity.desc"
        case (.topRated, _):
            return "vote_average.desc"
        case (.newest, .movie):
            return "primary_release_date.desc"
        case (.newest, .tv):
            return "first_air_date.desc"
        }
    }
}

struct BrowseGenre: Identifiable, Hashable {
    let id: Int
    let name: String

    static func catalog(for kind: MediaKind) -> [BrowseGenre] {
        switch kind {
        case .movie:
            return [
                .init(id: 28, name: "Action"),
                .init(id: 12, name: "Adventure"),
                .init(id: 16, name: "Animation"),
                .init(id: 35, name: "Comedy"),
                .init(id: 80, name: "Crime"),
                .init(id: 99, name: "Documentary"),
                .init(id: 18, name: "Drama"),
                .init(id: 10751, name: "Family"),
                .init(id: 14, name: "Fantasy"),
                .init(id: 27, name: "Horror"),
                .init(id: 9648, name: "Mystery"),
                .init(id: 10749, name: "Romance"),
                .init(id: 878, name: "Sci-Fi"),
                .init(id: 53, name: "Thriller"),
                .init(id: 37, name: "Western"),
            ]
        case .tv:
            return [
                .init(id: 10759, name: "Action"),
                .init(id: 16, name: "Animation"),
                .init(id: 35, name: "Comedy"),
                .init(id: 80, name: "Crime"),
                .init(id: 99, name: "Documentary"),
                .init(id: 18, name: "Drama"),
                .init(id: 10751, name: "Family"),
                .init(id: 10762, name: "Kids"),
                .init(id: 9648, name: "Mystery"),
                .init(id: 10764, name: "Reality"),
                .init(id: 10765, name: "Sci-Fi"),
                .init(id: 37, name: "Western"),
            ]
        }
    }
}

struct BrowseQuery: Equatable {
    var kind: MediaKind
    var sort: BrowseSort = .popular
    var genreId: Int? = nil
    var providerIds: Set<Int> = []
    var watchRegion: String = Locale.current.region?.identifier.uppercased() ?? "US"
    var page: Int = 1

    var summary: String {
        var bits: [String] = [sort.label.lowercased()]
        if let genreId,
           let genre = BrowseGenre.catalog(for: kind).first(where: { $0.id == genreId }) {
            bits.append(genre.name.lowercased())
        }
        let kindWord = kind == .movie ? "films" : "shows"
        var line = "Showing \(bits.joined(separator: " ")) \(kindWord)"
        if !providerIds.isEmpty {
            let names = StreamingProviderOption.allCases
                .filter { providerIds.contains($0.rawValue) }
                .map(\.title)
            if names.count == 1 {
                line += " on \(names[0])"
            } else if names.count > 1 {
                line += " on your services"
            }
        }
        return line + "."
    }
}
