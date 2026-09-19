import Foundation

/// A model's request to run a tool.
///
/// `arguments` is the raw JSON object the model produced, kept as a string so
/// the provider does not have to know each tool's schema. The tool decodes it.
public struct ToolCall: Equatable, Codable, Sendable {
    public let id: String
    public let name: String
    public let arguments: String
    /// Provider-owned state to echo back verbatim with this call on the next
    /// request (for example a reasoning signature). Core stores it and never
    /// reads it.
    public var opaque: String?

    public init(id: String, name: String, arguments: String, opaque: String? = nil) {
        self.id = id
        self.name = name
        self.arguments = arguments
        self.opaque = opaque
    }
}

/// What a provider tells the model about an available tool.
///
/// `ButlerCore` builds these from `ButlerTools.Tool` so that `ButlerTools`
/// and `ButlerProviders` stay independent of each other.
public struct ToolSpec: Equatable, Codable, Sendable {
    public let name: String
    public let description: String
    /// JSON Schema for the tool's arguments, as a string.
    public let parametersSchema: String

    public init(name: String, description: String, parametersSchema: String) {
        self.name = name
        self.description = description
        self.parametersSchema = parametersSchema
    }
}
