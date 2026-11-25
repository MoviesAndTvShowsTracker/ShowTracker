import Foundation
import os

/// When each screen last loaded from the server, so tab switches reuse fresh data instead of
/// refetching. Any successful write (POST/DELETE) marks every screen stale.
final class Freshness: Sendable {
    static let shared = Freshness()

    private let loadedAt = OSAllocatedUnfairLock(initialState: [String: Date]())

    func isStale(_ key: String, window: TimeInterval = 60, now: Date = .now) -> Bool {
        guard let at = loadedAt.withLock({ $0[key] }) else { return true }
        return now.timeIntervalSince(at) >= window
    }

    func markLoaded(_ key: String, now: Date = .now) {
        loadedAt.withLock { $0[key] = now }
    }

    func invalidate(_ key: String) {
        _ = loadedAt.withLock { $0.removeValue(forKey: key) }
    }

    func invalidateAll() {
        loadedAt.withLock { $0.removeAll() }
    }

    /// Writes change what screens show; reads don't. Some older endpoints read with POST.
    static func invalidates(method: String, path: String) -> Bool {
        if method.uppercased() == "GET" { return false }
        if readOnlyPosts.contains(path) { return false }
        let last = path.split(separator: "/").last.map(String.init) ?? ""
        return !last.hasPrefix("get")
    }

    private static let readOnlyPosts: Set<String> = [
        "/api/favorite/favorited", "/api/tv/favorite/favorited",
        "/api/watchlist/watchlisted", "/api/tv/watchlist/watchlisted",
        "/api/watch/watched", "/api/devices/register",
    ]
}
