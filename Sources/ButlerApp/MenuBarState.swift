import Foundation

/// What the menu bar icon says about Butler right now.
///
/// Only `.idle` is used in Phase 0. `.watching` means an observation loop is
/// running; `.nudging` means there is an unread nudge in the panel.
enum MenuBarState: CaseIterable, Equatable {
    case idle
    case watching
    case nudging

    static let `default`: MenuBarState = .idle

    /// SF Symbol shown in the status item.
    var symbolName: String {
        switch self {
        case .idle: return "circle.dotted"
        case .watching: return "eye"
        case .nudging: return "bell.badge"
        }
    }

    var accessibilityDescription: String {
        switch self {
        case .idle: return "Butler, idle"
        case .watching: return "Butler, watching"
        case .nudging: return "Butler has a nudge"
        }
    }
}
