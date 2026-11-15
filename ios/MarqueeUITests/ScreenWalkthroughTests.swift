import XCTest

final class ScreenWalkthroughTests: XCTestCase {
    func testWalkMainScreens() throws {
        let app = XCUIApplication()
        app.launchEnvironment["MARQUEE_DEBUG_EMAIL"] = "marquee.sim@example.com"
        app.launchEnvironment["MARQUEE_DEBUG_PASSWORD"] = "simtest123"
        app.launch()

        if app.buttons["Start your diary"].waitForExistence(timeout: 12) {
            shot("02-welcome")
            app.buttons["Start your diary"].tap()
        }

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        sleep(2)
        shot("03-home")

        tapTab(app, "Films")
        sleep(2)
        shot("04-films")
        tapFirstPoster(app)
        sleep(2)
        shot("05-film-detail")
        app.swipeUp()
        sleep(1)
        shot("05b-film-detail-scrolled")
        swipeBack(app)

        tapTab(app, "TV")
        sleep(2)
        shot("06-tv")

        tapFirstPoster(app)
        sleep(3)
        shot("07-tv-detail")
        app.swipeUp()
        sleep(1)
        shot("08-tv-detail-scrolled")
        swipeBack(app)

        tapTab(app, "Search")
        sleep(1)
        shot("09-search")
        let search = app.searchFields.firstMatch
        if search.waitForExistence(timeout: 4) {
            search.tap()
            search.typeText("severance")
            sleep(2)
            shot("10-search-results")
            if app.staticTexts["Severance"].waitForExistence(timeout: 6) {
                app.staticTexts["Severance"].firstMatch.tap()
                sleep(3)
                shot("11-search-show-detail")
                swipeBack(app)
            }
        }

        tapTab(app, "You")
        sleep(1)
        shot("12-you")
    }

    private func tapFirstPoster(_ app: XCUIApplication) {
        let posters = app.descendants(matching: .any).matching(identifier: "posterTile")
        if posters.element(boundBy: 0).waitForExistence(timeout: 4) {
            posters.element(boundBy: 0).tap()
            return
        }
        let cells = app.buttons.allElementsBoundByIndex
        for button in cells.prefix(16) {
            let label = button.label
            if label.isEmpty { continue }
            if ["Home", "Films", "TV", "Search", "You", "Back", "Your TV library"].contains(label) { continue }
            if label.contains("Watching") { continue }
            if button.isHittable {
                button.tap()
                return
            }
        }
    }

    private func tapTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.tabBars.buttons[name]
        if tab.waitForExistence(timeout: 4) {
            tab.tap()
        } else {
            app.buttons[name].firstMatch.tap()
        }
    }

    private func swipeBack(_ app: XCUIApplication) {
        let back = app.buttons["Back"]
        if back.waitForExistence(timeout: 2), back.isHittable {
            back.tap()
        } else {
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.02, dy: 0.45))
            let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.45))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        sleep(1)
    }

    private func shot(_ name: String) {
        let data = XCUIScreen.main.screenshot().pngRepresentation
        let url = URL(fileURLWithPath: "/tmp/marquee-shots/\(name).png")
        try? data.write(to: url)
    }
}
