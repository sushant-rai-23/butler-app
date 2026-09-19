import AppKit

/// Owns the `NSStatusItem` and toggles the floating panel beneath it.
///
/// We own the status item directly instead of using SwiftUI's `MenuBarExtra`
/// because `MenuBarExtra` cannot be opened or closed programmatically and its
/// `.window` style is not a real floating panel. See decisions.md.
@MainActor
final class StatusItemController {
    private let statusItem: NSStatusItem
    private let panel: FloatingPanel

    var state: MenuBarState = .default {
        didSet { applyState() }
    }

    init(panel: FloatingPanel) {
        self.panel = panel
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)
        applyState()
    }

    private func applyState() {
        let image = NSImage(systemSymbolName: state.symbolName, accessibilityDescription: state.accessibilityDescription)
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    @objc private func togglePanel() {
        if panel.isVisible {
            panel.close()
        } else {
            positionPanelBelowStatusItem()
            panel.makeKeyAndOrderFront(nil)
        }
    }

    /// Maccy's positioning: convert the button's bounds to screen coordinates,
    /// hang the panel from its bottom-left, clamp to the screen's visible frame.
    private func positionPanelBelowStatusItem() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonRect = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        let size = panel.frame.size
        var origin = NSPoint(x: buttonRect.minX, y: buttonRect.minY - size.height)
        if let screen = buttonWindow.screen ?? NSScreen.main {
            let visible = screen.visibleFrame
            origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
            origin.y = max(origin.y, visible.minY)
        }
        panel.setFrameOrigin(origin)
    }
}
