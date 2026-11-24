import Foundation

/// When the launch splash hands off to the app.
/// Shown at least `minimum` so the reveal never flickers, never longer than
/// `maximum` so a slow session restore can't hold the app hostage.
enum LaunchTiming {
    static let minimum: TimeInterval = 0.6
    static let maximum: TimeInterval = 1.5

    /// Seconds to wait before revealing, or `nil` to keep waiting for the restore.
    static func revealDelay(elapsed: TimeInterval, restored: Bool) -> TimeInterval? {
        if elapsed >= maximum { return 0 }
        guard restored else { return nil }
        return max(0, minimum - elapsed)
    }
}
