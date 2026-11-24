import Foundation
import Observation

/// Shows the user has watched or queued, for catalogue badges and long-press actions.
@MainActor
@Observable
final class TVDiaryIndex {
    static let shared = TVDiaryIndex()

    private(set) var seen: Set<Int> = []
    private(set) var watchlist: Set<Int> = []
    /// Most recently finished show rated 4+ (out of 5), for "Because you loved".
    private(set) var loved: (id: Int, title: String)?

    @ObservationIgnored private var loadedAt: Date?

    func mark(_ id: Int) -> DiaryStatusMark? {
        if seen.contains(id) { return .watched }
        return watchlist.contains(id) ? .watchlist : nil
    }

    func refresh(force: Bool = false) async {
        if UITestingFixtures.isEnabled { return }
        if !force, let loadedAt, Date().timeIntervalSince(loadedAt) < 120 { return }
        async let watchedTask = DiaryService.watchedTV()
        async let listTask = DiaryService.tvWatchlist()
        async let finishedTask = DiaryService.library(tab: "finished")
        if let watched = try? await watchedTask {
            seen = Set(watched.compactMap { Int($0.tvId) })
        }
        if let list = try? await listTask {
            watchlist = Set(list.compactMap { Int($0.tvId) })
        }
        if let finished = try? await finishedTask {
            seen.formUnion(finished.compactMap { Int($0.tvId) })
            loved = finished
                .first { FilmDiaryIndex.stars($0.rating) >= 4 }
                .flatMap { t in Int(t.tvId).map { ($0, t.tvTitle ?? "a show") } }
        }
        loadedAt = Date()
    }

    func toggleWatchlist(_ item: MediaItem) async throws {
        let id = item.id
        if watchlist.contains(id) {
            watchlist.remove(id)
            do { try await DiaryService.removeTVWatchlist(id: String(id)) } catch { watchlist.insert(id); throw error }
        } else {
            watchlist.insert(id)
            do {
                try await DiaryService.addTVWatchlist(
                    TVIdBody(tvId: String(id), tvTitle: item.displayTitle, tvPosterImage: item.poster_path)
                )
            } catch { watchlist.remove(id); throw error }
        }
        HomeService.clearCache()
    }
}
