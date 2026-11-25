import XCTest
@testable import Marquee

final class ProfileEditTests: XCTestCase {
    func testPasswordNeededOnlyWhenTheEmailReallyChanges() {
        XCTAssertFalse(ProfileEdit.needsPassword(original: "jimil@example.com", edited: "jimil@example.com"))
        XCTAssertFalse(ProfileEdit.needsPassword(original: "jimil@example.com", edited: "  Jimil@Example.com "), "case and spaces aren't a change")
        XCTAssertTrue(ProfileEdit.needsPassword(original: "jimil@example.com", edited: "new@example.com"))
    }
}
