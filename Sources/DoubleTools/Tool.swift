import Foundation

/// How much a tool can hurt if the model calls it wrongly.
///
/// `low`: reads Double's own files or the current observation.
/// `medium`: writes Double's own files or posts a nudge.
/// `high`: anything that acts inside the user's applications. Off the table.
public enum RiskLevel: Int, Comparable, Codable, Sendable, CaseIterable {
    case low, medium, high

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Something the model may ask Double to do.
///
/// Tools are registered once in a `ToolRegistry` and dispatched by name.
/// Adding a tool never touches the agent loop.
public protocol Tool: Sendable {
    /// Unique within a registry.
    var name: String { get }
    var description: String { get }
    /// JSON Schema for `invoke(arguments:)`, as a string.
    var parametersSchema: String { get }
    var risk: RiskLevel { get }

    /// Run with the raw JSON arguments the model produced. Returns text for the model.
    func invoke(arguments: String) async throws -> String
}
