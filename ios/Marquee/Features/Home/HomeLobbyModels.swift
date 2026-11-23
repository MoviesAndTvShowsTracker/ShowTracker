import Foundation

enum TonightKind: Equatable {
    case airingTonight
    case continueWatching
    case fromWatchlist
}

struct TonightPick: Identifiable {
    var id: String
    let kind: TonightKind
    let title: String
    let subtitle: String
    let posterPath: String?
    let tvId: Int?
    let movieId: Int?
    let tracking: TrackingRecord?

    var cta: String {
        switch kind {
        case .airingTonight: return "Watch tonight"
        case .continueWatching: return "Continue"
        case .fromWatchlist: return "Start here"
        }
    }

    var chip: String {
        switch kind {
        case .airingTonight: return "Tonight"
        case .continueWatching: return "Pick up"
        case .fromWatchlist: return "Queued"
        }
    }
}

struct HomeRecommendation: Identifiable, Hashable {
    var id: String { "\(kind == .movie ? "movie" : "tv")-\(item.id)" }
    let item: MediaItem
    let kind: MediaKind
    let reason: String
}

enum StreamingProviderOption: Int, CaseIterable, Identifiable, Hashable {
    case netflix = 8
    case prime = 119
    case disney = 337
    case max = 1899
    case hulu = 15
    case appleTV = 350
    case paramount = 531

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .netflix: return "Netflix"
        case .prime: return "Prime"
        case .disney: return "Disney+"
        case .max: return "Max"
        case .hulu: return "Hulu"
        case .appleTV: return "Apple TV+"
        case .paramount: return "Paramount+"
        }
    }

    /// TMDB watch-provider logo (stable enough for a curated short list).
    var logoPath: String {
        switch self {
        case .netflix: return "/rK1KljqmbvO9HQa1PBFLILWah72.png"
        case .prime: return "/gMZdpavHmxFNnLpMHwVxfqeux2g.png"
        case .disney: return "/5eZ872CghnHFLB1j8grszbrx0dx.png"
        case .max: return "/skypuy7SXuugIQeYg0IglmzoKaS.png"
        case .hulu: return "/44uAnmSqvA4yBOdbPWN8YgQHjWm.png"
        case .appleTV: return "/v9SnyvYt0U3KGgBH3Sbh3z4yODe.png"
        case .paramount: return "/4N4BMd0Mm0kHAmF7RZgL5lW3cwc.png"
        }
    }

    /// Alternate TMDB ids that map to the same service brand.
    var aliases: Set<Int> {
        switch self {
        // TMDB uses several Amazon / Prime ids by region and storefront.
        case .prime: return [9, 10, 119, 2100, 582]
        case .max: return [1899, 1825, 31]
        case .paramount: return [531, 2303, 2616, 633]
        default: return [rawValue]
        }
    }
}

// MARK: - This week timeline (merged schedule + resume)

enum ThisWeekKind: Equatable {
    case airing
    case returning
    case resume
}

struct ThisWeekItem: Identifiable {
    let id: String
    let kind: ThisWeekKind
    let title: String
    let detail: String
    let dayLabel: String
    let sortKey: String
    let posterPath: String?
    let tvId: Int
    let tracking: TrackingRecord?

    var chip: String {
        switch kind {
        case .airing: return dayLabel
        case .returning: return "Returns"
        case .resume: return "Resume"
        }
    }
}

enum ThisWeekBuilder {
    static func build(
        schedule: [ScheduleEpisode],
        returning: [ScheduleEpisode],
        paused: [TrackingRecord],
        continueIds: Set<Int>
    ) -> [ThisWeekItem] {
        var items: [ThisWeekItem] = []
        var seenShows = Set<Int>()

        for ep in schedule {
            seenShows.insert(ep.tvId)
            items.append(
                ThisWeekItem(
                    id: "air-\(ep.id)",
                    kind: .airing,
                    title: ep.title,
                    detail: "S\(ep.season)E\(ep.episode)\(ep.episodeName.map { " · \($0)" } ?? "")",
                    dayLabel: friendlyDay(ep.airDate),
                    sortKey: ep.airDate,
                    posterPath: ep.posterPath,
                    tvId: ep.tvId,
                    tracking: nil
                )
            )
        }

        for ep in returning where !seenShows.contains(ep.tvId) {
            seenShows.insert(ep.tvId)
            items.append(
                ThisWeekItem(
                    id: "ret-\(ep.id)",
                    kind: .returning,
                    title: ep.title,
                    detail: "S\(ep.season) premiere\(ep.episodeName.map { " · \($0)" } ?? "")",
                    dayLabel: friendlyDay(ep.airDate),
                    sortKey: ep.airDate,
                    posterPath: ep.posterPath,
                    tvId: ep.tvId,
                    tracking: nil
                )
            )
        }

        let today = dayString(Date())
        for track in paused.prefix(8) {
            guard let tvId = Int(track.tvId), !continueIds.contains(tvId), !seenShows.contains(tvId) else {
                continue
            }
            seenShows.insert(tvId)
            let progress = ShowProgress.from(track: track)
            items.append(
                ThisWeekItem(
                    id: "resume-\(track.tvId)",
                    kind: .resume,
                    title: track.tvTitle ?? "Show",
                    detail: progress.episodeLine,
                    dayLabel: "Paused",
                    sortKey: "\(today)-z-\(track.tvId)",
                    posterPath: track.posterPath,
                    tvId: tvId,
                    tracking: track
                )
            )
        }

        return items.sorted { lhs, rhs in
            if lhs.sortKey != rhs.sortKey { return lhs.sortKey < rhs.sortKey }
            return kindRank(lhs.kind) < kindRank(rhs.kind)
        }
    }

    private static func kindRank(_ kind: ThisWeekKind) -> Int {
        switch kind {
        case .airing: return 0
        case .returning: return 1
        case .resume: return 2
        }
    }

    private static func friendlyDay(_ raw: String) -> String {
        let today = dayString(Date())
        if raw == today { return "Today" }
        if let tmr = Calendar.current.date(byAdding: .day, value: 1, to: Date()),
           raw == dayString(tmr) {
            return "Tomorrow"
        }
        let parts = raw.split(separator: "-")
        guard parts.count == 3,
              let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]),
              let date = Calendar.current.date(from: DateComponents(year: y, month: m, day: d))
        else { return raw }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    private static func dayString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}

enum TonightPicker {
    /// One job only: a *different* decision than Continue.
    /// - Airing tonight on a show that isn’t already in the Continue hero
    /// - Or, when Continue is empty, a paused / watchlist nudge
    static func pick(
        continueItems: [TrackingRecord],
        paused: [TrackingRecord],
        schedule: [ScheduleEpisode],
        tvWatchlist: [FavoriteTVDoc],
        filmWatchlist: [FavoriteMovieDoc]
    ) -> TonightPick? {
        let continueIds = Set(continueItems.compactMap { Int($0.tvId) })
        let today = dayString(Date())

        if let airing = schedule.first(where: { $0.airDate == today && !continueIds.contains($0.tvId) }) {
            return TonightPick(
                id: "air-\(airing.id)",
                kind: .airingTonight,
                title: airing.title,
                subtitle: "S\(airing.season)E\(airing.episode)\(airing.episodeName.map { " · \($0)" } ?? "")",
                posterPath: airing.posterPath,
                tvId: airing.tvId,
                movieId: nil,
                tracking: nil
            )
        }

        // Continue hero already owns mid-season shows — don’t mirror it here.
        guard continueItems.isEmpty else { return nil }

        if let pausedShow = paused.first {
            return TonightPick(
                id: "pause-\(pausedShow.tvId)",
                kind: .continueWatching,
                title: pausedShow.tvTitle ?? "Paused show",
                subtitle: "Waiting where you left off",
                posterPath: pausedShow.posterPath,
                tvId: Int(pausedShow.tvId),
                movieId: nil,
                tracking: pausedShow
            )
        }

        if let show = tvWatchlist.first, let id = Int(show.tvId) {
            return TonightPick(
                id: "wl-tv-\(show.tvId)",
                kind: .fromWatchlist,
                title: show.tvTitle ?? "Queued show",
                subtitle: "From your watchlist",
                posterPath: show.posterPath,
                tvId: id,
                movieId: nil,
                tracking: nil
            )
        }

        if let film = filmWatchlist.first, let id = Int(film.movieId) {
            return TonightPick(
                id: "wl-film-\(film.movieId)",
                kind: .fromWatchlist,
                title: film.movieTitle ?? "Queued film",
                subtitle: "From your watchlist",
                posterPath: film.posterPath,
                tvId: nil,
                movieId: id,
                tracking: nil
            )
        }

        return nil
    }

    private static func dayString(_ date: Date) -> String {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }
}
