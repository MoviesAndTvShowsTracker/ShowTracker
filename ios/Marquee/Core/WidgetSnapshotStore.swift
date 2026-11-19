import Foundation
import WidgetKit

enum WidgetSnapshotStore {
    /// Prefer App Group `group.com.jimil.marquee` once enabled on the App ID.
    static let suiteName = "group.com.jimil.marquee"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func save(
        continueTitle: String?,
        continuePoster: String?,
        weekFilms: Int?,
        weekEpisodes: Int?,
        weekMins: Int?
    ) {
        defaults.set(continueTitle, forKey: "continueTitle")
        defaults.set(continuePoster, forKey: "continuePoster")
        defaults.set(weekFilms ?? 0, forKey: "weekFilms")
        defaults.set(weekEpisodes ?? 0, forKey: "weekEpisodes")
        defaults.set(weekMins ?? 0, forKey: "weekMins")
        defaults.set(Date().timeIntervalSince1970, forKey: "updatedAt")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
