import Foundation

/// One dated watch of a film, as the film's diary list shows it.
struct FilmPlay: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let watchedAt: String?
    let note: String?
    let rating: Double?
    let isRewatch: Bool?

    var date: Date? { ISODate.parse(watchedAt) }

    /// Ratings are stored out of 10 (older logs) or 5; shown out of 5.
    var stars: Double {
        guard let rating, rating > 0 else { return 0 }
        return rating > 5 ? rating / 2 : rating
    }

    var noteText: String? {
        guard let note else { return nil }
        let trimmed = DiaryNote.trimmed(note)
        return trimmed.isEmpty ? nil : trimmed
    }
}
