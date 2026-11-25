import Foundation

struct UpNextItem: Codable, Identifiable, Sendable {
    var id: String { track.tvId }
    var track: TrackingRecord
    var nextAirDate: String?
}

struct AgendaEpisode: Codable, Identifiable, Sendable, Equatable {
    var id: String { "\(tvId)-\(season)-\(episode)" }
    let tvId: Int
    let title: String
    let posterPath: String?
    let season: Int
    let episode: Int
    let episodeName: String?
    let airDate: String
    let kind: String // "airing" | "returning"
}

struct HomeFeed: Codable, Sendable {
    var upNext: [UpNextItem] = []
    var pausedCount = 0
    var thisWeek: [AgendaEpisode] = []
    var recent: [DiaryActivityItem] = []
    var recap: WeekRecap?
    var films: [FavoriteMovieDoc] = []
    var tv: [FavoriteTVDoc] = []

    static let empty = HomeFeed()
}

enum UpNextTrailing: Equatable {
    case mark
    case airs(String)
    case chevron
}

struct AgendaRow: Identifiable, Equatable {
    var id: String { episode.id }
    let dayLabel: String?
    let episode: AgendaEpisode
}

enum HomeFeedLogic {
    static func trailing(for item: UpNextItem, today: Date, calendar: Calendar = .current) -> UpNextTrailing {
        if item.track.status == "rewatching" { return .chevron }
        if ShowProgress.from(track: item.track).next == nil { return .chevron }
        guard let raw = item.nextAirDate, let air = day(raw, calendar) else { return .mark }
        let start = calendar.startOfDay(for: today)
        if air <= start { return .mark }
        return .airs(shortDay(air, today: start, calendar: calendar, tonight: "Tonight"))
    }

    static func progressCaption(_ p: ShowProgress) -> String? {
        p.total > 0 ? "\(p.watched) of \(p.total)" : nil
    }

    /// "Tonight", "Tomorrow", "Thu 26".
    static func dayLabel(_ airDate: String, today: Date, calendar: Calendar = .current) -> String {
        guard let air = day(airDate, calendar) else { return airDate }
        let start = calendar.startOfDay(for: today)
        let diff = calendar.dateComponents([.day], from: start, to: air).day ?? 0
        if diff == 0 { return "Tonight" }
        if diff == 1 { return "Tomorrow" }
        let f = Date.FormatStyle(timeZone: calendar.timeZone).weekday(.abbreviated)
        let d = calendar.component(.day, from: air)
        if diff < 7 { return "\(air.formatted(f)) \(d)" }
        return air.formatted(Date.FormatStyle(timeZone: calendar.timeZone).month(.abbreviated).day())
    }

    static func agendaRows(_ eps: [AgendaEpisode], today: Date, calendar: Calendar = .current) -> [AgendaRow] {
        let start = calendar.startOfDay(for: today)
        let kept = eps.filter { ep in
            guard let air = day(ep.airDate, calendar), air >= start else { return false }
            let diff = calendar.dateComponents([.day], from: start, to: air).day ?? 0
            return diff <= (ep.kind == "returning" ? 30 : 7)
        }
        .sorted { $0.airDate < $1.airDate }
        .prefix(8)

        var lastDay: String?
        return kept.map { ep in
            defer { lastDay = ep.airDate }
            let label = ep.airDate == lastDay ? nil : dayLabel(ep.airDate, today: today, calendar: calendar)
            return AgendaRow(dayLabel: label, episode: ep)
        }
    }

    static func recentCaption(_ item: DiaryActivityItem, today: Date, calendar: Calendar = .current) -> String {
        let when = item.dayKey.flatMap { day($0, calendar) }.map {
            relativeDay($0, today: calendar.startOfDay(for: today), calendar: calendar)
        }
        if item.kind == "film" {
            if var rating = item.rating, rating > 0 {
                if rating > 5 { rating /= 2 } // legacy 10-point ratings
                return "Film · ★\(rating.formatted(.number.precision(.fractionLength(0...1))))"
            }
            return ["Film", when].compactMap { $0 }.joined(separator: " · ")
        }
        var code = (item.subtitle ?? "")
        if code.hasPrefix("Rewatch · ") { code.removeFirst("Rewatch · ".count) }
        code = code.components(separatedBy: " · ").first ?? code
        return [code.isEmpty ? nil : code, when].compactMap { $0 }.joined(separator: " · ")
    }

    static func headerSubtitle(_ feed: HomeFeed, today: Date, calendar: Calendar = .current) -> String {
        let todayKey = key(today, calendar)
        let tonight = feed.thisWeek.first { $0.kind == "airing" && $0.airDate == todayKey }?.title
        let n = feed.upNext.count
        if n > 0 {
            let waiting = "\(n) show\(n == 1 ? "" : "s") waiting"
            return tonight.map { "\(waiting) · \($0) airs tonight" } ?? "\(waiting)."
        }
        if let tonight { return "\(tonight) airs tonight." }
        if !feed.thisWeek.isEmpty { return "New episodes this week." }
        if !feed.films.isEmpty || !feed.tv.isEmpty { return "Your watchlist is waiting." }
        return "Let’s start your diary."
    }

    static func isStarter(_ feed: HomeFeed) -> Bool {
        feed.upNext.isEmpty && feed.pausedCount == 0 && feed.thisWeek.isEmpty
            && feed.recent.isEmpty && feed.films.isEmpty && feed.tv.isEmpty
    }

    // MARK: - Dates

    static func day(_ raw: String, _ calendar: Calendar) -> Date? {
        let parts = raw.prefix(10).split(separator: "-")
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        return calendar.date(from: DateComponents(year: y, month: m, day: d))
    }

    static func key(_ date: Date, _ calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    private static func shortDay(_ air: Date, today: Date, calendar: Calendar, tonight: String) -> String {
        let diff = calendar.dateComponents([.day], from: today, to: air).day ?? 0
        if diff <= 0 { return tonight }
        if diff == 1 { return "Tomorrow" }
        if diff < 7 { return "In \(diff) days" }
        return air.formatted(Date.FormatStyle(timeZone: calendar.timeZone).month(.abbreviated).day())
    }

    private static func relativeDay(_ date: Date, today: Date, calendar: Calendar) -> String {
        let diff = calendar.dateComponents([.day], from: date, to: today).day ?? 0
        if diff <= 0 { return "Today" }
        if diff == 1 { return "Yesterday" }
        let style = Date.FormatStyle(timeZone: calendar.timeZone)
        if diff < 7 { return date.formatted(style.weekday(.abbreviated)) }
        return date.formatted(style.month(.abbreviated).day())
    }
}
