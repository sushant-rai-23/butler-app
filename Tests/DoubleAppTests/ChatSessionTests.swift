import DoubleCore
import DoubleProviders
import DoubleTools
import XCTest
@testable import DoubleApp

/// Scripted AgentLoop: emits the given deltas, then returns or throws.
private final class ScriptedLoop: AgentLoop, @unchecked Sendable {
    var deltas: [String]
    var error: Error?
    var delay: Duration = .zero
    private(set) var resets = 0
    private(set) var models: [String] = []

    init(deltas: [String], error: Error? = nil) {
        self.deltas = deltas
        self.error = error
    }

    func send(_ input: String, model: String, maximumRisk: RiskLevel, onDelta: @escaping @Sendable (String) -> Void) async throws -> String {
        models.append(model)
        if delay > .zero { try? await Task.sleep(for: delay) }
        for delta in deltas { onDelta(delta) }
        if let error { throw error }
        return deltas.joined()
    }

    func reset() async { resets += 1 }
}

@MainActor
final class ChatSessionTests: XCTestCase {
    private func makeSettings() -> AppSettings {
        let suite = "com.double.app.tests.\(UUID().uuidString)"
        let settings = AppSettings(defaults: UserDefaults(suiteName: suite)!)
        settings.chatModel = "test-model"
        return settings
    }

    func testSendAppendsUserAndStreamedAssistantInOrder() async {
        let loop = ScriptedLoop(deltas: ["Hel", "lo, ", "sir."])
        let session = ChatSession(loop: loop, settings: makeSettings())
        session.send("  hi  ")
        XCTAssertTrue(session.isStreaming)
        await session.awaitCurrentTurn()
        XCTAssertFalse(session.isStreaming)
        XCTAssertEqual(session.messages.map(\.role), [.user, .assistant])
        XCTAssertEqual(session.messages.map(\.text), ["hi", "Hello, sir."])
        XCTAssertEqual(loop.models, ["test-model"])
        XCTAssertNil(session.errorText)
    }

    func testErrorRemovesEmptyPlaceholderAndShowsMessage() async {
        let loop = ScriptedLoop(deltas: [], error: ProviderError.rateLimited)
        let session = ChatSession(loop: loop, settings: makeSettings())
        session.send("hi")
        await session.awaitCurrentTurn()
        XCTAssertEqual(session.messages.map(\.role), [.user])
        XCTAssertEqual(session.errorText, ProviderError.rateLimited.errorDescription)
    }

    func testEmptyOrDuplicateSendsAreIgnored() async {
        let loop = ScriptedLoop(deltas: ["x"])
        loop.delay = .milliseconds(100)
        let session = ChatSession(loop: loop, settings: makeSettings())
        session.send("   ")
        XCTAssertTrue(session.messages.isEmpty)
        session.send("one")
        session.send("two")
        await session.awaitCurrentTurn()
        XCTAssertEqual(session.messages.map(\.text), ["one", "x"], "second send while streaming is dropped")
    }

    func testClearWhileStreamingIsIgnored() async {
        let loop = ScriptedLoop(deltas: ["x"])
        loop.delay = .milliseconds(100)
        let session = ChatSession(loop: loop, settings: makeSettings())
        session.send("hi")
        session.clear()
        XCTAssertEqual(session.messages.count, 2, "clear during a stream is a no-op")
        await session.awaitCurrentTurn()
        session.clear()
        XCTAssertTrue(session.messages.isEmpty)
        try? await Task.sleep(for: .milliseconds(20))
        XCTAssertEqual(loop.resets, 1)
    }
}
