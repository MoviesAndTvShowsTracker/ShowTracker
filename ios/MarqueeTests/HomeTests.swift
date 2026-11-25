import XCTest
@testable import Marquee

@MainActor
final class HomeTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/New_York")!
        return c
    }()
    private var today: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 24, hour: 12))! }

    private func item(_ id: String, air: String? = nil, status: String = "watching") -> UpNextItem {
        UpNextItem(track: TrackingRecord(tvId: id, status: status, tvTitle: "Show \(id)", nextSeason: 1, nextEpisode: 5), nextAirDate: air)
    }

    private func body(_ id: String) -> MarkEpisodeBody {
        MarkEpisodeBody(tvId: id, seasonNumber: 1, episodeNumber: 5, runtimeMinutes: nil, episodeName: nil,
                        tvTitle: nil, tvPosterImage: nil, nextSeason: 1, nextEpisode: 6)
    }

    func testTrailing() {
        XCTAssertEqual(HomeFeedLogic.trailing(for: item("1"), today: today, calendar: cal), .mark)
        XCTAssertEqual(HomeFeedLogic.trailing(for: item("1", air: "2026-11-24"), today: today, calendar: cal), .mark)
        XCTAssertEqual(HomeFeedLogic.trailing(for: item("1", air: "2026-11-25"), today: today, calendar: cal), .airs("Tomorrow"))
        XCTAssertEqual(HomeFeedLogic.trailing(for: item("1", air: "2026-11-27"), today: today, calendar: cal), .airs("In 3 days"))
        XCTAssertEqual(HomeFeedLogic.trailing(for: item("1", status: "rewatching"), today: today, calendar: cal), .chevron)
    }

    func testAgendaRows() {
        func ep(_ id: Int, _ day: String, _ kind: String = "airing") -> AgendaEpisode {
            AgendaEpisode(tvId: id, title: "T", posterPath: nil, season: 1, episode: id, episodeName: nil, airDate: day, kind: kind)
        }
        let rows = HomeFeedLogic.agendaRows(
            [ep(1, "2026-11-26"), ep(2, "2026-11-24"), ep(3, "2026-11-24"), ep(4, "2026-12-05"), ep(5, "2026-12-10", "returning"), ep(6, "2026-11-20")],
            today: today, calendar: cal
        )
        XCTAssertEqual(rows.map(\.episode.tvId), [2, 3, 1, 5])
        XCTAssertEqual(rows.map(\.dayLabel), ["Tonight", nil, "Thu 26", "Dec 10"])
    }

    func testSecondMarkWhileInFlightIsIgnoredAndUndoRestores() async {
        var calls = 0
        var undone: [String] = []
        let model = UpNextModel(
            items: [item("1"), item("2"), item("3")],
            mark: { track in
                calls += 1
                try await Task.sleep(for: .milliseconds(50))
                return .init(body: self.body(track.tvId), updated: TrackingRecord(tvId: track.tvId, status: "completed"))
            },
            undo: { undone.append($0.tvId) }
        )
        async let a: Void = model.mark(model.items[1])
        async let b: Void = model.mark(model.items[1])
        _ = await (a, b)
        XCTAssertEqual(calls, 1)
        XCTAssertEqual(model.items.map(\.id), ["1", "3"])
        XCTAssertEqual(model.toast?.title, "Finished Show 2.")
        XCTAssertEqual(model.toast?.finished, true)

        await model.undoLast()
        XCTAssertEqual(undone, ["2"])
        XCTAssertEqual(model.items.map(\.id), ["1", "2", "3"])
        XCTAssertNil(model.toast)
    }

    func testRowAdvancesBeforeServerAndRollsBackOnFailure() async {
        var seenDuringMark: Int?
        var model: UpNextModel!
        model = UpNextModel(
            items: [item("1")],
            mark: { _ in
                seenDuringMark = model.items[0].track.nextEpisode
                throw APIError.empty
            },
            undo: { _ in },
            preview: { EpisodeMarker.advanced($0, watched: EpisodePointer(season: 1, episode: 5), next: EpisodePointer(season: 1, episode: 6)) }
        )
        await model.mark(model.items[0])
        XCTAssertEqual(seenDuringMark, 6)
        XCTAssertEqual(model.items[0].track.nextEpisode, 5)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertNil(model.toast)
    }

    func testNoInventedNextEpisode() {
        // Watched the finale; the server says nothing is next. Never "S1E9" or "S2E1".
        let done = TrackingRecord(tvId: "1", status: "watching", lastSeason: 1, lastEpisode: 8, watchedEpisodeCount: 8)
        XCTAssertNil(ShowProgress.from(track: done).next)
        let counted = TrackingRecord(tvId: "1", status: "watching", watchedEpisodeCount: 3)
        XCTAssertNil(ShowProgress.from(track: counted).next)
        // A new show still starts at S1E1.
        let fresh = TrackingRecord(tvId: "1", status: "watching")
        XCTAssertEqual(ShowProgress.from(track: fresh).next, EpisodePointer(season: 1, episode: 1))
    }

    func testCaughtUpOnAiringSeasonIsNotFinished() {
        // Dexter: 14 aired and watched, 20 listed, S2E5 airs in 5 days.
        let track = TrackingRecord(tvId: "1", status: "watching", nextSeason: 2, nextEpisode: 5,
                                   lastSeason: 2, lastEpisode: 4, watchedEpisodeCount: 14,
                                   totalEpisodes: 20, airedEpisodeCount: 14)
        let progress = ShowProgress.from(track: track)
        XCTAssertFalse(progress.isComplete)
        XCTAssertEqual(progress.next, EpisodePointer(season: 2, episode: 5))
        XCTAssertEqual(HomeFeedLogic.progressCaption(progress), "14 of 20")
        let item = UpNextItem(track: track, nextAirDate: "2026-11-29")
        XCTAssertEqual(HomeFeedLogic.trailing(for: item, today: today, calendar: cal), .airs("In 5 days"))
        let far = UpNextItem(track: track, nextAirDate: "2026-12-10")
        XCTAssertEqual(HomeFeedLogic.trailing(for: far, today: today, calendar: cal), .airs("Dec 10"))
    }

    func testNoMarkButtonWithoutNextEpisode() {
        let caughtUp = UpNextItem(track: TrackingRecord(tvId: "1", status: "watching", lastSeason: 1, lastEpisode: 8, watchedEpisodeCount: 8), nextAirDate: nil)
        XCTAssertEqual(HomeFeedLogic.trailing(for: caughtUp, today: today, calendar: cal), .chevron)
    }

    func testLaterInSeasonNeverCrossesSeasons() {
        func ep(_ n: Int) -> TVEpisode {
            TVEpisode(id: n, name: "E\(n)", overview: nil, still_path: nil, episode_number: n, season_number: 1, runtime: nil, air_date: nil)
        }
        let season = [ep(1), ep(2), ep(3)]
        XCTAssertEqual(EpisodeMarker.laterInSeason(after: EpisodePointer(season: 1, episode: 2), seasonEpisodes: season),
                       EpisodePointer(season: 1, episode: 3, name: "E3"))
        XCTAssertNil(EpisodeMarker.laterInSeason(after: EpisodePointer(season: 1, episode: 3), seasonEpisodes: season))
        XCTAssertNil(EpisodeMarker.laterInSeason(after: EpisodePointer(season: 2, episode: 1), seasonEpisodes: nil))
    }

    func testFallbackOnlyOn404() {
        XCTAssertTrue(HomeService.shouldFallback(APIError.server(message: "x", status: 404)))
        XCTAssertFalse(HomeService.shouldFallback(APIError.server(message: "x", status: 500)))
        XCTAssertFalse(HomeService.shouldFallback(APIError.unauthorized))
    }
}
