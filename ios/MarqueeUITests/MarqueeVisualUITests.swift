import XCTest

final class MarqueeVisualUITests: XCTestCase {
    func testCaptureHomeAndCalendar() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTesting"]
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Don’t Allow"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        } else {
            let dont = springboard.alerts.buttons["Don't Allow"]
            if dont.waitForExistence(timeout: 1) { dont.tap() }
        }

        XCTAssertTrue(app.staticTexts["Continue"].waitForExistence(timeout: 5))
        let homeShot = app.screenshot()
        let homeAttach = XCTAttachment(screenshot: homeShot)
        homeAttach.name = "home-continue"
        homeAttach.lifetime = .keepAlways
        add(homeAttach)

        // Swipe carousel
        let card = app.descendants(matching: .any)["Continue watching"].firstMatch
        if card.exists {
            card.swipeLeft()
            sleep(1)
            let page2 = app.screenshot()
            let a2 = XCTAttachment(screenshot: page2)
            a2.name = "home-continue-page2"
            a2.lifetime = .keepAlways
            add(a2)
        }

        let calendar = app.buttons["Watch calendar"].firstMatch
        if !calendar.exists {
            app.swipeUp()
        }
        let link = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS[c] %@", "Watch calendar")).firstMatch
        if link.waitForExistence(timeout: 3) {
            link.tap()
        } else {
            app.otherElements["Watch calendar"].tap()
        }

        XCTAssertTrue(app.navigationBars["Watch calendar"].waitForExistence(timeout: 5)
            || app.staticTexts["Watch calendar"].waitForExistence(timeout: 2))
        // Allow poster fetches to settle before capture.
        sleep(3)
        let calShot = app.screenshot()
        let calAttach = XCTAttachment(screenshot: calShot)
        calAttach.name = "watch-calendar"
        calAttach.lifetime = .keepAlways
        add(calAttach)
    }
}
