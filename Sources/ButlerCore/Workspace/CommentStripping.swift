import Foundation

public extension String {
    /// Removes lines that start with `_`. Templates use them for guidance that
    /// should never reach the model.
    func strippingCommentLines() -> String {
        split(separator: "\n", omittingEmptySubsequences: false)
            .filter { !$0.hasPrefix("_") }
            .joined(separator: "\n")
    }
}
