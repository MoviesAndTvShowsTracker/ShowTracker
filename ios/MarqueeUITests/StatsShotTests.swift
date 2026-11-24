import XCTest

/// Screenshot walk of the Stats page: every range, then the all-time tail.
/// Shots land in /tmp/marquee-shots/stats-*.png.
final class StatsShotTests: XCTestCase {
    func testStatsRanges() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons["You"].tap()

        let entry = app.staticTexts["Open diary"]
        for _ in 0..<4 where !entry.isHittable {
            app.swipeUp()
        }
        XCTAssertTrue(entry.waitForExistence(timeout: 10))
        entry.tap()

        XCTAssertTrue(app.buttons["Week"].waitForExistence(timeout: 30))
        sleep(2)
        shot("stats-open")

        for range in ["Week", "Month", "Year", "All"] {
            app.buttons[range].tap()
            sleep(2)
            shot("stats-\(range.lowercased())-top")
            app.swipeUp()
            sleep(1)
            shot("stats-\(range.lowercased())-mid")
            app.swipeDown()
            app.swipeDown()
        }

        for i in 1...5 {
            app.swipeUp()
            sleep(1)
            shot("stats-tail-\(i)")
        }
    }

    private func shot(_ name: String) {
        try? FileManager.default.createDirectory(atPath: "/tmp/marquee-shots", withIntermediateDirectories: true)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "/tmp/marquee-shots/\(name).png"))
    }
}
