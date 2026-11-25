import XCTest
import Security
@testable import Marquee

final class KeychainStoreTests: XCTestCase {
    private let key = "test.keychain.accessibility"

    override func tearDown() { KeychainStore.remove(key) }

    func testNewItemsStayOnThisDeviceAfterFirstUnlock() {
        KeychainStore.set("secret", forKey: key)
        XCTAssertEqual(KeychainStore.string(forKey: key), "secret")
        XCTAssertEqual(KeychainStore.accessibility(forKey: key), kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    func testSavingAgainReplacesTheValueInPlace() {
        KeychainStore.set("first", forKey: key)
        KeychainStore.set("second", forKey: key)
        XCTAssertEqual(KeychainStore.string(forKey: key), "second")
        XCTAssertEqual(KeychainStore.accessibility(forKey: key), kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    func testOlderItemsAreMigratedWhenRead() {
        // An item saved the old way (default accessibility, which can travel in backups).
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: "com.jimil.marquee",
            kSecAttrAccount as String: key,
            kSecValueData as String: Data("old".utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlocked,
        ]
        SecItemDelete(query as CFDictionary)
        XCTAssertEqual(SecItemAdd(query as CFDictionary, nil), errSecSuccess)

        XCTAssertEqual(KeychainStore.string(forKey: key), "old")
        XCTAssertEqual(KeychainStore.accessibility(forKey: key), kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }
}
