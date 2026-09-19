import AppKit

@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    var onToggle: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    var state: MenuBarState = .default {
        didSet { applyState() }
    }

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        statusItem.button?.target = self
        statusItem.button?.action = #selector(clicked)
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        applyState()
    }

    /// Screen rectangle of the status item button, for positioning the panel.
    var anchorRect: NSRect? {
        guard let button = statusItem.button, let window = button.window else { return nil }
        return window.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func applyState() {
        let image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: state.accessibilityDescription)
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc private func clicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            onToggle?()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Butler", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        statusItem.menu = menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }
}
