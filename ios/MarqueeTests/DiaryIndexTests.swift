import XCTest
@testable import Marquee

final class DiaryIndexTests: XCTestCase {
    func testIndexDecodesCompactFilmPairs() throws {
        let json = """
        {"success":true,"films":[["550",3],["27205",1]],"filmWatchlist":["157336"],"loved":{"id":"550","title":"Fight Club"}}
        """
        let index = try JSONDecoder().decode(DiaryIndexResponse.self, from: Data(json.utf8))
        XCTAssertEqual(index.watchCounts, [550: 3, 27205: 1])
        XCTAssertEqual(index.watchlistIds, [157336])
        XCTAssertEqual(index.loved?.id, "550")
        XCTAssertEqual(index.loved?.title, "Fight Club")
    }

    func testEmptyIndexDecodes() throws {
        let json = #"{"success":true,"films":[],"filmWatchlist":[],"loved":null}"#
        let index = try JSONDecoder().decode(DiaryIndexResponse.self, from: Data(json.utf8))
        XCTAssertTrue(index.watchCounts.isEmpty)
        XCTAssertNil(index.loved)
    }
}
