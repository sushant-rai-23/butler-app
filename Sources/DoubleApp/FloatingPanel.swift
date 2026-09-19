import AppKit
import SwiftUI

/// A non-activating floating panel hosting SwiftUI content.
///
/// Pattern from Maccy and Cindori: `.nonactivatingPanel` so opening it does
/// not steal focus from the user's app, `.floating` level, joins all Spaces,
/// stays visible when the app deactivates (an accessory app is rarely active).
/// Closes on Escape and via the title-bar close button. Click-outside dismissal
/// arrives with the event monitors in Phase 1.
final class FloatingPanel: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = "Double"
        titlebarAppearsTransparent = true
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
        contentView = NSHostingView(rootView: PanelView())
    }

    override var canBecomeKey: Bool { true }

    /// Escape closes the panel.
    override func cancelOperation(_ sender: Any?) {
        close()
    }
}
