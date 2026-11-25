import XCTest
@testable import Marquee

final class EpisodeRatingsSummaryTests: XCTestCase {
    // Stored ratings are 1–10 (half-stars doubled).
    private let summary = EpisodeRatingsSummary(
        ratings: ["1-1": 6, "1-2": 10, "1-3": 7, "2-1": 9, "2-2": 0],
        names: ["1-2": "Cat's in the Bag", "2-1": "Seven Thirty-Seven"]
    )

    func testSeasonAverageInStarsIgnoresUnrated() {
        XCTAssertEqual(summary.average(season: 1)!, 23.0 / 6.0, accuracy: 0.001)
        XCTAssertEqual(summary.average(season: 2)!, 4.5, accuracy: 0.001)
        XCTAssertNil(summary.average(season: 3))
    }

    func testBestEpisodesHighestFirstThenEarliest() {
        let best = summary.best(limit: 3)
        XCTAssertEqual(best.map(\.key), ["1-2", "2-1", "1-3"])
        XCTAssertEqual(best.first?.stars, 5)
        XCTAssertEqual(best.first?.name, "Cat's in the Bag")
        XCTAssertEqual(best.first?.label, "S1 · E2")
    }

    func testOnlyShownWithEnoughRatings() {
        XCTAssertTrue(summary.hasBest)
        XCTAssertFalse(EpisodeRatingsSummary(ratings: ["1-1": 8, "1-2": 9], names: [:]).hasBest)
    }
}
