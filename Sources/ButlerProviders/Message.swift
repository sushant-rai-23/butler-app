import Foundation

/// One piece of a message. Text today; JPEG images for the Phase 3 watcher.
public enum ContentPart: Equatable, Codable, Sendable {
    case text(String)
    case image(data: Data, mimeType: String)
}

/// One turn in a conversation with a model, in Butler's own shape.
///
/// Adapters translate `Message` to and from each vendor's wire format so
/// `ButlerCore` never sees vendor JSON. A `Message` never carries an API key.
/// The system prompt is not a message; it travels in `ChatRequest.system`.
public struct Message: Equatable, Codable, Sendable {
    public enum Role: String, Codable, Sendable { case user, assistant, tool }

    public var role: Role
    public var parts: [ContentPart]
    /// Tool invocations the assistant asked for. Empty for every other role.
    public var toolCalls: [ToolCall]
    /// For `.tool` messages: the `ToolCall.id` this result answers.
    public var toolCallID: String?
    /// For `.tool` messages: the tool's name. Some vendors need name and id.
    public var toolName: String?

    public init(role: Role, parts: [ContentPart], toolCalls: [ToolCall] = [], toolCallID: String? = nil, toolName: String? = nil) {
        self.role = role
        self.parts = parts
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
        self.toolName = toolName
    }

    public init(role: Role, text: String) {
        self.init(role: role, parts: [.text(text)])
    }

    /// All text parts joined, images skipped.
    public var text: String {
        parts.compactMap { part -> String? in
            if case .text(let value) = part { return value }
            return nil
        }.joined()
    }

    /// The result of running a tool, addressed back to the call that requested it.
    public static func toolResult(for call: ToolCall, content: String) -> Message {
        Message(role: .tool, parts: [.text(content)], toolCallID: call.id, toolName: call.name)
    }
}
