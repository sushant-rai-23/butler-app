import DoubleProviders
import DoubleTools
import Foundation

public actor DefaultAgentLoop: AgentLoop {
    private let provider: any ModelProvider
    private let tools: ToolRegistry
    private let workspace: any Workspace
    private let maxToolRounds: Int
    public private(set) var history: [Message] = []

    public init(provider: any ModelProvider, tools: ToolRegistry, workspace: any Workspace, maxToolRounds: Int = 8) {
        self.provider = provider
        self.tools = tools
        self.workspace = workspace
        self.maxToolRounds = maxToolRounds
    }

    public func reset() {
        history.removeAll()
    }

    public func send(_ input: String, model: String, maximumRisk: RiskLevel, onDelta: @escaping @Sendable (String) -> Void) async throws -> String {
        let system = try workspace.systemPrompt()
        let specs = tools.tools(atMost: maximumRisk).map {
            ToolSpec(name: $0.name, description: $0.description, parametersSchema: $0.parametersSchema)
        }
        let checkpoint = history.count
        history.append(Message(role: .user, text: input))
        do {
            for _ in 0..<maxToolRounds {
                let request = ChatRequest(model: model, system: system, messages: history, tools: specs)
                var text = ""
                var calls: [ToolCall] = []
                for try await event in provider.stream(request) {
                    switch event {
                    case .textDelta(let delta):
                        text += delta
                        onDelta(delta)
                    case .toolCall(let call):
                        calls.append(call)
                    case .finished:
                        break
                    }
                }
                history.append(Message(role: .assistant, parts: text.isEmpty ? [] : [.text(text)], toolCalls: calls))
                if calls.isEmpty { return text }
                for call in calls {
                    let result = await run(call, maximumRisk: maximumRisk)
                    history.append(.toolResult(for: call, content: result))
                }
            }
            throw AgentLoopError.tooManyToolRounds(maxToolRounds)
        } catch {
            history.removeSubrange(checkpoint...)
            throw error
        }
    }

    private func run(_ call: ToolCall, maximumRisk: RiskLevel) async -> String {
        guard let tool = tools.tool(named: call.name) else { return "error: unknown tool \(call.name)" }
        guard tool.risk <= maximumRisk else { return "error: tool \(call.name) is above the allowed risk level" }
        do { return try await tool.invoke(arguments: call.arguments) } catch { return "error: \(error)" }
    }
}
