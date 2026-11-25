import Foundation

/// Local play bookkeeping for the show page, so a first watch doesn't need a server round trip.
enum EpisodePlays {
    /// After logging a first watch of `key`: one play, dated `at` (the server's ISO format).
    static func afterFirstWatch(
        counts: [String: Int],
        dates: [String: [String]],
        key: String,
        at: Date
    ) -> ([String: Int], [String: [String]]) {
        var counts = counts
        var dates = dates
        if (counts[key] ?? 0) == 0 {
            counts[key] = 1
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            dates[key] = (dates[key] ?? []) + [iso.string(from: at)]
        }
        return (counts, dates)
    }
}
