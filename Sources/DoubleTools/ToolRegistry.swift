import Foundation

public enum ToolRegistryError: Error, Equatable {
    case duplicateName(String)
}

/// Holds the tools the model may call, keyed by unique name.
///
/// The agent loop asks for `tools(atMost:)` to build the list it offers the
/// model, and `tool(named:)` to dispatch a `ToolCall`.
public final class ToolRegistry: @unchecked Sendable {
    private let lock = NSLock()
    private var tools: [String: any Tool] = [:]

    public init() {}

    public func register(_ tool: any Tool) throws {
        try lock.withLock {
            guard tools[tool.name] == nil else { throw ToolRegistryError.duplicateName(tool.name) }
            tools[tool.name] = tool
        }
    }

    public func tool(named name: String) -> (any Tool)? {
        lock.withLock { tools[name] }
    }

    /// Every registered tool, sorted by name.
    public var all: [any Tool] {
        lock.withLock { tools.values.sorted { $0.name < $1.name } }
    }

    /// Tools whose risk is at or below `maximum`, sorted by name.
    public func tools(atMost maximum: RiskLevel) -> [any Tool] {
        all.filter { $0.risk <= maximum }
    }
}
