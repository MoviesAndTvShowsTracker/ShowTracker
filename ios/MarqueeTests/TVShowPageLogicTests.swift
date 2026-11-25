import XCTest
@testable import Marquee

final class TVShowPageLogicTests: XCTestCase {
    let cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    var today: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 25))! }

    private func state(
        _ status: String?,
        rating: Double = 0,
        first: String? = "2024-01-01",
        showStatus: String? = "Returning Series",
        seasons: [Int] = [1, 2]
    ) -> TVHeaderState {
        TVShowPageLogic.headerState(
            status: status, showRating: rating, seasons: seasons,
            firstAirDate: first, showStatus: showStatus, today: today, calendar: cal
        )
    }

    func testNotStartedTargetsFirstSeason() {
        XCTAssertEqual(state(nil), .notStarted(season: 1))
    }

    func testDroppedReadsAsPaused() {
        XCTAssertEqual(state("dropped"), .paused)
    }

    func testTrackedStatesMap() {
        XCTAssertEqual(state("watching"), .watching)
        XCTAssertEqual(state("rewatching"), .rewatching)
        XCTAssertEqual(state("paused"), .paused)
        XCTAssertEqual(state("completed"), .finished(rated: false))
        XCTAssertEqual(state("completed", rating: 4), .finished(rated: true))
    }

    func testPremiereStateForFutureShow() {
        XCTAssertEqual(state(nil, first: "2026-12-03"), .premieres(label: "Premieres Dec 3"))
    }

    func testPremiereTodayCountsAsAired() {
        XCTAssertEqual(state(nil, first: "2026-11-25"), .notStarted(season: 1))
    }

    func testPlannedWithoutDate() {
        XCTAssertEqual(state(nil, first: nil, showStatus: "Planned"), .premieres(label: "Not aired yet"))
    }

    func testStartSkipsSpecials() {
        XCTAssertEqual(TVShowPageLogic.startSeason([0, 1, 2]), 1)
        XCTAssertEqual(state(nil, seasons: [0, 2, 3]), .notStarted(season: 2))
    }

    func testStartFallsBackToOne() {
        XCTAssertEqual(TVShowPageLogic.startSeason([]), 1)
    }

    func testCountLine() {
        XCTAssertEqual(TVShowPageLogic.seasonCountLine(watched: 3, aired: 8, total: 8), "3 of 8 watched")
        XCTAssertEqual(TVShowPageLogic.seasonCountLine(watched: 0, aired: 6, total: 8), "0 of 6 watched · 2 to air")
    }

    func testWholeShowOnlyForMultiSeason() {
        XCTAssertFalse(TVShowPageLogic.offersWholeShow(seasonCount: 1, canMarkWholeShow: true))
        XCTAssertTrue(TVShowPageLogic.offersWholeShow(seasonCount: 2, canMarkWholeShow: true))
        XCTAssertFalse(TVShowPageLogic.offersWholeShow(seasonCount: 3, canMarkWholeShow: false))
    }
}
