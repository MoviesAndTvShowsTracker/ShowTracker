import Foundation

/// What a poster's long-press menu offers, from what the diary knows about the title.
enum QuickActionMenu: Equatable {
    case markWatched
    case logAgain
    case addToWatchlist
    case removeFromWatchlist
    case share

    /// Until the diary has loaded, only actions that can't be wrong.
    static func film(loaded: Bool, watchCount: Int, onWatchlist: Bool) -> [QuickActionMenu] {
        guard loaded else { return [.share] }
        var items: [QuickActionMenu] = [watchCount > 0 ? .logAgain : .markWatched]
        if onWatchlist {
            items.append(.removeFromWatchlist)
        } else if watchCount == 0 {
            // A watched film never goes back on the watchlist.
            items.append(.addToWatchlist)
        }
        return items + [.share]
    }

    /// Shows you're tracking (watching, paused, finished) don't belong on the watchlist.
    static func show(loaded: Bool, tracked: Bool, onWatchlist: Bool) -> [QuickActionMenu] {
        guard loaded else { return [.share] }
        if onWatchlist { return [.removeFromWatchlist, .share] }
        return tracked ? [.share] : [.addToWatchlist, .share]
    }
}
