import SwiftUI

/// Diary badge + long-press actions for any film poster in the catalogue.
struct FilmQuickActions: ViewModifier {
    let item: MediaItem
    private var index: FilmDiaryIndex { .shared }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if let mark = index.mark(item.id) {
                    DiaryStatusBadge(mark: mark, compact: true)
                        .padding(6)
                        .allowsHitTesting(false)
                }
            }
            .contextMenu {
                let queued = index.watchlist.contains(item.id)
                Button {
                    run(queued ? "Couldn't update your watchlist. Try again." : "Couldn't add to your watchlist. Try again.") {
                        try await index.toggleWatchlist(item)
                    }
                } label: {
                    Label(queued ? "Remove from watchlist" : "Add to watchlist",
                          systemImage: queued ? "bookmark.slash" : "bookmark")
                }
                Button {
                    run("Couldn't log that film. Try again.") { try await index.markWatched(item) }
                } label: {
                    Label(index.watchCounts[item.id] == nil ? "Mark watched" : "Log again", systemImage: "checkmark.circle")
                }
                if let url = URL(string: "https://www.themoviedb.org/movie/\(item.id)") {
                    ShareLink(item: url, subject: Text(item.displayTitle)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
    }

    private func run(_ failure: String, _ action: @escaping @MainActor () async throws -> Void) {
        Task { @MainActor in
            do {
                try await action()
                Haptics.success()
            } catch {
                Feedback.failed(failure)
            }
        }
    }
}

/// Diary badge + long-press watchlist/share for any show poster.
struct TVQuickActions: ViewModifier {
    let item: MediaItem
    private var index: TVDiaryIndex { .shared }

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .topTrailing) {
                if let mark = index.mark(item.id) {
                    DiaryStatusBadge(mark: mark, compact: true)
                        .padding(6)
                        .allowsHitTesting(false)
                }
            }
            .contextMenu {
                let queued = index.watchlist.contains(item.id)
                Button {
                    Task { @MainActor in
                        do { try await index.toggleWatchlist(item); Haptics.success() } catch {
                            Feedback.failed("Couldn't update your watchlist. Try again.")
                        }
                    }
                } label: {
                    Label(queued ? "Remove from watchlist" : "Add to watchlist",
                          systemImage: queued ? "bookmark.slash" : "bookmark")
                }
                if let url = URL(string: "https://www.themoviedb.org/tv/\(item.id)") {
                    ShareLink(item: url, subject: Text(item.displayTitle)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
    }
}

extension View {
    /// Diary badge and long-press actions for catalogue posters.
    @ViewBuilder
    func catalogQuickActions(_ item: MediaItem, kind: MediaKind) -> some View {
        if kind == .movie { modifier(FilmQuickActions(item: item)) } else { modifier(TVQuickActions(item: item)) }
    }
}
