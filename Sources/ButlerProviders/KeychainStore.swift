import Foundation

/// Where API keys live.
///
/// Every read of a secret goes through this protocol so tests can inject
/// `InMemoryKeychainStore`. The Security-framework implementation arrives with
/// the first adapter; it must use the file-based login keychain so unsigned
/// `swift run` builds work, and it is never exercised in tests.
public protocol KeychainStore: Sendable {
    func get(_ key: String) throws -> String?
    func set(_ value: String, for key: String) throws
    func delete(_ key: String) throws
}
