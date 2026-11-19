import SwiftUI

@MainActor
@Observable
final class AppPreferences {
    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }

        var title: String {
            switch self {
            case .system: return "System"
            case .light: return "Day"
            case .dark: return "Night"
            }
        }

        var symbol: String {
            switch self {
            case .system: return "circle.lefthalf.filled"
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            }
        }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light: return .light
            case .dark: return .dark
            }
        }
    }

    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) }
    }

    var blobsEnabled: Bool {
        didSet { defaults.set(blobsEnabled, forKey: Keys.blobs) }
    }

    var hapticsEnabled: Bool {
        didSet { defaults.set(hapticsEnabled, forKey: Keys.haptics) }
    }

    var heroAutoplay: Bool {
        didSet { defaults.set(heroAutoplay, forKey: Keys.autoplay) }
    }

    var gridDensity: GridDensity {
        didSet { defaults.set(gridDensity.rawValue, forKey: Keys.grid) }
    }

    var episodeAlertsEnabled: Bool {
        didSet { defaults.set(episodeAlertsEnabled, forKey: Keys.episodeAlerts) }
    }

    /// TMDB watch-provider ids the user cares about (empty = any service).
    var preferredProviderIds: Set<Int> {
        didSet { defaults.set(Array(preferredProviderIds), forKey: Keys.providers) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let appearanceRaw = defaults.string(forKey: Keys.appearance) ?? Appearance.system.rawValue
        appearance = Appearance(rawValue: appearanceRaw) ?? .system
        blobsEnabled = defaults.object(forKey: Keys.blobs) as? Bool ?? true
        hapticsEnabled = defaults.object(forKey: Keys.haptics) as? Bool ?? true
        heroAutoplay = defaults.object(forKey: Keys.autoplay) as? Bool ?? true
        let densityRaw = defaults.object(forKey: Keys.grid) as? Int ?? GridDensity.cozy.rawValue
        gridDensity = GridDensity(rawValue: densityRaw) ?? .cozy
        episodeAlertsEnabled = defaults.object(forKey: Keys.episodeAlerts) as? Bool ?? false
        let storedProviders = defaults.array(forKey: Keys.providers) as? [Int] ?? []
        preferredProviderIds = Set(storedProviders)
    }

    func clearSearchHistory() {
        defaults.removeObject(forKey: "recentSearches")
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let appearance = "marquee.appearance"
        static let blobs = "marquee.blobs"
        static let haptics = "marquee.haptics"
        static let autoplay = "marquee.heroAutoplay"
        static let grid = "marquee.gridDensity"
        static let episodeAlerts = "marquee.episodeAlerts"
        static let providers = "marquee.preferredProviders"
    }
}
