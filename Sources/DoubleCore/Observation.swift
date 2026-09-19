import Foundation

/// A cheap reading of what is in front of the user: frontmost app and window
/// title, no pixels, no model call.
///
/// `DoubleApp` builds these from `DoubleWatch` output. Titles are untrusted
/// text and are fenced before they reach a model.
public struct Observation: Equatable, Sendable {
    public var appName: String
    public var windowTitle: String
    public var at: Date

    public init(appName: String, windowTitle: String, at: Date) {
        self.appName = appName
        self.windowTitle = windowTitle
        self.at = at
    }
}
