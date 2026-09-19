import DoubleCore
import DoubleProviders
import Foundation
import Observation

enum RootScreen: Equatable { case onboarding, keyEntry, chat }

/// Onboarding draft lives here so closing the panel mid-way keeps answers.
struct OnboardingDraft: Equatable {
    var step = 0
    var answers = Array(repeating: "", count: 5)
}

/// The app's composition root state shared by every panel screen.
@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    let keychain: any KeychainStore
    let workspace: MarkdownWorkspace
    let session: ChatSession
    var screen: RootScreen = .chat
    var onboarding = OnboardingDraft()
    /// Shown under the onboarding and key screens when a step fails.
    var lastError: String?

    init(settings: AppSettings, keychain: any KeychainStore, workspace: MarkdownWorkspace, session: ChatSession) {
        self.settings = settings
        self.keychain = keychain
        self.workspace = workspace
        self.session = session
        refreshScreen()
    }

    var hasKey: Bool {
        ((try? keychain.get(settings.providerDescriptor.keychainKey)) ?? nil)?.isEmpty == false
    }

    func refreshScreen() {
        if !workspace.exists { screen = .onboarding }
        else if !hasKey { screen = .keyEntry }
        else { screen = .chat }
    }

    func finishOnboarding() {
        guard let templates = MarkdownWorkspace.bundledTemplates else {
            lastError = "The bundled templates are missing. Rebuild the app."
            return
        }
        let a = onboarding.answers.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let answers = OnboardingAnswers(name: a[0], work: a[1], hours: a[2], workApps: a[3], helpsWhenStuck: a[4])
        do {
            try workspace.seed(from: templates)
            try workspace.applyOnboarding(answers)
            workspace.startWatching()
            lastError = nil
        } catch {
            lastError = "Could not create \(workspace.rootURL.path): \(error.localizedDescription)"
            return
        }
        refreshScreen()
    }

    func saveKey(_ key: String) {
        do {
            try keychain.set(key.trimmingCharacters(in: .whitespacesAndNewlines), for: settings.providerDescriptor.keychainKey)
            lastError = nil
        } catch {
            lastError = "Could not save the key to the Keychain: \(error)"
        }
        refreshScreen()
    }
}
