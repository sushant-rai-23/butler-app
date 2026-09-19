import Foundation

/// The seam between `DoubleCore` and any model vendor.
///
/// One conforming type per vendor, one file each, living in this module.
/// An adapter owns request shaping, streaming, and error mapping. It reads its
/// API key from a `KeychainStore` and never logs it, never puts it in a URL,
/// and never places it in a `Message`.
///
/// No adapter exists in Phase 0. Gemini (AI Studio, free tier) is the first.
public protocol ModelProvider: Sendable {
    /// Stable identifier such as `"gemini"`, used for settings and Keychain keys.
    var id: String { get }

    /// Send the conversation and the tools the model may call; return the
    /// model's next message. If `toolCalls` is non-empty the caller runs the
    /// tools and calls again with the results appended.
    func complete(messages: [Message], tools: [ToolSpec]) async throws -> Message
}
