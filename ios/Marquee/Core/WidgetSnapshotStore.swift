import Foundation
import WidgetKit

enum WidgetSnapshotStore {
    static let suiteName = "group.com.jimil.marquee"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: suiteName) ?? .standard
    }

    static func save(
        continueTitle: String?,
        continueSubtitle: String? = nil,
        continuePoster: String?,
        weekFilms: Int?,
        weekEpisodes: Int?,
        weekMins: Int?,
        weekStreak: Int? = nil
    ) {
        defaults.set(continueTitle, forKey: "continueTitle")
        defaults.set(continueSubtitle, forKey: "continueSubtitle")
        defaults.set(continuePoster, forKey: "continuePoster")
        defaults.set(weekFilms ?? 0, forKey: "weekFilms")
        defaults.set(weekEpisodes ?? 0, forKey: "weekEpisodes")
        defaults.set(weekMins ?? 0, forKey: "weekMins")
        defaults.set(weekStreak ?? 0, forKey: "weekStreak")
        defaults.set(Date().timeIntervalSince1970, forKey: "updatedAt")
        WidgetCenter.shared.reloadAllTimelines()
    }
}
