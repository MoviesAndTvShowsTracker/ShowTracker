import XCTest
@testable import Marquee

/// Long-press menus follow what the diary knows about the title.
final class QuickActionMenuTests: XCTestCase {
    func testUnknownStateOffersOnlySafeActions() {
        XCTAssertEqual(QuickActionMenu.film(loaded: false, watchCount: 0, onWatchlist: false), [.share])
        XCTAssertEqual(QuickActionMenu.show(loaded: false, tracked: false, onWatchlist: false), [.share])
    }

    func testUnwatchedFilm() {
        XCTAssertEqual(QuickActionMenu.film(loaded: true, watchCount: 0, onWatchlist: false),
                       [.markWatched, .addToWatchlist, .share])
        XCTAssertEqual(QuickActionMenu.film(loaded: true, watchCount: 0, onWatchlist: true),
                       [.markWatched, .removeFromWatchlist, .share])
    }

    func testWatchedFilmNeverOffersTheWatchlist() {
        XCTAssertEqual(QuickActionMenu.film(loaded: true, watchCount: 2, onWatchlist: false),
                       [.logAgain, .share])
        // A stale watchlist row on a watched film can still be cleared.
        XCTAssertEqual(QuickActionMenu.film(loaded: true, watchCount: 1, onWatchlist: true),
                       [.logAgain, .removeFromWatchlist, .share])
    }

    func testTrackedShowsSkipTheWatchlist() {
        XCTAssertEqual(QuickActionMenu.show(loaded: true, tracked: true, onWatchlist: false), [.share])
        XCTAssertEqual(QuickActionMenu.show(loaded: true, tracked: false, onWatchlist: false), [.addToWatchlist, .share])
        XCTAssertEqual(QuickActionMenu.show(loaded: true, tracked: false, onWatchlist: true), [.removeFromWatchlist, .share])
    }
}
