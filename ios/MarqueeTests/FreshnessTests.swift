import XCTest
@testable import Marquee

final class FreshnessTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func testNeverLoadedIsStale() {
        let f = Freshness()
        XCTAssertTrue(f.isStale("home", now: t0))
    }

    func testFreshWithinWindowThenStale() {
        let f = Freshness()
        f.markLoaded("home", now: t0)
        XCTAssertFalse(f.isStale("home", window: 60, now: t0.addingTimeInterval(59)))
        XCTAssertTrue(f.isStale("home", window: 60, now: t0.addingTimeInterval(60)))
    }

    func testKeysAreIndependent() {
        let f = Freshness()
        f.markLoaded("home", now: t0)
        XCTAssertTrue(f.isStale("you", now: t0))
    }

    func testAnyChangeMakesEveryScreenStale() {
        let f = Freshness()
        f.markLoaded("home", now: t0)
        f.markLoaded("you", now: t0)
        f.invalidateAll()
        XCTAssertTrue(f.isStale("home", now: t0))
        XCTAssertTrue(f.isStale("you", now: t0))
    }

    func testOnlyWritesMakeScreensStale() {
        XCTAssertFalse(Freshness.invalidates(method: "GET", path: "/api/home"))
        XCTAssertTrue(Freshness.invalidates(method: "POST", path: "/api/tv/episodes/mark"))
        XCTAssertTrue(Freshness.invalidates(method: "POST", path: "/api/watchlist/addToWatchlist"))
        XCTAssertTrue(Freshness.invalidates(method: "DELETE", path: "/users/me"))
        // This API reads some lists with POST; those don't change anything.
        XCTAssertFalse(Freshness.invalidates(method: "POST", path: "/api/watch/getWatchMovie"))
        XCTAssertFalse(Freshness.invalidates(method: "POST", path: "/api/tv/watchlist/getTvWatchlist"))
        XCTAssertFalse(Freshness.invalidates(method: "POST", path: "/api/favorite/favorited"))
        XCTAssertFalse(Freshness.invalidates(method: "POST", path: "/api/tv/watchlist/watchlisted"))
        XCTAssertFalse(Freshness.invalidates(method: "POST", path: "/api/watch/watched"))
        XCTAssertFalse(Freshness.invalidates(method: "POST", path: "/api/devices/register"))
    }
}
