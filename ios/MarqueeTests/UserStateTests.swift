import XCTest
@testable import Marquee

/// The /api/me responses decode into what the detail pages need.
final class UserStateTests: XCTestCase {
    func testTVStateDecodes() throws {
        let json = """
        {"success":true,"favorited":true,"watchlisted":false,
         "tracking":{"tvId":"85271","status":"completed","watchedEpisodeCount":9,"totalEpisodes":9},
         "episodes":[{"_id":"a","tvId":"85271","seasonNumber":1,"episodeNumber":1,"rating":4,"watchedAt":"2026-11-25T03:00:00.000Z"}],
         "rewatch":{"tracking":null,"activeSession":null,"playCounts":{"1-1":1},"playDates":{"1-1":["2026-11-25T03:00:00.000Z"]},"rewatchPlayTotal":0}}
        """
        let state = try JSONDecoder().decode(TVUserState.self, from: Data(json.utf8))
        XCTAssertEqual(state.favorited, true)
        XCTAssertEqual(state.watchlisted, false)
        XCTAssertEqual(state.tracking?.status, "completed")
        XCTAssertEqual(state.episodes?.first?.episodeNumber, 1)
        XCTAssertEqual(state.rewatch?.playCounts?["1-1"], 1)
    }

    func testMovieStateDecodes() throws {
        let json = """
        {"success":true,"favorited":false,"watchlisted":true,
         "watched":{"watched":true,"watchCount":2,"watchedAt":"2026-11-20T00:00:00.000Z","rating":4.5,"isRewatch":true,"latestPlayId":"p"}}
        """
        let state = try JSONDecoder().decode(MovieUserState.self, from: Data(json.utf8))
        XCTAssertEqual(state.watchlisted, true)
        XCTAssertEqual(state.watched?.watchCount, 2)
        XCTAssertEqual(state.watched?.rating, 4.5)
    }
}
