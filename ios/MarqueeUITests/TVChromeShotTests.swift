import XCTest

final class TVChromeShotTests: XCTestCase {
    func testTVScrolledChrome() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MARQUEE_DEBUG_EMAIL"] = "marquee.sim@example.com"
        app.launchEnvironment["MARQUEE_DEBUG_PASSWORD"] = "simtest123"
        app.launch()
        if app.buttons["Start your diary"].waitForExistence(timeout: 8) {
            app.buttons["Start your diary"].tap()
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let tv = app.tabBars.buttons["TV"]
        if tv.waitForExistence(timeout: 4) { tv.tap() } else { app.buttons["TV"].firstMatch.tap() }
        sleep(2)
        shot("tv-top")
        app.swipeUp()
        sleep(1)
        app.swipeUp()
        sleep(1)
        shot("tv-scrolled-chrome")
        app.swipeUp()
        sleep(1)
        shot("tv-scrolled-chrome-2")
    }

    private func shot(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "/tmp/marquee-shots/\(name).png"))
    }
}
