import XCTest
@testable import DoubleProviders

private struct EventsProvider: ModelProvider {
    let id = "events"
    let events: [StreamEvent]
    func listModels() async throws -> [ModelInfo] { [] }
    func stream(_ request: ChatRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        AsyncThrowingStream { continuation in
            for event in events { continuation.yield(event) }
            continuation.finish()
        }
    }
}

final class ModelProviderCompleteTests: XCTestCase {
    func testCompleteCollectsDeltasAndToolCalls() async throws {
        let call = ToolCall(id: "c1", name: "echo", arguments: "{}")
        let provider = EventsProvider(events: [.textDelta("Hel"), .textDelta("lo"), .toolCall(call), .finished(.stop)])
        let message = try await provider.complete(ChatRequest(model: "m", system: nil, messages: []))
        XCTAssertEqual(message.role, .assistant)
        XCTAssertEqual(message.text, "Hello")
        XCTAssertEqual(message.toolCalls, [call])
    }
}
