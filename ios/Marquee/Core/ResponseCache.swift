import Foundation

enum ResponseCache {
    private static var defaults: UserDefaults { .standard }

    static func store<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: storageKey(key))
        defaults.set(Date().timeIntervalSince1970, forKey: stampKey(key))
    }

    static func load<T: Decodable>(_ type: T.Type, key: String, maxAge: TimeInterval = 60 * 60 * 24 * 7) -> T? {
        let stamp = defaults.double(forKey: stampKey(key))
        guard stamp > 0, Date().timeIntervalSince1970 - stamp <= maxAge else { return nil }
        guard let data = defaults.data(forKey: storageKey(key)) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    /// Wipes every cached response — on sign-out so the next account never sees them.
    static func clearAll() {
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys where key.hasPrefix("marquee.cache.") {
            defaults.removeObject(forKey: key)
        }
    }

    static func clear(_ key: String) {
        defaults.removeObject(forKey: storageKey(key))
        defaults.removeObject(forKey: stampKey(key))
    }

    private static func storageKey(_ key: String) -> String { "marquee.cache.\(key)" }
    private static func stampKey(_ key: String) -> String { "marquee.cache.stamp.\(key)" }
}
