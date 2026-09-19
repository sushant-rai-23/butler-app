import DoubleProviders
import DoubleTools
import Foundation

public enum AgentLoopError: Error, Equatable {
    case tooManyToolRounds(Int)
}

/// One conversation with the model.
///
/// Builds context from the workspace (SOUL and USER as the system prompt,
/// plus this session's history), streams the reply, dispatches any
/// `ToolCall` through the registry gated by `maximumRisk`, appends the
/// results, and repeats until the model answers without tool calls.
/// `DoubleCore` reaches the model only through `ModelProvider` and tools
/// only through `ToolRegistry`; it never names a vendor or a concrete tool.
public protocol AgentLoop: Sendable {
    /// Runs one user turn. `onDelta` receives text as it streams; the return
    /// value is the complete final answer.
    func send(_ input: String, model: String, maximumRisk: RiskLevel, onDelta: @escaping @Sendable (String) -> Void) async throws -> String
    /// Forgets this session's history. Workspace files are untouched.
    func reset() async
}
