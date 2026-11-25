import Foundation

/// The server's dates: ISO 8601 in UTC, with or without milliseconds.
enum ISODate {
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        if let date = try? Date(raw, strategy: Date.ISO8601FormatStyle(includingFractionalSeconds: true)) {
            return date
        }
        return try? Date(raw, strategy: Date.ISO8601FormatStyle())
    }

    /// Same shape the server writes (`toISOString()`).
    static func string(_ date: Date) -> String {
        date.formatted(Date.ISO8601FormatStyle(includingFractionalSeconds: true))
    }
}
