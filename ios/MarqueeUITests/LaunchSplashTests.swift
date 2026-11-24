import XCTest

/// Cold-launch hand-off: splash continues the static frame, then reveals the app.
final class LaunchSplashTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    override func tearDown() {
        XCUIDevice.shared.appearance = .light
    }

    private func launch(_ args: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-uiTesting"] + args
        app.launch()
        return app
    }

    // XCUIApplication.launch() returns only once the app is idle (~3–4 s), after the
    // splash has been removed — so the first second (static frame → splash → reveal)
    // is verified by the frame-by-frame screen recording, not here.

    func testSplashClearsAfterLaunch() {
        let app = launch()
        XCTAssertTrue(app.otherElements["launch.splash"].waitForNonExistence(timeout: 2))
    }

    func testSignedOutRevealIsInteractive() {
        let app = launch()
        XCTAssertTrue(app.otherElements["launch.splash"].waitForNonExistence(timeout: 2.0))
        XCTAssertTrue(app.buttons.firstMatch.waitForExistence(timeout: 2.0))
        XCTAssertTrue(app.buttons.firstMatch.isHittable)
    }

    func testNoSplashOnWarmResume() {
        let app = launch()
        XCTAssertTrue(app.otherElements["launch.splash"].waitForNonExistence(timeout: 2.0))
        XCUIDevice.shared.press(.home)
        app.activate()
        sleep(1)
        XCTAssertFalse(app.otherElements["launch.splash"].exists)
    }

    func testLaunchInDarkSystemWithLightPreference() {
        XCUIDevice.shared.appearance = .dark
        let app = launch(["-marquee.appearance", "light"])
        // Flipping system appearance right before launch slows the first launch.
        XCTAssertTrue(app.otherElements["launch.splash"].waitForNonExistence(timeout: 3))
        sleep(1)
        // Salt Grey under the ambient blobs reads ~0.79; the dark surface reads ~0.1.
        XCTAssertGreaterThan(edgeLuminance(), 0.6, "revealed app follows the app's Light preference")
    }

    /// Mean luminance of a strip by the status bar — always the app/splash background,
    /// never content cards or the logo.
    private func edgeLuminance() -> CGFloat {
        let image = XCUIScreen.main.screenshot().image
        guard let cg = image.cgImage else { return -1 }
        let w = cg.width, h = cg.height
        let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(),
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        let px = ctx.data!.assumingMemoryBound(to: UInt8.self)
        var total: CGFloat = 0
        var n: CGFloat = 0
        for y in stride(from: h * 2 / 100, to: h * 4 / 100, by: 4) {
            for x in stride(from: w / 12, to: w / 6, by: 4) {
                let i = (y * w + x) * 4
                total += (0.2126 * CGFloat(px[i]) + 0.7152 * CGFloat(px[i + 1]) + 0.0722 * CGFloat(px[i + 2])) / 255
                n += 1
            }
        }
        return total / n
    }
}
