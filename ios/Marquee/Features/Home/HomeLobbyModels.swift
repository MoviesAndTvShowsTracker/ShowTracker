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

    /// Alternate TMDB ids that map to the same service brand.
    var aliases: Set<Int> {
        switch self {
        case .prime: return [9, 119, 10]
        case .max: return [1899, 1825, 31]
        default: return [rawValue]
        }
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
