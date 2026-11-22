import XCTest

/// Visual polish loop for cinematic film detail. Credentials come from the
/// invoking environment only — never hardcode passwords here.
final class MovieDetailPolishUITests: XCTestCase {
    func testCaptureMovieDetailFold() throws {
        let email = ProcessInfo.processInfo.environment["MARQUEE_DEBUG_EMAIL"] ?? ""
        let password = ProcessInfo.processInfo.environment["MARQUEE_DEBUG_PASSWORD"] ?? ""
        try XCTSkipIf(email.isEmpty || password.isEmpty, "Set MARQUEE_DEBUG_EMAIL / MARQUEE_DEBUG_PASSWORD to run")

        let app = XCUIApplication()
        app.launchArguments = [
            "-previewMovieDetail=1300968",
            "-debugEmail=\(email)",
            "-debugPassword=\(password)"
        ]
        app.launchEnvironment["MARQUEE_DEBUG_EMAIL"] = email
        app.launchEnvironment["MARQUEE_DEBUG_PASSWORD"] = password
        app.launch()

        // Dismiss push prompt if it appears.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Don’t Allow", "Don't Allow", "Allow"] {
            let button = springboard.alerts.buttons[label]
            if button.waitForExistence(timeout: 2) {
                if label.hasPrefix("Allow") { continue }
                button.tap()
                break
            }
        }

        // Wait for hero title from live TMDB payload.
        let title = app.staticTexts["The Hunger Games: Sunrise on the Reaping"]
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        sleep(2)

        let top = XCTAttachment(screenshot: app.screenshot())
        top.name = "movie-detail-top"
        top.lifetime = .keepAlways
        add(top)

        app.swipeUp()
        sleep(1)
        app.swipeUp()
        sleep(1)

        let mid = XCTAttachment(screenshot: app.screenshot())
        mid.name = "movie-detail-scrolled"
        mid.lifetime = .keepAlways
        add(mid)
    }
}
