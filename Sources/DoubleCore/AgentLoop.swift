import DoubleProviders
import DoubleTools
import Foundation

/// Everything the agent loop needs, injected by `DoubleApp` at launch.
///
/// `DoubleCore` reaches the model only through `ModelProvider` and tools only
/// through `ToolRegistry`; it never names a vendor or a concrete tool.
public struct AgentLoopDependencies {
    public var provider: any ModelProvider
    public var tools: ToolRegistry
    public var workspace: any Workspace
    /// Tools above this risk are never offered to the model.
    public var maximumRisk: RiskLevel

    public init(provider: any ModelProvider, tools: ToolRegistry, workspace: any Workspace, maximumRisk: RiskLevel = .medium) {
        self.provider = provider
        self.tools = tools
        self.workspace = workspace
        self.maximumRisk = maximumRisk
    }
}

/// One conversation turn with the model.
///
/// Builds context from the workspace (SOUL, USER, the commitment, today's
/// notes), calls `ModelProvider.complete`, dispatches any `ToolCall` through
/// the registry gated by `maximumRisk`, appends the results, and repeats
/// until the model answers without tool calls. Returns the final text.
public protocol AgentLoop: Sendable {
    func run(input: String) async throws -> String
}
