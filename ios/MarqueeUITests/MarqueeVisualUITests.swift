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

        XCTAssertTrue(app.descendants(matching: .any)["home-upnext"].firstMatch.waitForExistence(timeout: 5))
        let homeAttach = XCTAttachment(screenshot: app.screenshot())
        homeAttach.name = "home-upnext"
        homeAttach.lifetime = .keepAlways
        add(homeAttach)

        let calendar = app.buttons["watch-calendar-link"].firstMatch
        for _ in 0..<4 where !calendar.isHittable { app.swipeUp() }
        calendar.tap()

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
