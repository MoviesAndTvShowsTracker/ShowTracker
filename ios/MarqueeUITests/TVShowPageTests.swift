import XCTest

/// The show page's first-run path: Start lands on S1 · E1 without logging anything.
final class TVShowPageTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }

    func testStartLandsOnFirstEpisode() {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting", "-previewTVDetail=1396"]
        app.launch()

        let start = app.buttons["Start with S1 · E1"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        attach(app, "1-untracked")
        start.tap()

        let pilot = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'E1 ·'")).firstMatch
        XCTAssertTrue(pilot.waitForExistence(timeout: 10))
        XCTAssertTrue(pilot.isHittable, "Start should scroll E1 into view")
        XCTAssertTrue(app.buttons["Not watched"].firstMatch.exists, "Start must not mark anything")
        attach(app, "2-after-start")

        sleep(2)
        attach(app, "3-flash-faded")

        pilot.tap()
        sleep(1)
        attach(app, "4-row-tap")
    }
}
