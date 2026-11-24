import XCTest
@testable import Marquee

final class LaunchTimingTests: XCTestCase {
    func testWaitsForMinimumWhenRestoredEarly() throws {
        let delay = try XCTUnwrap(LaunchTiming.revealDelay(elapsed: 0.2, restored: true))
        XCTAssertEqual(delay, 0.4, accuracy: 0.001)
    }

    func testRevealsImmediatelyAfterMinimum() {
        XCTAssertEqual(LaunchTiming.revealDelay(elapsed: 0.9, restored: true), 0)
    }

    func testKeepsWaitingWhileRestoring() {
        XCTAssertNil(LaunchTiming.revealDelay(elapsed: 0.9, restored: false))
    }

    func testRevealCapsAtMaximum() {
        XCTAssertEqual(LaunchTiming.revealDelay(elapsed: 1.5, restored: false), 0)
        XCTAssertEqual(LaunchTiming.revealDelay(elapsed: 3, restored: false), 0)
    }
}
