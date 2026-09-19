import Foundation

/// What the app needs to know about a provider without importing its type.
public struct ProviderDescriptor: Equatable, Sendable, Identifiable {
    public let id: String
    public let displayName: String
    public let defaultModel: String
    public let keychainKey: String
    /// Where the user gets a key.
    public let keyHelpURL: URL
}

/// The only place that names concrete adapters. DoubleApp builds providers
/// through here, so no vendor type leaks outside this module.
public enum ProviderCatalog {
    public static let all: [ProviderDescriptor] = [
        ProviderDescriptor(
            id: "gemini",
            displayName: "Gemini (AI Studio)",
            defaultModel: "gemini-3.8-flash",
            keychainKey: GeminiProvider.keychainKey,
            keyHelpURL: URL(string: "https://aistudio.google.com/apikey")!
        ),
    ]

    public static var defaultProvider: ProviderDescriptor { all[0] }

    public static func descriptor(id: String) -> ProviderDescriptor? {
        all.first { $0.id == id }
    }

    public static func makeProvider(id: String, keychain: any KeychainStore, session: URLSession = .shared) -> (any ModelProvider)? {
        switch id {
        case "gemini": return GeminiProvider(keychain: keychain, session: session)
        default: return nil
        }
    }
}
