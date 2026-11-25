import XCTest
@testable import Marquee

final class EpisodePlaysTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    func testFirstMarkRecordsOnePlayDatedNow() {
        let (counts, dates) = EpisodePlays.afterFirstWatch(counts: [:], dates: [:], key: "1-3", at: now)
        XCTAssertEqual(counts["1-3"], 1)
        XCTAssertEqual(dates["1-3"], ["2027-01-15T08:00:00.000Z"], "same shape as the server's toISOString()")
    }

    func testOtherEpisodesAreUntouched() {
        let (counts, dates) = EpisodePlays.afterFirstWatch(
            counts: ["1-1": 2], dates: ["1-1": ["2026-01-01T00:00:00Z"]], key: "1-3", at: now
        )
        XCTAssertEqual(counts["1-1"], 2)
        XCTAssertEqual(dates["1-1"], ["2026-01-01T00:00:00Z"])
    }

    func testAlreadyCountedEpisodeKeepsItsCount() {
        let (counts, _) = EpisodePlays.afterFirstWatch(counts: ["1-3": 2], dates: [:], key: "1-3", at: now)
        XCTAssertEqual(counts["1-3"], 2)
    }
}
