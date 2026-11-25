import XCTest
@testable import Marquee

/// Scores are shown as plain text: a source name, a figure and its scale. No third-party logos.
final class RatingsChipTests: XCTestCase {
    private func ratings(_ json: String) throws -> MediaRatings {
        try JSONDecoder().decode(MediaRatings.self, from: Data(json.utf8))
    }

    func testEachScoreHasAPlainNameAndScale() throws {
        let r = try ratings(#"{"id":550,"tmdb":{"value":8.4,"scale":10},"imdb":{"value":8.8,"scale":10},"metacritic":{"value":67,"scale":100}}"#)
        XCTAssertEqual(r.chips.map(\.source.label), ["IMDb", "Metacritic", "TMDB"])
        XCTAssertEqual(r.chips.map(\.display), ["8.8", "67", "8.4"])
        XCTAssertEqual(r.chips.map(\.scaleText), ["/10", "/100", "/10"])
    }

    func testPercentScoresCarryNoExtraScale() throws {
        let r = try ratings(#"{"id":1,"rottenTomatoes":{"value":81,"scale":100}}"#)
        XCTAssertEqual(r.chips.first?.source.label, "Rotten Tomatoes")
        XCTAssertEqual(r.chips.first?.display, "81%")
        XCTAssertEqual(r.chips.first?.scaleText, "")
    }

    func testNoScoresNoChips() throws {
        XCTAssertTrue(try ratings(#"{"id":1}"#).chips.isEmpty)
    }
}
