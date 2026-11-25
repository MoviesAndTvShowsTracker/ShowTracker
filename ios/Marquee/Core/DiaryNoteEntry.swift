import Foundation

/// One note in "Your notes": a film or episode log with the note you wrote.
struct DiaryNoteEntry: Decodable, Identifiable, Hashable, Sendable {
    let id: String
    let kind: String
    let mediaId: String
    let title: String
    let posterPath: String?
    let subtitle: String?
    let watchedAt: String?
    let note: String
    let rating: Double?

    var date: Date? { ISODate.parse(watchedAt) }
    var isFilm: Bool { kind == "film" }
    var stars: Double { (rating ?? 0) > 0 ? (rating ?? 0) / 2 : 0 }
}

struct DiaryNotesResponse: Decodable, Sendable {
    let success: Bool?
    let notes: [DiaryNoteEntry]?
}

/// Notes grouped under month headings, newest month first (order preserved).
enum DiaryNotesGrouping {
    struct Month: Identifiable, Hashable {
        let id: String
        let title: String
        let entries: [DiaryNoteEntry]
    }

    static func months(_ entries: [DiaryNoteEntry], calendar: Calendar = .current) -> [Month] {
        var order: [String] = []
        var buckets: [String: (title: String, entries: [DiaryNoteEntry])] = [:]
        for entry in entries {
            let date = entry.date ?? .distantPast
            let c = calendar.dateComponents([.year, .month], from: date)
            let key = "\(c.year ?? 0)-\(c.month ?? 0)"
            if buckets[key] == nil {
                order.append(key)
                let title = entry.date.map { $0.formatted(.dateTime.month(.wide).year()) } ?? "Undated"
                buckets[key] = (title, [])
            }
            buckets[key]?.entries.append(entry)
        }
        return order.compactMap { key in buckets[key].map { Month(id: key, title: $0.title, entries: $0.entries) } }
    }
}
