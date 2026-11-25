import XCTest
@testable import Marquee

/// App Store Connect rejects uploads whose required-reason API use isn't declared.
final class PrivacyManifestTests: XCTestCase {
    func testAppShipsAManifestDeclaringUserDefaultsAndNoTracking() throws {
        let url = try XCTUnwrap(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"), "manifest is in the app bundle")
        let plist = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: Any])
        XCTAssertEqual(plist["NSPrivacyTracking"] as? Bool, false)
        let apis = try XCTUnwrap(plist["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let defaults = try XCTUnwrap(apis.first { $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults" })
        let reasons = try XCTUnwrap(defaults["NSPrivacyAccessedAPITypeReasons"] as? [String])
        XCTAssertTrue(reasons.contains("CA92.1"), "app's own settings")
        XCTAssertTrue(reasons.contains("1C8F.1"), "App Group shared with the widget")
    }

    func testWidgetShipsItsOwnManifest() throws {
        let plugins = try XCTUnwrap(Bundle.main.builtInPlugInsURL)
        let widget = plugins.appendingPathComponent("MarqueeWidgets.appex")
        let bundle = try XCTUnwrap(Bundle(url: widget))
        XCTAssertNotNil(bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    }
}
