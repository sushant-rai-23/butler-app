import Foundation

/// Everything one model call needs. Model is per request so a Settings
/// change applies to the next message with no provider state.
public struct ChatRequest: Equatable, Sendable {
    public var model: String
    public var system: String?
    public var messages: [Message]
    public var tools: [ToolSpec]

    public init(model: String, system: String?, messages: [Message], tools: [ToolSpec] = []) {
        self.model = model
        self.system = system
        self.messages = messages
        self.tools = tools
    }
}

public enum FinishReason: Equatable, Sendable {
    case stop
    case maxTokens
    case contentFiltered
    case other(String)
}

/// What a streaming call yields, in order. `finished` is always last.
public enum StreamEvent: Equatable, Sendable {
    case textDelta(String)
    case toolCall(ToolCall)
    case finished(FinishReason)
}

public struct ModelInfo: Equatable, Codable, Sendable, Identifiable {
    /// Bare id such as `gemini-3.8-flash`, never a vendor path.
    public let id: String
    public let displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}
