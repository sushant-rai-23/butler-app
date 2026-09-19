import AppKit

/// Sets the accessory activation policy (no Dock icon, no main menu) and owns
/// the status item and panel for the life of the process.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var panel: FloatingPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let panel = FloatingPanel()
        self.panel = panel
        statusItemController = StatusItemController(panel: panel)
    }
}
