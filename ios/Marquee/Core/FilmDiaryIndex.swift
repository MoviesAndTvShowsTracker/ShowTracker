import Foundation
import Observation

/// What the user has watched or queued, so catalogue posters can show badges
/// and long-press actions without opening the film page.
@MainActor
@Observable
final class FilmDiaryIndex {
    static let shared = FilmDiaryIndex()

    private(set) var watchCounts: [Int: Int] = [:]
    private(set) var watchlist: Set<Int> = []
    /// Most recent film rated 4+ (out of 5), for "Because you loved".
    private(set) var loved: (id: Int, title: String)?

    @ObservationIgnored private var loadedAt: Date?

    func mark(_ id: Int) -> DiaryStatusMark? {
        if let times = watchCounts[id] { return .watched(times: times) }
        return watchlist.contains(id) ? .watchlist : nil
    }

    /// Refreshes at most every 2 minutes unless forced.
    func refresh(force: Bool = false) async {
        if UITestingFixtures.isEnabled { return }
        if !force, let loadedAt, Date().timeIntervalSince(loadedAt) < 120 { return }
        async let watchedTask = DiaryService.watchedMovies()
        async let listTask = DiaryService.movieWatchlist()
        if let watched = try? await watchedTask {
            watchCounts = Dictionary(
                watched.compactMap { doc in Int(doc.movieId).map { ($0, max(1, doc.watchCount ?? 1)) } },
                uniquingKeysWith: { a, _ in a }
            )
            loved = watched
                .filter { Self.stars($0.rating) >= 4 }
                .max { ($0.watchedAt ?? "") < ($1.watchedAt ?? "") }
                .flatMap { doc in Int(doc.movieId).map { ($0, doc.movieTitle ?? "a film") } }
        }
        if let list = try? await listTask {
            watchlist = Set(list.compactMap { Int($0.movieId) })
        }
        loadedAt = Date()
    }

    func toggleWatchlist(_ item: MediaItem) async throws {
        let id = item.id
        if watchlist.contains(id) {
            watchlist.remove(id)
            do { try await DiaryService.removeMovieWatchlist(id: String(id)) } catch { watchlist.insert(id); throw error }
        } else {
            watchlist.insert(id)
            do { try await DiaryService.addMovieWatchlist(body(item, runtime: nil)) } catch { watchlist.remove(id); throw error }
        }
        HomeService.clearCache()
    }

    func markWatched(_ item: MediaItem) async throws {
        let runtime = (try? await TMDBService.movieDetail(id: item.id))?.runtime
        let previous = watchCounts[item.id]
        watchCounts[item.id] = (previous ?? 0) + 1
        do {
            try await DiaryService.addMovieWatched(body(item, runtime: runtime))
        } catch {
            watchCounts[item.id] = previous
            throw error
        }
        HomeService.clearCache()
    }

    private func body(_ item: MediaItem, runtime: Int?) -> MovieIdBody {
        MovieIdBody(
            movieId: String(item.id),
            movieTitle: item.displayTitle,
            moviePosterImage: item.poster_path,
            movieRuntime: runtime.map(String.init)
        )
    }

    /// Ratings are out of 5; older 10-point values are halved.
    static func stars(_ rating: Double?) -> Double {
        guard let rating, rating > 0 else { return 0 }
        return rating > 5 ? rating / 2 : rating
    }
}
