import XCTest

/// Screenshots of the film diary: Your watches, the edit sheet and the Watched long-press menu.
/// Needs a local API with a seeded account: MARQUEE_SHOT_EMAIL / MARQUEE_SHOT_PASSWORD / MARQUEE_SHOT_API.
final class DiaryLogShotTests: XCTestCase {
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFilmDiary() throws {
        let env = ProcessInfo.processInfo.environment
        guard let email = env["MARQUEE_SHOT_EMAIL"], let password = env["MARQUEE_SHOT_PASSWORD"] else {
            throw XCTSkip("No seeded account")
        }
        let app = XCUIApplication()
        app.launchArguments = [
            "-debugEmail=\(email)", "-debugPassword=\(password)",
            "-apiBaseURL", env["MARQUEE_SHOT_API"] ?? "http://localhost:5055",
            "-previewMovieDetail=27205",
            "-marquee.appearance", env["MARQUEE_SHOT_APPEARANCE"] ?? "light",
        ]
        app.launch()

        let firstWatch = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'First watch'")).firstMatch
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10))
        for _ in 0..<4 where !firstWatch.isHittable {
            app.swipeUp(velocity: .slow)
        }
        sleep(1)
        shot(app, "1-your-watches")

        firstWatch.tap()
        sleep(2)
        shot(app, "2-edit-sheet")
        app.buttons["Cancel"].tap()
        sleep(1)

        for _ in 0..<5 { app.swipeDown(velocity: .fast) }
        let watched = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Watched'")).firstMatch
        if watched.waitForExistence(timeout: 5) {
            watched.press(forDuration: 0.8)
            sleep(1)
            shot(app, "3-watched-menu")
        }
    }
}

extension DiaryLogShotTests {
    func testShowDiary() throws {
        let env = ProcessInfo.processInfo.environment
        guard let email = env["MARQUEE_SHOT_EMAIL"], let password = env["MARQUEE_SHOT_PASSWORD"] else {
            throw XCTSkip("No seeded account")
        }
        let app = XCUIApplication()
        app.launchArguments = [
            "-debugEmail=\(email)", "-debugPassword=\(password)",
            "-apiBaseURL", env["MARQUEE_SHOT_API"] ?? "http://localhost:5055",
            "-previewTVDetail=1396",
        ]
        app.launch()
        let pilot = app.buttons.matching(NSPredicate(format: "label CONTAINS 'Pilot'")).firstMatch
        for _ in 0..<8 where !pilot.isHittable { app.swipeUp(velocity: .slow) }
        sleep(1)
        let attach = { (name: String) in
            let a = XCTAttachment(screenshot: app.screenshot()); a.name = name; a.lifetime = .keepAlways; self.add(a)
        }
        attach("4-episodes")
        let third = app.buttons.matching(NSPredicate(format: "label CONTAINS 'E3 ·'")).firstMatch
        if third.waitForExistence(timeout: 5) {
            third.press(forDuration: 0.8)
            sleep(1)
            attach("5-episode-menu")
        }
    }
}
