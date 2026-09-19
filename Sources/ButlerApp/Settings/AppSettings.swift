import ButlerProviders
import Foundation
import Observation

/// Non-secret settings in a named UserDefaults suite (a bare `swift run`
/// binary has no bundle identifier). Keys never live here.
@Observable
final class AppSettings {
    static let suiteName = "com.butler.app"
    private enum Keys {
        static let providerID = "providerID"
        static let chatModel = "chatModel"
        static let useAppKitInputField = "useAppKitInputField"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var providerID: String { didSet { defaults.set(providerID, forKey: Keys.providerID) } }
    var chatModel: String { didSet { defaults.set(chatModel, forKey: Keys.chatModel) } }
    /// Fallback when SwiftUI focus fails inside the non-activating panel.
    var useAppKitInputField: Bool { didSet { defaults.set(useAppKitInputField, forKey: Keys.useAppKitInputField) } }

    init(defaults: UserDefaults = UserDefaults(suiteName: AppSettings.suiteName)!) {
        self.defaults = defaults
        let providerID = defaults.string(forKey: Keys.providerID) ?? ProviderCatalog.defaultProvider.id
        self.providerID = providerID
        self.chatModel = defaults.string(forKey: Keys.chatModel) ?? (ProviderCatalog.descriptor(id: providerID)?.defaultModel ?? "")
        self.useAppKitInputField = defaults.bool(forKey: Keys.useAppKitInputField)
    }

    var providerDescriptor: ProviderDescriptor {
        ProviderCatalog.descriptor(id: providerID) ?? ProviderCatalog.defaultProvider
    }
}
