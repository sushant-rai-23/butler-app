import ButlerProviders
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let keychain: any KeychainStore
    let makeProvider: (String) -> (any ModelProvider)?

    @State private var keyInput = ""
    @State private var hasKey = false
    @State private var models: [ModelInfo] = []
    @State private var status = ""
    @State private var busy = false

    var body: some View {
        Form {
            Section("Provider") {
                Picker("Provider", selection: $settings.providerID) {
                    ForEach(ProviderCatalog.all) { Text($0.displayName).tag($0.id) }
                }
            }
            Section("API key") {
                SecureField("Paste your key", text: $keyInput)
                HStack {
                    Button("Save key") { saveKey() }.disabled(keyInput.isEmpty)
                    Text(hasKey ? "A key is saved." : "No key saved.").foregroundStyle(.secondary)
                    Spacer()
                    Link("Get a key", destination: settings.providerDescriptor.keyHelpURL)
                }
            }
            Section("Model") {
                if !models.isEmpty {
                    Picker("Available", selection: $settings.chatModel) {
                        ForEach(models) { Text($0.displayName).tag($0.id) }
                    }
                }
                TextField("Model id", text: $settings.chatModel)
                HStack {
                    Button("Test connection") { Task { await testConnection() } }.disabled(busy || !hasKey)
                    Text(status).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Section("Advanced") {
                Toggle("Use AppKit text field in the panel (only if typing does not work)", isOn: $settings.useAppKitInputField)
            }
        }
        .formStyle(.grouped)
        .frame(width: 520, height: 400)
        .task {
            refreshKeyState()
            if hasKey { await loadModels(announce: false) }
        }
    }

    private func refreshKeyState() {
        hasKey = ((try? keychain.get(settings.providerDescriptor.keychainKey)) ?? nil)?.isEmpty == false
    }

    private func saveKey() {
        do {
            try keychain.set(keyInput.trimmingCharacters(in: .whitespacesAndNewlines), for: settings.providerDescriptor.keychainKey)
            keyInput = ""
            status = "Key saved."
        } catch {
            status = "Could not save key: \(error)"
        }
        refreshKeyState()
    }

    private func testConnection() async {
        await loadModels(announce: true)
    }

    private func loadModels(announce: Bool) async {
        guard let provider = makeProvider(settings.providerID) else { return }
        busy = true
        defer { busy = false }
        do {
            models = try await provider.listModels()
            if announce { status = "Connected. \(models.count) models available." }
        } catch {
            status = error.localizedDescription
        }
    }
}
