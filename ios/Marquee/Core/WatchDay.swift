import Foundation

/// When something was watched, as the log sheet's pills express it.
enum WatchDay: Hashable, Sendable {
    case today
    case yesterday
    case custom(Date)

    /// The moment to store. Past days keep the current time of day so logs stay in a natural order;
    /// nothing is ever in the future.
    /// `timeOf`: keep that moment's time of day (when moving an existing log to another day).
    func date(now: Date = .now, calendar: Calendar = .current, timeOf: Date? = nil) -> Date {
        switch self {
        case .today:
            return now
        case .yesterday:
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: now) else { return now }
            guard let timeOf else { return yesterday }
            return WatchDay.custom(yesterday).date(now: now, calendar: calendar, timeOf: timeOf)
        case .custom(let picked):
            let day = calendar.dateComponents([.year, .month, .day], from: picked)
            let time = calendar.dateComponents([.hour, .minute, .second], from: timeOf ?? now)
            var parts = DateComponents()
            parts.year = day.year; parts.month = day.month; parts.day = day.day
            parts.hour = time.hour; parts.minute = time.minute; parts.second = time.second
            let moment = calendar.date(from: parts) ?? picked
            return min(moment, now)
        }
    }

    /// The pill an existing log's date belongs to.
    static func from(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> WatchDay {
        if calendar.isDate(date, inSameDayAs: now) { return .today }
        if let yesterday = calendar.date(byAdding: .day, value: -1, to: now),
           calendar.isDate(date, inSameDayAs: yesterday) { return .yesterday }
        return .custom(date)
    }

    /// "Today", "Yesterday", "Sat, Mar 7" (this year) or "Feb 14, 2024".
    func label(now: Date = .now, calendar: Calendar = .current) -> String {
        switch self {
        case .today: return "Today"
        case .yesterday: return "Yesterday"
        case .custom(let date):
            let style = Date.FormatStyle(calendar: calendar, timeZone: calendar.timeZone)
            if calendar.isDate(date, equalTo: now, toGranularity: .year) {
                return date.formatted(style.weekday(.abbreviated).month(.abbreviated).day())
            }
            return date.formatted(style.month(.abbreviated).day().year())
        }
    }

    var isCustom: Bool {
        if case .custom = self { return true }
        return false
    }
}
