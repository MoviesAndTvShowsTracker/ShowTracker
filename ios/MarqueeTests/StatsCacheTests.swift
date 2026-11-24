import XCTest
@testable import Marquee

final class StatsCacheTests: XCTestCase {
    private let json = """
    {"overview":{"totalMins":1200,"tvMins":900,"filmMins":300,"episodeCount":20,"filmCount":2,"tvShowCount":3},
     "ranges":{"week":{"key":"week","totals":{"totalMins":90},"topShows":[{"tvId":1396,"tvTitle":"Breaking Bad","plays":4}]}},
     "seasonArcs":[{"tvId":"1668","tvTitle":"Friends"}]}
    """

    func testDashboardStatsSurvivesEncodeDecode() throws {
        let original = try JSONDecoder().decode(DashboardStats.self, from: Data(json.utf8))
        let restored = try JSONDecoder().decode(DashboardStats.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(restored.overview?.totalMins, 1200)
        XCTAssertEqual(restored.ranges?.week?.totals?.totalMins, 90)
        XCTAssertEqual(restored.ranges?.week?.topShows?.first?.tvId, .int(1396))
        XCTAssertEqual(restored.seasonArcs?.first?.tvId, .string("1668"))
    }
}
