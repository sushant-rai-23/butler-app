import SwiftUI

/// Entry point. Runs unsigned from `swift run ButlerApp`.
///
/// The status item and panel live in `AppDelegate`. The `MenuBarExtra` below
/// is never inserted; it exists only because a SwiftUI `App` must declare a
/// scene. Do not add windows here: an accessory app cannot reliably bring
/// SwiftUI windows to the front.
@main
struct ButlerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("Butler", systemImage: MenuBarState.default.symbolName, isInserted: .constant(false)) {
            EmptyView()
        }
    }
}
