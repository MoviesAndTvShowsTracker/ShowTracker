import XCTest

/// Screenshot walk of the You tab glance and the full Stats page.
/// Shots land in /tmp/marquee-shots/stats-*.png.
final class StatsShotTests: XCTestCase {
    func testStatsPage() throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15))
        app.tabBars.buttons["You"].tap()

        let entry = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Screen time")).firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 20))
        sleep(1)
        shot("stats-profile")
        entry.tap()

        XCTAssertTrue(app.buttons["Week"].waitForExistence(timeout: 30))
        sleep(2)
        shot("stats-00-top")

        app.buttons["Year"].tap()
        sleep(1)
        shot("stats-01-year")

        for i in 2...12 {
            app.swipeUp()
            sleep(1)
            shot(String(format: "stats-%02d", i))
        }
    }

    private func shot(_ name: String) {
        try? FileManager.default.createDirectory(atPath: "/tmp/marquee-shots", withIntermediateDirectories: true)
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "/tmp/marquee-shots/\(name).png"))
    }
}
