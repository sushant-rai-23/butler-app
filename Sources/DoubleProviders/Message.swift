import Foundation

/// One turn in a conversation with a model, in Double's own shape.
///
/// Adapters translate `Message` to and from each vendor's wire format so that
/// `DoubleCore` never sees vendor JSON. A `Message` never carries an API key.
public struct Message: Equatable, Codable, Sendable {
    public enum Role: String, Codable, Sendable {
        case system, user, assistant, tool
    }

    public var role: Role
    public var content: String
    /// Tool invocations the assistant asked for. Empty for every other role.
    public var toolCalls: [ToolCall]
    /// For `.tool` messages: the `ToolCall.id` this result answers.
    public var toolCallID: String?

    public init(role: Role, content: String, toolCalls: [ToolCall] = [], toolCallID: String? = nil) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallID = toolCallID
    }

    /// The result of running a tool, addressed back to the call that requested it.
    public static func toolResult(callID: String, content: String) -> Message {
        Message(role: .tool, content: content, toolCallID: callID)
    }
}
