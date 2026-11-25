import XCTest
@testable import Marquee

final class FilmPlayTests: XCTestCase {
    func testServerDatesParseWithAndWithoutMilliseconds() {
        XCTAssertNotNil(ISODate.parse("2024-02-14T20:00:00.000Z"))
        XCTAssertNotNil(ISODate.parse("2024-02-14T20:00:00Z"))
        XCTAssertNil(ISODate.parse("yesterday"))
        XCTAssertNil(ISODate.parse(nil))
        XCTAssertEqual(ISODate.string(ISODate.parse("2024-02-14T20:00:00.000Z")!), "2024-02-14T20:00:00.000Z")
    }

    func testPlaysDecodeWithStarsOutOfFive() throws {
        let json = #"[{"id":"a","watchedAt":"2024-02-14T20:00:00.000Z","note":"With Mom","rating":9,"isRewatch":false},{"id":"b","watchedAt":null,"note":"","rating":null,"isRewatch":true}]"#
        let plays = try JSONDecoder().decode([FilmPlay].self, from: Data(json.utf8))
        XCTAssertEqual(plays[0].stars, 4.5)
        XCTAssertEqual(plays[0].noteText, "With Mom")
        XCTAssertNotNil(plays[0].date)
        XCTAssertEqual(plays[1].stars, 0)
        XCTAssertNil(plays[1].noteText, "empty notes read as none")
        XCTAssertTrue(plays[1].isRewatch == true)
    }
}
