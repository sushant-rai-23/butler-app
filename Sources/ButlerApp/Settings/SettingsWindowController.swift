import AppKit
import SwiftUI

/// Our own window for Settings. An accessory app must briefly become a
/// regular, active app for a window to come to the front; we flip the policy
/// only while this window is open and never for the chat panel.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let makeView: () -> AnyView

    init(makeView: @escaping () -> AnyView) {
        self.makeView = makeView
    }

    func show() {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 400), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = "Butler Settings"
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            self.window = window
        }
        window?.contentView = NSHostingView(rootView: makeView())
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
