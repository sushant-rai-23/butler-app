import AppKit
import SwiftUI

/// Owns the panel and decides where it appears: under the status item when
/// there is one, otherwise the top-right of the main screen.
@MainActor
final class PanelController {
    private let panel = FloatingPanel()
    private let makeView: () -> AnyView

    init(makeView: @escaping () -> AnyView) {
        self.makeView = makeView
    }

    var isVisible: Bool { panel.isVisible }

    func toggle(anchor: NSRect?) {
        if panel.isVisible { panel.close() } else { show(anchor: anchor) }
    }

    func close() {
        panel.close()
    }

    func show(anchor: NSRect?) {
        let size = FloatingPanel.contentSize
        let screen = NSScreen.screens.first { $0.frame.contains(anchor?.origin ?? .zero) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        var origin: NSPoint
        if let anchor {
            origin = NSPoint(x: anchor.minX, y: anchor.minY - size.height - 4)
        } else {
            origin = NSPoint(x: visible.maxX - size.width - 16, y: visible.maxY - size.height - 16)
        }
        origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
        origin.y = max(origin.y, visible.minY)
        panel.present(makeView(), at: origin)
    }
}
