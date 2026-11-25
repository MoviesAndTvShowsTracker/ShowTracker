import Foundation

/// What the show page's header offers: one primary action per state.
enum TVHeaderState: Equatable {
    case notStarted(season: Int)
    case premieres(label: String)
    case watching
    case rewatching
    case paused
    case finished(rated: Bool)
}

/// Decisions behind the show page, kept out of the views so they can be tested.
enum TVShowPageLogic {
    static func headerState(
        status: String?,
        showRating: Double,
        seasons: [Int],
        firstAirDate: String?,
        showStatus: String?,
        today: Date,
        calendar: Calendar = .current
    ) -> TVHeaderState {
        switch status {
        case nil:
            if let label = premiereLabel(firstAirDate: firstAirDate, showStatus: showStatus, today: today, calendar: calendar) {
                return .premieres(label: label)
            }
            return .notStarted(season: startSeason(seasons))
        case "rewatching": return .rewatching
        case "paused", "dropped": return .paused
        case "completed": return .finished(rated: showRating > 0)
        default: return .watching
        }
    }

    /// First real season; specials (season 0) never start a show.
    static func startSeason(_ seasons: [Int]) -> Int {
        seasons.filter { $0 > 0 }.min() ?? 1
    }

    static func seasonCountLine(watched: Int, aired: Int, total: Int) -> String {
        let line = "\(watched) of \(aired) watched"
        return total > aired ? "\(line) · \(total - aired) to air" : line
    }

    /// On a one-season show, "whole show" is the same as "season", so it isn't offered.
    static func offersWholeShow(seasonCount: Int, canMarkWholeShow: Bool) -> Bool {
        seasonCount > 1 && canMarkWholeShow
    }

    private static func premiereLabel(firstAirDate: String?, showStatus: String?, today: Date, calendar: Calendar) -> String? {
        guard let raw = firstAirDate, !raw.isEmpty else {
            return ["Planned", "In Production"].contains(showStatus ?? "") ? "Not aired yet" : nil
        }
        guard let day = HomeFeedLogic.day(raw, calendar), day > calendar.startOfDay(for: today) else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d"
        return "Premieres \(formatter.string(from: day))"
    }
}
