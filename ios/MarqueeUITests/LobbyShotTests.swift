import XCTest

final class LobbyShotTests: XCTestCase {
    func testLobbyChrome() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MARQUEE_DEBUG_EMAIL"] = "marquee.sim@example.com"
        app.launchEnvironment["MARQUEE_DEBUG_PASSWORD"] = "simtest123"
        app.launch()

        if app.buttons["Start your diary"].waitForExistence(timeout: 10) {
            app.buttons["Start your diary"].tap()
        }
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        let home = app.tabBars.buttons["Home"]
        if home.waitForExistence(timeout: 3) { home.tap() }
        sleep(3)
        shot("lobby-top")
        app.swipeUp()
        sleep(1)
        shot("lobby-scrolled")
        app.swipeUp()
        sleep(1)
        shot("lobby-scrolled-2")
    }

    private func shot(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        try? data.write(to: URL(fileURLWithPath: "/tmp/marquee-shots/\(name).png"))
    }
}
