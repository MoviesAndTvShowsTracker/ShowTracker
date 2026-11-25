import XCTest
@testable import Marquee

final class WatchDayTests: XCTestCase {
    private var cal: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "America/Toronto")!
        return c
    }()
    /// Wed Nov 25, 2026, 9:30 pm in Toronto.
    private var now: Date { cal.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 21, minute: 30))! }

    func testTodayIsNow() {
        XCTAssertEqual(WatchDay.today.date(now: now, calendar: cal), now)
    }

    func testYesterdayKeepsTheTimeOfDay() {
        let d = WatchDay.yesterday.date(now: now, calendar: cal)
        XCTAssertEqual(cal.dateComponents([.year, .month, .day, .hour, .minute], from: d),
                       DateComponents(year: 2026, month: 11, day: 24, hour: 21, minute: 30))
    }

    func testPickedDayUsesTheTimeOfDayAndNeverTheFuture() {
        let picked = cal.date(from: DateComponents(year: 2024, month: 2, day: 14, hour: 3))!
        let d = WatchDay.custom(picked).date(now: now, calendar: cal)
        XCTAssertEqual(cal.dateComponents([.year, .month, .day, .hour, .minute], from: d),
                       DateComponents(year: 2024, month: 2, day: 14, hour: 21, minute: 30))
        let future = cal.date(byAdding: .day, value: 3, to: now)!
        XCTAssertEqual(WatchDay.custom(future).date(now: now, calendar: cal), now, "clamped to now")
    }

    func testMovingALogToAnotherDayKeepsItsTimeOfDay() {
        let original = cal.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 9, minute: 5))!
        let picked = cal.date(from: DateComponents(year: 2026, month: 11, day: 20))!
        let moved = WatchDay.custom(picked).date(now: now, calendar: cal, timeOf: original)
        XCTAssertEqual(cal.dateComponents([.day, .hour, .minute], from: moved), DateComponents(day: 20, hour: 9, minute: 5))
        let yesterday = WatchDay.yesterday.date(now: now, calendar: cal, timeOf: original)
        XCTAssertEqual(cal.dateComponents([.day, .hour, .minute], from: yesterday), DateComponents(day: 24, hour: 9, minute: 5))
    }

    func testAnExistingDateSelectsTheRightPill() {
        XCTAssertEqual(WatchDay.from(now.addingTimeInterval(-3600), now: now, calendar: cal), .today)
        XCTAssertEqual(WatchDay.from(cal.date(byAdding: .day, value: -1, to: now)!, now: now, calendar: cal), .yesterday)
        let old = cal.date(from: DateComponents(year: 2024, month: 2, day: 14, hour: 20))!
        XCTAssertEqual(WatchDay.from(old, now: now, calendar: cal), .custom(old))
    }

    func testLabels() {
        XCTAssertEqual(WatchDay.today.label(now: now, calendar: cal), "Today")
        XCTAssertEqual(WatchDay.yesterday.label(now: now, calendar: cal), "Yesterday")
        let sameYear = cal.date(from: DateComponents(year: 2026, month: 3, day: 7))!
        XCTAssertEqual(WatchDay.custom(sameYear).label(now: now, calendar: cal), "Sat, Mar 7")
        let lastYear = cal.date(from: DateComponents(year: 2024, month: 2, day: 14))!
        XCTAssertEqual(WatchDay.custom(lastYear).label(now: now, calendar: cal), "Feb 14, 2024")
    }

    func testNoteLimit() {
        XCTAssertEqual(DiaryNote.limit, 500)
        XCTAssertEqual(DiaryNote.clamped(String(repeating: "a", count: 520)).count, 500)
        XCTAssertNil(DiaryNote.counter(for: String(repeating: "a", count: 399)), "quiet until close to the limit")
        XCTAssertEqual(DiaryNote.counter(for: String(repeating: "a", count: 430)), "430/500")
        XCTAssertEqual(DiaryNote.trimmed("  With Mom.\n "), "With Mom.")
    }
}
