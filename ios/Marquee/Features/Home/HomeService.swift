import Foundation

/// Loads everything Home shows: one `/api/home` call, or the separate calls on older servers.
enum HomeService {
    static let cacheKey = "home.landing.v2"

    static func load() async throws -> HomeFeed {
        do {
            return try await loadFromServer()
        } catch where shouldFallback(error) {
            return try await loadAggregated()
        }
    }

    static func shouldFallback(_ error: Error) -> Bool {
        if case APIError.server(_, let status) = error { return status == 404 }
        return false
    }

    static func loadFromServer() async throws -> HomeFeed {
        let res: HomeAPIResponse = try await APIClient.shared.get("/api/home")
        return res.feed
    }

    static func loadAggregated() async throws -> HomeFeed {
        async let c = DiaryService.continueWatching()
        async let pausedTask = DiaryService.library(tab: "stopped")
        async let finishedTask = DiaryService.library(tab: "finished")
        async let f = DiaryService.movieWatchlist()
        async let t = DiaryService.tvWatchlist()
        async let r = DiaryService.weekRecap()
        async let a = DiaryService.activity(limit: 10)

        let cont = try await c
        let films = try await f
        let shows = try await t
        let paused = (try? await pausedTask) ?? []
        let finished = (try? await finishedTask) ?? []
        let recap = try? await r
        let recent = (try? await a) ?? []

        async let upcomingTask = HomeScheduleBuilder.upcoming(from: cont + paused, withinDays: 7)
        async let returningTask = HomeScheduleBuilder.returningSoon(from: paused + finished, withinDays: 30)
        let upcoming = await upcomingTask
        let airingIds = Set(upcoming.map(\.tvId))
        let returning = await returningTask.filter { !airingIds.contains($0.tvId) }

        let agenda = upcoming.map { agendaEpisode($0, kind: "airing") }
            + returning.map { agendaEpisode($0, kind: "returning") }

        let upNext = cont.map { track in
            UpNextItem(
                track: track,
                nextAirDate: upcoming.first {
                    String($0.tvId) == track.tvId && $0.season == track.nextSeason && $0.episode == track.nextEpisode
                }?.airDate
            )
        }

        return HomeFeed(
            upNext: upNext,
            pausedCount: paused.count,
            thisWeek: agenda.sorted { $0.airDate < $1.airDate },
            recent: recent,
            recap: recap,
            films: films,
            tv: shows
        )
    }

    static func cached() -> HomeFeed? { ResponseCache.load(HomeFeed.self, key: cacheKey) }
    static func store(_ feed: HomeFeed) { ResponseCache.store(feed, key: cacheKey) }
    static func clearCache() { ResponseCache.clear(cacheKey) }

    private static func agendaEpisode(_ ep: ScheduleEpisode, kind: String) -> AgendaEpisode {
        AgendaEpisode(
            tvId: ep.tvId, title: ep.title, posterPath: ep.posterPath,
            season: ep.season, episode: ep.episode, episodeName: ep.episodeName,
            airDate: ep.airDate, kind: kind
        )
    }
}

struct HomeAPIResponse: Decodable, Sendable {
    struct Watchlist: Decodable, Sendable {
        let films: [FavoriteMovieDoc]?
        let tv: [FavoriteTVDoc]?
    }

    let success: Bool?
    let upNext: [UpNextItem]?
    let pausedCount: Int?
    let thisWeek: [AgendaEpisode]?
    let recent: [DiaryActivityItem]?
    let recap: WeekRecap?
    let watchlist: Watchlist?

    var feed: HomeFeed {
        HomeFeed(
            upNext: upNext ?? [],
            pausedCount: pausedCount ?? 0,
            thisWeek: thisWeek ?? [],
            recent: recent ?? [],
            recap: recap,
            films: watchlist?.films ?? [],
            tv: watchlist?.tv ?? []
        )
    }
}
