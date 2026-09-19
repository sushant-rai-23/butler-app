import AppKit
import SwiftUI

/// A non-activating floating panel hosting SwiftUI content.
///
/// Pattern from Maccy and Ice: `.nonactivatingPanel` so opening it does not
/// steal focus from the user's app, `.floating` level, joins all Spaces,
/// stays visible when the app deactivates. The hosting view is rebuilt on
/// every `present` so SwiftUI's appear-time focus request fires each time.
/// Closes on Escape, on the title-bar button, and when it stops being key
/// (a click anywhere else).
final class FloatingPanel: NSPanel {
    static let contentSize = NSSize(width: 380, height: 480)

    init() {
        super.init(
            contentRect: NSRect(origin: .zero, size: FloatingPanel.contentSize),
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        title = "Butler"
        titlebarAppearsTransparent = true
        isFloatingPanel = true
        level = .floating
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
    }

    func present(_ view: some View, at origin: NSPoint) {
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        contentView = hosting
        setContentSize(FloatingPanel.contentSize)
        setFrameOrigin(origin)
        orderFrontRegardless()
        makeKey()
    }

    override var canBecomeKey: Bool { true }

    override func resignKey() {
        super.resignKey()
        close()
    }

    override func cancelOperation(_ sender: Any?) {
        close()
    }

    override func close() {
        super.close()
        contentView = nil
    }
}
