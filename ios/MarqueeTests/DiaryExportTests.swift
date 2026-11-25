import XCTest
@testable import Marquee

final class DiaryExportTests: XCTestCase {
    func testFileNamesCarryTheDateAndFormat() {
        let day = Calendar(identifier: .gregorian).date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 12))!
        XCTAssertEqual(DiaryExportFormat.csv.fileName(on: day), "marquee-diary-2026-11-25.csv")
        XCTAssertEqual(DiaryExportFormat.json.fileName(on: day), "marquee-diary-2026-11-25.json")
        XCTAssertEqual(DiaryExportFormat.csv.query, "csv")
    }

    func testSizesReadNaturally() {
        XCTAssertEqual(DiaryExportFormat.sizeText(bytes: 900), "900 bytes")
        XCTAssertEqual(DiaryExportFormat.sizeText(bytes: 42_000), "42 KB")
    }
}
