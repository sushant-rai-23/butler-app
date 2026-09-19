import XCTest
@testable import DoubleProviders

final class MessageTests: XCTestCase {
    func testAssistantMessageWithToolCallRoundTrips() throws {
        let call = ToolCall(id: "call_1", name: "read_workspace", arguments: #"{"path":"NOW.md"}"#)
        let original = Message(role: .assistant, content: "", toolCalls: [call])
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(Message.self, from: data), original)
    }

    func testToolResultMessageCarriesTheCallID() {
        let result = Message.toolResult(callID: "call_1", content: "# Now")
        XCTAssertEqual(result.role, .tool)
        XCTAssertEqual(result.toolCallID, "call_1")
    }
}
