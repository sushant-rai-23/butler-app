import XCTest
@testable import DoubleProviders

final class MessageTests: XCTestCase {
    func testAssistantMessageWithToolCallRoundTrips() throws {
        let call = ToolCall(id: "call_1", name: "read_workspace", arguments: #"{"path":"NOW.md"}"#, opaque: "sig-1")
        let original = Message(role: .assistant, parts: [.text("Reading.")], toolCalls: [call])
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(Message.self, from: data), original)
    }

    func testTextJoinsTextPartsAndSkipsImages() {
        let message = Message(role: .user, parts: [.text("a"), .image(data: Data([1]), mimeType: "image/jpeg"), .text("b")])
        XCTAssertEqual(message.text, "ab")
    }

    func testToolResultCarriesCallIDAndName() {
        let call = ToolCall(id: "call_1", name: "echo", arguments: "{}")
        let result = Message.toolResult(for: call, content: "hi")
        XCTAssertEqual(result.role, .tool)
        XCTAssertEqual(result.toolCallID, "call_1")
        XCTAssertEqual(result.toolName, "echo")
        XCTAssertEqual(result.text, "hi")
    }
}
