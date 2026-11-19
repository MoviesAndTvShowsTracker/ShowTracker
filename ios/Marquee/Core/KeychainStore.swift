import Foundation
import Security

enum KeychainStore {
    private static let service = "com.jimil.marquee"
    private static let legacyService = "com.marquee.app"

    static func set(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
    }

    static func string(forKey key: String) -> String? {
        if let value = read(service: service, key: key) {
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
