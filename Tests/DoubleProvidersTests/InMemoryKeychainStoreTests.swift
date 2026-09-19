import XCTest
@testable import DoubleProviders

final class InMemoryKeychainStoreTests: XCTestCase {
    func testSetGetDelete() throws {
        let store: any KeychainStore = InMemoryKeychainStore()
        XCTAssertNil(try store.get("gemini"))
        try store.set("AIza-test", for: "gemini")
        XCTAssertEqual(try store.get("gemini"), "AIza-test")
        try store.set("AIza-rotated", for: "gemini")
        XCTAssertEqual(try store.get("gemini"), "AIza-rotated")
        try store.delete("gemini")
        XCTAssertNil(try store.get("gemini"))
    }
}
