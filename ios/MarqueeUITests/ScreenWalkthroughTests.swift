import XCTest

final class ScreenWalkthroughTests: XCTestCase {
    func testWalkMainScreens() throws {
        let app = XCUIApplication()
        // Override with TEST_RUNNER_WALK_EMAIL / TEST_RUNNER_WALK_PASSWORD to walk a real account.
        let env = ProcessInfo.processInfo.environment
        app.launchEnvironment["MARQUEE_DEBUG_EMAIL"] = env["WALK_EMAIL"] ?? "marquee.sim@example.com"
        app.launchEnvironment["MARQUEE_DEBUG_PASSWORD"] = env["WALK_PASSWORD"] ?? "simtest123"
        if let api = env["WALK_API"] { app.launchArguments += ["-apiBaseURL", api] }
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
        openPersonFilmography(app, prefix: "05c")
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
            let posters = app.descendants(matching: .any).matching(identifier: "posterTile")
            if posters.element(boundBy: 0).waitForExistence(timeout: 6) {
                posters.element(boundBy: 0).tap()
                sleep(3)
                shot("11-search-show-detail")
                swipeBack(app)
            } else if app.staticTexts["Severance"].waitForExistence(timeout: 2) {
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

    private func openPersonFilmography(_ app: XCUIApplication, prefix: String) {
        // Prefer cast rail, then director/credit chips.
        let cast = app.descendants(matching: .any).matching(identifier: "castMember")
        let chips = app.descendants(matching: .any).matching(identifier: "personChip")
        let target: XCUIElement?
        if cast.count > 0, cast.element(boundBy: 0).waitForExistence(timeout: 3) {
            target = cast.element(boundBy: 0)
        } else if chips.count > 0, chips.element(boundBy: 0).waitForExistence(timeout: 2) {
            target = chips.element(boundBy: 0)
        } else {
            // Scroll for cast if still offscreen.
            for _ in 0..<4 {
                app.swipeUp()
                sleep(1)
                if cast.count > 0 {
                    break
                }
            }
            target = cast.count > 0 ? cast.element(boundBy: 0)
                : (chips.count > 0 ? chips.element(boundBy: 0) : nil)
        }
        guard let person = target, person.waitForExistence(timeout: 4) else { return }
        person.tap()
        sleep(3)
        shot("\(prefix)-person")
        let personRoot = app.otherElements["personView"]
        _ = personRoot.waitForExistence(timeout: 6)
        // Switch segment if segmented control exists.
        let segmented = app.segmentedControls.firstMatch
        if segmented.waitForExistence(timeout: 2), segmented.buttons.count > 1 {
            segmented.buttons.element(boundBy: 1).tap()
            sleep(1)
            shot("\(prefix)-person-segment")
        }
        app.swipeUp()
        sleep(1)
        shot("\(prefix)-person-scrolled")
        swipeBack(app)
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
