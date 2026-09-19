import Foundation
import Security

public enum KeychainError: Error, Equatable {
    case unexpectedStatus(OSStatus)
    case encoding
}

/// Generic-password items in the login keychain under one service name.
///
/// `kSecUseDataProtectionKeychain` is deliberately not set: the data
/// protection keychain needs an entitlement that unsigned `swift run` builds
/// do not have. Every rebuild is a new code identity, so macOS may ask once
/// per build before reading an item an older build wrote; choose Always Allow.
public final class SecurityKeychainStore: KeychainStore, @unchecked Sendable {
    public static let defaultService = "com.butler.app"
    private let service: String

    public init(service: String = SecurityKeychainStore.defaultService) {
        self.service = service
    }

    public func get(_ key: String) throws -> String? {
        var query = baseQuery(key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data, let value = String(data: data, encoding: .utf8) else { throw KeychainError.encoding }
            return value
        case errSecItemNotFound:
            return nil
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    public func set(_ value: String, for key: String) throws {
        let data = Data(value.utf8)
        let update = [kSecValueData as String: data]
        let status = SecItemUpdate(baseQuery(key) as CFDictionary, update as CFDictionary)
        if status == errSecSuccess { return }
        guard status == errSecItemNotFound else { throw KeychainError.unexpectedStatus(status) }
        var add = baseQuery(key)
        add[kSecValueData as String] = data
        let addStatus = SecItemAdd(add as CFDictionary, nil)
        guard addStatus == errSecSuccess else { throw KeychainError.unexpectedStatus(addStatus) }
    }

    public func delete(_ key: String) throws {
        let status = SecItemDelete(baseQuery(key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw KeychainError.unexpectedStatus(status) }
    }

    private func baseQuery(_ key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
        ]
    }
}
