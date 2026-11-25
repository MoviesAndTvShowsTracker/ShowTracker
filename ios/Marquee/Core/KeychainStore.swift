import Foundation
import Security

enum KeychainStore {
    private static let service = "com.jimil.marquee"
    private static let legacyService = "com.marquee.app"
    /// Readable after the first unlock (background refresh still works), never copied to
    /// backups or another device.
    private static let accessible = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String

    static func set(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        // Update in place first: never delete a token before its replacement is stored.
        let changes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: accessible,
        ]
        let status = SecItemUpdate(query as CFDictionary, changes as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add.merge(changes) { _, new in new }
            SecItemAdd(add as CFDictionary, nil)
        }
    }

    static func string(forKey key: String) -> String? {
        if let value = read(service: service, key: key) {
            // Items saved before this setting existed are re-saved with it once.
            if accessibility(forKey: key) != accessible { set(value, forKey: key) }
            return value
        }
        // One-time migrate from the old service name.
        guard let legacy = read(service: legacyService, key: key) else { return nil }
        set(legacy, forKey: key)
        remove(key, service: legacyService)
        return legacy
    }

    static func remove(_ key: String) {
        remove(key, service: service)
        remove(key, service: legacyService)
    }

    /// The stored item's accessibility class, or nil when there's no item.
    static func accessibility(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnAttributes as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let attrs = item as? [String: Any] else { return nil }
        return attrs[kSecAttrAccessible as String] as? String
    }

    private static func read(service: String, key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func remove(_ key: String, service: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
