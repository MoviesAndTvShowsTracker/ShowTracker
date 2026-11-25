import Foundation

/// The two ways to take the diary out of Marquee.
enum DiaryExportFormat: String, CaseIterable, Identifiable, Sendable {
    case csv
    case json

    var id: String { rawValue }
    var query: String { rawValue }

    var title: String {
        switch self {
        case .csv: "Spreadsheet (CSV)"
        case .json: "Everything (JSON)"
        }
    }

    var detail: String {
        switch self {
        case .csv: "One row per watch, with dates, ratings and notes. Opens in Numbers, Excel or Google Sheets."
        case .json: "Your diary plus shows, watchlists and favorites. For moving to another app."
        }
    }

    var systemImage: String {
        switch self {
        case .csv: "tablecells"
        case .json: "curlybraces"
        }
    }

    func fileName(on date: Date = .now, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        let stamp = String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
        return "marquee-diary-\(stamp).\(rawValue)"
    }

    static func sizeText(bytes: Int) -> String {
        if bytes < 1000 { return "\(bytes) bytes" }
        return ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
