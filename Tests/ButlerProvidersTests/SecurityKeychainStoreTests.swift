import XCTest
@testable import ButlerProviders

final class SecurityKeychainStoreTests: XCTestCase {
    /// Opt-in: touches the developer's login keychain. Run with
    /// `BUTLER_KEYCHAIN_TESTS=1 swift test --filter SecurityKeychainStoreTests`.
    func testSetGetDeleteOnTheLoginKeychain() throws {
        guard ProcessInfo.processInfo.environment["BUTLER_KEYCHAIN_TESTS"] == "1" else {
            throw XCTSkip("Set BUTLER_KEYCHAIN_TESTS=1 to run against the login keychain")
        }
        let store = SecurityKeychainStore(service: "com.butler.app.tests")
        let account = "test-\(UUID().uuidString)"
        do {
            try store.set("secret-1", for: account)
        } catch KeychainError.unexpectedStatus(let status) where status == errSecMissingEntitlement || status == errSecInteractionNotAllowed {
            throw XCTSkip("Keychain unavailable in this environment (\(status))")
        }
        defer { try? store.delete(account) }
        XCTAssertEqual(try store.get(account), "secret-1")
        try store.set("secret-2", for: account)
        XCTAssertEqual(try store.get(account), "secret-2")
        try store.delete(account)
        XCTAssertNil(try store.get(account))
        XCTAssertNoThrow(try store.delete(account), "deleting a missing item is not an error")
    }
}
