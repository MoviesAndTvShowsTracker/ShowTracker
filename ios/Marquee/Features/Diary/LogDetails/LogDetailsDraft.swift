import Foundation

/// What the log sheet edits: when, an optional rating (films), and a note.
struct LogDetailsDraft: Equatable, Sendable {
    var day: WatchDay = .today
    /// Out of 5; nil when the sheet doesn't rate (episodes) or nothing was chosen.
    var rating: Double?
    var note: String = ""
}

/// What is being logged, shown at the top of the sheet so it's clear what you're saving.
struct LogDetailsSubject: Equatable, Sendable {
    let title: String
    let subtitle: String?
    let posterPath: String?
}
