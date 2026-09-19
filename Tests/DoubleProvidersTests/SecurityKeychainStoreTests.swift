import XCTest
@testable import DoubleProviders

final class SecurityKeychainStoreTests: XCTestCase {
    func testSetGetDeleteOnTheLoginKeychain() throws {
        let store = SecurityKeychainStore(service: "com.double.app.tests")
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
