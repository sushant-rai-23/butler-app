import AppKit
import ButlerCore
import ButlerProviders
import ButlerTools
import SwiftUI

/// Composition root. Sets the accessory activation policy (no Dock icon),
/// builds every concrete object once, and wires the status item, hotkey,
/// panel and settings window together.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var panelController: PanelController?
    private var settingsWindow: SettingsWindowController?
    private var hotKey: HotKey?
    private var model: AppModel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let settings = AppSettings()
        let keychain = SecurityKeychainStore()
        let workspace = MarkdownWorkspace()
        let provider = ProviderCatalog.makeProvider(id: settings.providerID, keychain: keychain)
            ?? ProviderCatalog.makeProvider(id: ProviderCatalog.defaultProvider.id, keychain: keychain)!
        let loop = DefaultAgentLoop(provider: provider, tools: ToolRegistry(), workspace: workspace)
        let session = ChatSession(loop: loop, settings: settings)
        let model = AppModel(settings: settings, keychain: keychain, workspace: workspace, session: session)
        self.model = model
        if workspace.exists { workspace.startWatching() }
        workspace.changeHandler = { [weak model] in Task { @MainActor in model?.refreshScreen() } }

        let settingsWindow = SettingsWindowController {
            AnyView(SettingsView(settings: settings, keychain: keychain) { id in
                ProviderCatalog.makeProvider(id: id, keychain: keychain)
            })
        }
        self.settingsWindow = settingsWindow

        let panelController = PanelController { [weak self] in
            AnyView(RootView(model: model,
                             onOpenSettings: { self?.openSettings() },
                             onClose: { self?.panelController?.close() }))
        }
        self.panelController = panelController

        let statusItemController = StatusItemController()
        statusItemController.onToggle = { [weak self] in self?.togglePanel() }
        statusItemController.onOpenSettings = { [weak self] in self?.openSettings() }
        self.statusItemController = statusItemController

        hotKey = HotKey.commandShiftSpace { [weak self] in self?.togglePanel() }
    }

    private func togglePanel() {
        model?.refreshScreen()
        panelController?.toggle(anchor: statusItemController?.anchorRect)
    }

    private func openSettings() {
        panelController?.close()
        settingsWindow?.show()
    }
}
