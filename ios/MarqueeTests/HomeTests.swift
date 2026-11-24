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
        XCTAssertEqual(HomeFeedLogic.trailing(for: item("1", air: "2026-11-27"), today: today, calendar: cal), .airs("Fri"))
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
        XCTAssertEqual(model.toast?.title, "Logged Show 2 S1E5")

        await model.undoLast()
        XCTAssertEqual(undone, ["2"])
        XCTAssertEqual(model.items.map(\.id), ["1", "2", "3"])
        XCTAssertNil(model.toast)
    }

    func testFallbackOnlyOn404() {
        XCTAssertTrue(HomeService.shouldFallback(APIError.server(message: "x", status: 404)))
        XCTAssertFalse(HomeService.shouldFallback(APIError.server(message: "x", status: 500)))
        XCTAssertFalse(HomeService.shouldFallback(APIError.unauthorized))
    }
}
