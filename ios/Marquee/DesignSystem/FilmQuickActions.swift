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
                let options = QuickActionMenu.film(
                    loaded: index.isLoaded,
                    watchCount: index.watchCounts[item.id] ?? 0,
                    onWatchlist: index.watchlist.contains(item.id)
                )
                ForEach(options, id: \.self) { option in
                    switch option {
                    case .markWatched, .logAgain:
                        Button {
                            run("Couldn't log that film. Try again.") { try await index.markWatched(item) }
                        } label: {
                            Label(option == .logAgain ? "Log again today" : "Mark watched", systemImage: "checkmark.circle")
                        }
                    case .addToWatchlist, .removeFromWatchlist:
                        Button {
                            run("Couldn't update your watchlist. Try again.") { try await index.toggleWatchlist(item) }
                        } label: {
                            Label(option == .removeFromWatchlist ? "Remove from watchlist" : "Add to watchlist",
                                  systemImage: option == .removeFromWatchlist ? "bookmark.slash" : "bookmark")
                        }
                    case .share:
                        if let url = URL(string: "https://www.themoviedb.org/movie/\(item.id)") {
                            ShareLink(item: url, subject: Text(item.displayTitle)) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
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
                let options = QuickActionMenu.show(
                    loaded: index.isLoaded,
                    tracked: index.seen.contains(item.id),
                    onWatchlist: index.watchlist.contains(item.id)
                )
                ForEach(options, id: \.self) { option in
                    switch option {
                    case .addToWatchlist, .removeFromWatchlist:
                        Button {
                            Task { @MainActor in
                                do { try await index.toggleWatchlist(item); Haptics.success() } catch {
                                    Feedback.failed("Couldn't update your watchlist. Try again.")
                                }
                            }
                        } label: {
                            Label(option == .removeFromWatchlist ? "Remove from watchlist" : "Add to watchlist",
                                  systemImage: option == .removeFromWatchlist ? "bookmark.slash" : "bookmark")
                        }
                    case .share:
                        if let url = URL(string: "https://www.themoviedb.org/tv/\(item.id)") {
                            ShareLink(item: url, subject: Text(item.displayTitle)) {
                                Label("Share", systemImage: "square.and.arrow.up")
                            }
                        }
                    case .markWatched, .logAgain:
                        EmptyView()
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

    /// The same long-press actions for diary rows (You tab rails and lists).
    @ViewBuilder
    func diaryQuickActions(id: String, title: String, posterPath: String?, kind: MediaKind) -> some View {
        if let item = MediaItem.diary(id: id, title: title, posterPath: posterPath, kind: kind) {
            catalogQuickActions(item, kind: kind)
        } else {
            self
        }
    }
}
