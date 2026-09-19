import Foundation

/// The seam between `ButlerCore` and any model vendor.
///
/// One conforming type per vendor, one folder each, living in this module.
/// An adapter owns request shaping, streaming, and error mapping. It reads its
/// API key from a `KeychainStore` and never logs it, never puts it in a URL,
/// and never places it in a `Message`.
public protocol ModelProvider: Sendable {
    /// Stable identifier such as `"gemini"`, used for settings and Keychain keys.
    var id: String { get }

    /// Models the key can use, for the Settings picker.
    func listModels() async throws -> [ModelInfo]

    /// Stream the model's reply. Yields text deltas and tool calls as they
    /// arrive and ends with `.finished`. Throws `ProviderError`.
    func stream(_ request: ChatRequest) -> AsyncThrowingStream<StreamEvent, Error>
}

public extension ModelProvider {
    /// Collects a stream into one assistant message. Adapters do not override this.
    func complete(_ request: ChatRequest) async throws -> Message {
        var text = ""
        var calls: [ToolCall] = []
        for try await event in stream(request) {
            switch event {
            case .textDelta(let delta): text += delta
            case .toolCall(let call): calls.append(call)
            case .finished: break
            }
        }
        return Message(role: .assistant, parts: text.isEmpty ? [] : [.text(text)], toolCalls: calls)
    }
}
