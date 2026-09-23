import ButlerProviders
import ButlerTools
import XCTest
@testable import ButlerCore

struct StubWorkspace: Workspace {
    var rootURL = URL(fileURLWithPath: "/tmp/stub")
    func read(_ relativePath: String) throws -> String { "" }
    func write(_ contents: String, to relativePath: String) throws {}
    func document(_ relativePath: String) throws -> MarkdownDocument { MarkdownDocument(frontmatter: nil, body: "") }
    func index() throws -> [MemoryEntry] { [] }
    func append(_ text: String, to relativePath: String, description: String?) throws {}
    func systemPrompt() throws -> String { "SYSTEM" }
}

final class DefaultAgentLoopTests: XCTestCase {
    func makeLoop(_ provider: ScriptedProvider, tools: [any Tool] = [EchoTool()], maxToolRounds: Int = 8) throws -> DefaultAgentLoop {
        let registry = ToolRegistry()
        for tool in tools { try registry.register(tool) }
        return DefaultAgentLoop(provider: provider, tools: registry, workspace: StubWorkspace(), maxToolRounds: maxToolRounds)
    }

    func testStreamsDeltasAndReturnsFinalText() async throws {
        let provider = ScriptedProvider([[.textDelta("Hello, "), .textDelta("sir."), .finished(.stop)]])
        let loop = try makeLoop(provider)
        let collected = Collector()
        let result = try await loop.send("hi", model: "m", maximumRisk: .medium) { delta in collected.add(delta) }
        XCTAssertEqual(result, "Hello, sir.")
        let deltas = collected.values
        XCTAssertEqual(deltas.joined(), "Hello, sir.")
        XCTAssertEqual(provider.requests[0].system, "SYSTEM")
        XCTAssertEqual(provider.requests[0].model, "m")
        XCTAssertEqual(provider.requests[0].tools.map(\.name), ["echo"])
        XCTAssertEqual(provider.requests[0].messages, [Message(role: .user, text: "hi")])
    }

    func testToolCallRoundTripKeepsOpaqueAndAppendsResult() async throws {
        let call = ToolCall(id: "c1", name: "echo", arguments: #"{"text":"hi back"}"#, opaque: "sig")
        let provider = ScriptedProvider([[.toolCall(call), .finished(.stop)], [.textDelta("Echo said hi back"), .finished(.stop)]])
        let loop = try makeLoop(provider)
        let result = try await loop.send("say hi", model: "m", maximumRisk: .medium) { _ in }
        XCTAssertEqual(result, "Echo said hi back")
        let second = provider.requests[1].messages
        XCTAssertEqual(second.count, 3)
        XCTAssertEqual(second[1].role, .assistant)
        XCTAssertEqual(second[1].toolCalls.first?.opaque, "sig")
        XCTAssertEqual(second[2], .toolResult(for: call, content: "hi back"))
        let history = await loop.history
        XCTAssertEqual(history.count, 4)
    }

    func testToolAboveRiskCapIsRefusedNotRun() async throws {
        let call = ToolCall(id: "c1", name: "echo", arguments: #"{"text":"x"}"#)
        let provider = ScriptedProvider([[.toolCall(call), .finished(.stop)], [.textDelta("ok"), .finished(.stop)]])
        var risky = EchoTool(); risky.risk = .high
        let loop = try makeLoop(provider, tools: [risky])
        _ = try await loop.send("go", model: "m", maximumRisk: .medium) { _ in }
        XCTAssertEqual(provider.requests[0].tools, [], "high-risk tools are not offered")
        XCTAssertTrue(provider.requests[1].messages[2].text.hasPrefix("error:"))
    }

    func testProviderErrorRollsBackHistory() async throws {
        let provider = ScriptedProvider([])
        provider.failNext = ProviderError.rateLimited
        let loop = try makeLoop(provider)
        do {
            _ = try await loop.send("hi", model: "m", maximumRisk: .medium) { _ in }
            XCTFail("expected throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .rateLimited)
        }
        let history = await loop.history
        XCTAssertEqual(history, [])
    }

    func testTooManyToolRoundsThrows() async throws {
        let call = ToolCall(id: "c", name: "echo", arguments: #"{"text":"again"}"#)
        let provider = ScriptedProvider([[.toolCall(call), .finished(.stop)], [.toolCall(call), .finished(.stop)], [.toolCall(call), .finished(.stop)]])
        let loop = try makeLoop(provider, maxToolRounds: 2)
        do {
            _ = try await loop.send("loop", model: "m", maximumRisk: .medium) { _ in }
            XCTFail("expected throw")
        } catch let error as AgentLoopError {
            XCTAssertEqual(error, .tooManyToolRounds(2))
        }
    }
}

/// Order matters, so collect under a lock rather than in unordered Tasks.
private final class Collector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [String] = []
    var values: [String] { lock.withLock { storage } }
    func add(_ value: String) { lock.withLock { storage.append(value) } }
}

/// Streams nothing for a while, then fails. Lets a test call `reset()` while
/// `send` is suspended inside the provider stream.
private final class SlowFailingProvider: ModelProvider, @unchecked Sendable {
    let id = "slow"
    func listModels() async throws -> [ModelInfo] { [] }
    func stream(_ request: ChatRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            Task {
                try? await Task.sleep(for: .milliseconds(150))
                continuation.finish(throwing: ProviderError.network("offline"))
            }
        }
    }
}

extension DefaultAgentLoopTests {
    func testEmptyReplyThrowsAndRollsBack() async throws {
        let provider = ScriptedProvider([[.finished(.contentFiltered)]])
        let loop = try makeLoop(provider)
        do {
            _ = try await loop.send("hi", model: "m", maximumRisk: .medium) { _ in }
            XCTFail("expected throw")
        } catch let error as AgentLoopError {
            XCTAssertEqual(error, .emptyReply(.contentFiltered))
        }
        let history = await loop.history
        XCTAssertEqual(history, [], "an empty assistant turn must never be stored")
    }

    func testResetWhileSendIsSuspendedDoesNotTrap() async throws {
        let registry = ToolRegistry()
        let loop = DefaultAgentLoop(provider: SlowFailingProvider(), tools: registry, workspace: StubWorkspace())
        async let sending: String = loop.send("hi", model: "m", maximumRisk: .medium) { _ in }
        try await Task.sleep(for: .milliseconds(30))
        await loop.reset()
        do {
            _ = try await sending
            XCTFail("expected throw")
        } catch let error as ProviderError {
            XCTAssertEqual(error, .network("offline"))
        }
        let history = await loop.history
        XCTAssertEqual(history, [])
    }
}

/// The Phase 2a seam, end to end: the model asks, the registry dispatches, the
/// real workspace writes, and the result comes back — against disk, not a stub.
extension DefaultAgentLoopTests {
    private func makeWorkspace() throws -> MarkdownWorkspace {
        let root = URL.temporaryDirectory.appending(path: "butler-loop-\(UUID().uuidString)")
        let workspace = MarkdownWorkspace(rootURL: root)
        try workspace.seed(from: XCTUnwrap(MarkdownWorkspace.bundledTemplates))
        addTeardownBlock { try? FileManager.default.removeItem(at: root) }
        return workspace
    }

    private var writeAditya: ToolCall {
        ToolCall(
            id: "c1",
            name: "memory.write",
            arguments: #"{"path":"people/aditya.md","text":"Runs the backend.","description":"Backend lead."}"#,
            opaque: "sig"
        )
    }

    func testMemoryWriteToolCallLandsOnDiskAndComesBackToTheModel() async throws {
        let workspace = try makeWorkspace()
        let registry = ToolRegistry()
        try registry.register(MemoryWriteTool(workspace: workspace))
        let provider = ScriptedProvider([
            [.toolCall(writeAditya), .finished(.stop)],
            [.textDelta("Noted, sir."), .finished(.stop)],
            [.textDelta("He runs the backend, sir."), .finished(.stop)],
        ])
        let loop = DefaultAgentLoop(provider: provider, tools: registry, workspace: workspace)

        let result = try await loop.send("remember that Aditya runs the backend", model: "m", maximumRisk: .medium) { _ in }

        XCTAssertEqual(result, "Noted, sir.")
        XCTAssertEqual(provider.requests[0].tools.map(\.name), ["memory.write"], "medium risk is within the cap")
        XCTAssertTrue(try workspace.read("people/aditya.md").contains("Runs the backend."))
        let second = provider.requests[1]
        XCTAssertTrue(second.messages.contains { $0.text.contains("Created people/aditya.md") })
        // The prompt is built once per turn, not once per tool round, so the new
        // file reaches the index on the next turn rather than mid-turn.
        XCTAssertEqual(second.system, provider.requests[0].system)

        _ = try await loop.send("what do you know about Aditya?", model: "m", maximumRisk: .medium) { _ in }

        let system = try XCTUnwrap(provider.requests[2].system)
        XCTAssertTrue(system.contains("# Memory index"), system)
        XCTAssertTrue(system.contains("people/aditya.md — Backend lead."), "the file written last turn is in the prompt, with no restart")
    }

    /// A model that invents a tool name, or names one it was not offered, must
    /// get a plain error back and keep going — the turn is not the place to fail.
    func testUnknownToolNameIsReportedToTheModelAndTheTurnContinues() async throws {
        let call = ToolCall(id: "c1", name: "memory.write", arguments: "{}")
        let provider = ScriptedProvider([[.toolCall(call), .finished(.stop)], [.textDelta("Sorry, sir."), .finished(.stop)]])
        let loop = try makeLoop(provider)

        let result = try await loop.send("go", model: "m", maximumRisk: .medium) { _ in }

        XCTAssertEqual(result, "Sorry, sir.")
        XCTAssertEqual(provider.requests[1].messages[2].text, "error: unknown tool memory.write")
    }

    /// Rollback is history-only by design: a file the tool already wrote stays
    /// written. The user's message goes back to them to send again, and the
    /// model sees the file in the index next turn rather than writing it twice.
    func testFailureAfterAWriteRollsBackHistoryButNotTheFile() async throws {
        let workspace = try makeWorkspace()
        let registry = ToolRegistry()
        try registry.register(MemoryWriteTool(workspace: workspace))
        let provider = ScriptedProvider([[.toolCall(writeAditya), .finished(.stop)], [.finished(.contentFiltered)]])
        let loop = DefaultAgentLoop(provider: provider, tools: registry, workspace: workspace)

        do {
            _ = try await loop.send("remember that Aditya runs the backend", model: "m", maximumRisk: .medium) { _ in }
            XCTFail("expected throw")
        } catch let error as AgentLoopError {
            XCTAssertEqual(error, .emptyReply(.contentFiltered))
        }

        let history = await loop.history
        XCTAssertEqual(history, [], "no half turn is left for the next request to carry")
        XCTAssertTrue(try workspace.read("people/aditya.md").contains("Runs the backend."))
    }
}
