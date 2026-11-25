import XCTest
@testable import Marquee

final class EpisodeOrderTests: XCTestCase {
    private func ep(_ s: Int, _ e: Int, aired: Bool = true) -> TVEpisode {
        TVEpisode(id: s * 100 + e, name: "S\(s)E\(e)", overview: nil, still_path: nil, episode_number: e,
                  season_number: s, runtime: nil, air_date: aired ? "2020-01-01" : "2099-01-01")
    }

    func testEverythingBeforeAndIncludingTheTargetThatIsntWatched() {
        let catalog = [ep(0, 1), ep(1, 1), ep(1, 2), ep(1, 3), ep(2, 1), ep(2, 2), ep(2, 3)]
        let watched: Set<String> = ["1-2"]
        let targets = EpisodeOrder.upTo(season: 2, episode: 2, catalog: catalog, watched: watched)
        XCTAssertEqual(targets.map(\.diaryKey), ["1-1", "1-3", "2-1", "2-2"], "in order, skipping watched, specials and later episodes")
    }

    func testUnairedEpisodesAreNeverMarked() {
        let catalog = [ep(1, 1), ep(1, 2, aired: false), ep(1, 3, aired: false)]
        XCTAssertEqual(EpisodeOrder.upTo(season: 1, episode: 3, catalog: catalog, watched: []).map(\.diaryKey), ["1-1"])
    }

    func testASpecialOnlyMarksSpecialsUpToIt() {
        let catalog = [ep(0, 1), ep(0, 2), ep(1, 1)]
        XCTAssertEqual(EpisodeOrder.upTo(season: 0, episode: 2, catalog: catalog, watched: []).map(\.diaryKey), ["0-1", "0-2"])
    }
}
