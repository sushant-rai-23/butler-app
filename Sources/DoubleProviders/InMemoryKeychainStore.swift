import Foundation

/// Test double for `KeychainStore`. Holds values in memory for one process.
public final class InMemoryKeychainStore: KeychainStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: String] = [:]

    public init() {}

    public func get(_ key: String) throws -> String? {
        lock.withLock { values[key] }
    }

    public func set(_ value: String, for key: String) throws {
        lock.withLock { values[key] = value }
    }

    public func delete(_ key: String) throws {
        lock.withLock { values[key] = nil }
    }
}
