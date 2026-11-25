import Foundation

/// Rules for the short note on a log (the server enforces the same limit).
enum DiaryNote {
    static let limit = 500
    /// The counter appears once a note gets this close to the limit.
    static let counterThreshold = 400

    static func clamped(_ text: String) -> String {
        text.count > limit ? String(text.prefix(limit)) : text
    }

    static func counter(for text: String) -> String? {
        text.count >= counterThreshold ? "\(text.count)/\(limit)" : nil
    }

    static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
