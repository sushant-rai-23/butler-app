import Foundation

/// The frontmost application and its window title.
public struct FrontmostWindow: Equatable, Sendable {
    public var appName: String
    public var bundleID: String?
    public var title: String

    public init(appName: String, bundleID: String?, title: String) {
        self.appName = appName
        self.bundleID = bundleID
        self.title = title
    }
}

/// Wraps the Accessibility API behind a protocol so `DoubleCore` and tests
/// never call it and never trigger a permission prompt.
///
/// The real implementation checks `AXIsProcessTrusted()` and reads the focused
/// window of the frontmost application on a timer. It is the cheap signal:
/// no pixels, no model call.
public protocol AccessibilityObserver: Sendable {
    var isTrusted: Bool { get }
    func frontmostWindow() -> FrontmostWindow?
}
