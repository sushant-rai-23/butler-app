import XCTest
@testable import ButlerProviders

final class GeminiMappingTests: XCTestCase {
    private func json(_ value: some Encodable) throws -> [String: Any] {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testRequestMapsRolesSystemAndTools() throws {
        let request = ChatRequest(
            model: "gemini-3.8-flash",
            system: "You are Jarvis.",
            messages: [Message(role: .user, text: "hi")],
            tools: [ToolSpec(name: "echo", description: "Echoes", parametersSchema: #"{"type":"object","properties":{"text":{"type":"string"}}}"#)]
        )
        let wire = try json(GeminiMapping.request(from: request))
        let contents = try XCTUnwrap(wire["contents"] as? [[String: Any]])
        XCTAssertEqual(contents.count, 1)
        XCTAssertEqual(contents[0]["role"] as? String, "user")
        let system = try XCTUnwrap(wire["systemInstruction"] as? [String: Any])
        let systemParts = try XCTUnwrap(system["parts"] as? [[String: Any]])
        XCTAssertEqual(systemParts[0]["text"] as? String, "You are Jarvis.")
        let tools = try XCTUnwrap(wire["tools"] as? [[String: Any]])
        let decls = try XCTUnwrap(tools[0]["functionDeclarations"] as? [[String: Any]])
        XCTAssertEqual(decls[0]["name"] as? String, "echo")
        XCTAssertNotNil(decls[0]["parametersJsonSchema"])
        let config = try XCTUnwrap(wire["generationConfig"] as? [String: Any])
        let thinking = try XCTUnwrap(config["thinkingConfig"] as? [String: Any])
        XCTAssertEqual(thinking["thinkingLevel"] as? String, "low")
    }

    func testAssistantToolCallEchoesSignatureAndToolResultsMergeIntoOneUserTurn() throws {
        let call1 = ToolCall(id: "8f2b", name: "echo", arguments: #"{"text":"a"}"#, opaque: "SIG")
        let call2 = ToolCall(id: "local-abc", name: "echo", arguments: #"{"text":"b"}"#)
        let request = ChatRequest(model: "gemini-3.8-flash", system: nil, messages: [
            Message(role: .user, text: "go"),
            Message(role: .assistant, parts: [], toolCalls: [call1, call2]),
            .toolResult(for: call1, content: "A"),
            .toolResult(for: call2, content: "B"),
        ])
        let wire = try json(GeminiMapping.request(from: request))
        let contents = try XCTUnwrap(wire["contents"] as? [[String: Any]])
        XCTAssertEqual(contents.map { $0["role"] as? String }, ["user", "model", "user"])
        let modelParts = try XCTUnwrap(contents[1]["parts"] as? [[String: Any]])
        XCTAssertEqual(modelParts.count, 2)
        XCTAssertEqual(modelParts[0]["thoughtSignature"] as? String, "SIG")
        let fc1 = try XCTUnwrap(modelParts[0]["functionCall"] as? [String: Any])
        XCTAssertEqual(fc1["id"] as? String, "8f2b")
        let fc2 = try XCTUnwrap(modelParts[1]["functionCall"] as? [String: Any])
        XCTAssertNil(fc2["id"], "locally generated ids are not sent back")
        let resultParts = try XCTUnwrap(contents[2]["parts"] as? [[String: Any]])
        XCTAssertEqual(resultParts.count, 2)
        let fr1 = try XCTUnwrap(resultParts[0]["functionResponse"] as? [String: Any])
        XCTAssertEqual(fr1["id"] as? String, "8f2b")
        XCTAssertEqual(fr1["name"] as? String, "echo")
        XCTAssertEqual((fr1["response"] as? [String: Any])?["result"] as? String, "A")
    }

    func testImagePartBecomesInlineData() throws {
        let request = ChatRequest(model: "m", system: nil, messages: [
            Message(role: .user, parts: [.text("look"), .image(data: Data([0xFF, 0xD8]), mimeType: "image/jpeg")]),
        ])
        let wire = try json(GeminiMapping.request(from: request))
        let parts = try XCTUnwrap((wire["contents"] as? [[String: Any]])?[0]["parts"] as? [[String: Any]])
        let inline = try XCTUnwrap(parts[1]["inlineData"] as? [String: Any])
        XCTAssertEqual(inline["mimeType"] as? String, "image/jpeg")
        XCTAssertEqual(inline["data"] as? String, Data([0xFF, 0xD8]).base64EncodedString())
    }

    func testThinkingConfigByModelFamily() throws {
        XCTAssertEqual(try json(GeminiMapping.generationConfig(model: "gemini-2.5-flash")!)["thinkingConfig"] as? [String: Int], ["thinkingBudget": 0])
        XCTAssertNil(GeminiMapping.generationConfig(model: "gemini-2.5-pro"))
        XCTAssertNil(GeminiMapping.generationConfig(model: "something-else"))
    }

    func testChunkWithTextAndFinishBecomesEvents() throws {
        let chunk = try JSONDecoder().decode(GeminiWire.Response.self, from: Data(#"""
        {"candidates":[{"content":{"parts":[{"text":"Hello"}],"role":"model"},"finishReason":"STOP","index":0}],"usageMetadata":{"totalTokenCount":3}}
        """#.utf8))
        XCTAssertEqual(GeminiMapping.events(from: chunk), [.textDelta("Hello"), .finished(.stop)])
    }

    func testChunkWithFunctionCallBecomesToolCallWithOpaqueSignature() throws {
        let chunk = try JSONDecoder().decode(GeminiWire.Response.self, from: Data(#"""
        {"candidates":[{"content":{"parts":[{"functionCall":{"id":"8f2b","name":"echo","args":{"text":"hi","n":2}},"thoughtSignature":"SIG"}],"role":"model"}}]}
        """#.utf8))
        let events = GeminiMapping.events(from: chunk)
        guard case .toolCall(let call)? = events.first else { return XCTFail("expected toolCall, got \(events)") }
        XCTAssertEqual(call.id, "8f2b")
        XCTAssertEqual(call.name, "echo")
        XCTAssertEqual(call.arguments, #"{"n":2,"text":"hi"}"#)
        XCTAssertEqual(call.opaque, "SIG")
    }

    func testFunctionCallWithoutIDGetsLocalID() throws {
        let chunk = try JSONDecoder().decode(GeminiWire.Response.self, from: Data(#"""
        {"candidates":[{"content":{"parts":[{"functionCall":{"name":"echo","args":{}}}]}}]}
        """#.utf8))
        guard case .toolCall(let call)? = GeminiMapping.events(from: chunk).first else { return XCTFail() }
        XCTAssertTrue(call.id.hasPrefix("local-"))
        XCTAssertEqual(call.arguments, "{}")
    }

    func testThoughtPartsAreSkippedAndBlockedPromptFinishesFiltered() throws {
        let thought = try JSONDecoder().decode(GeminiWire.Response.self, from: Data(#"""
        {"candidates":[{"content":{"parts":[{"text":"thinking...","thought":true}]}}]}
        """#.utf8))
        XCTAssertEqual(GeminiMapping.events(from: thought), [])
        let blocked = try JSONDecoder().decode(GeminiWire.Response.self, from: Data(#"""
        {"promptFeedback":{"blockReason":"SAFETY"}}
        """#.utf8))
        XCTAssertEqual(GeminiMapping.events(from: blocked), [.finished(.contentFiltered)])
    }

    func testErrorMapping() {
        let badKey = Data(#"{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT","details":[{"reason":"API_KEY_INVALID"}]}}"#.utf8)
        XCTAssertEqual(GeminiMapping.error(status: 400, body: badKey), .invalidKey)
        XCTAssertEqual(GeminiMapping.error(status: 403, body: Data(#"{"error":{"code":403,"message":"denied","status":"PERMISSION_DENIED"}}"#.utf8)), .invalidKey)
        XCTAssertEqual(GeminiMapping.error(status: 429, body: Data(#"{"error":{"code":429,"message":"quota","status":"RESOURCE_EXHAUSTED"}}"#.utf8)), .rateLimited)
        XCTAssertEqual(GeminiMapping.error(status: 404, body: Data(#"{"error":{"code":404,"message":"models/x is not found","status":"NOT_FOUND"}}"#.utf8)), .modelNotFound("models/x is not found"))
        XCTAssertEqual(GeminiMapping.error(status: 500, body: Data("not json".utf8)), .server(status: 500, message: "not json"))
        XCTAssertEqual(GeminiMapping.error(status: 400, body: Data(#"{"error":{"code":400,"message":"bad request","status":"INVALID_ARGUMENT"}}"#.utf8)), .server(status: 400, message: "bad request"))
    }

    func testModelListMapsAndFiltersGenerateContent() throws {
        let list = try JSONDecoder().decode(GeminiWire.ModelList.self, from: Data(#"""
        {"models":[{"name":"models/gemini-3.8-flash","displayName":"Gemini 3.8 Flash","supportedGenerationMethods":["generateContent"]},{"name":"models/embedding-1","displayName":"Embed","supportedGenerationMethods":["embedContent"]}],"nextPageToken":"t2"}
        """#.utf8))
        XCTAssertEqual(GeminiMapping.modelInfos(from: list), [ModelInfo(id: "gemini-3.8-flash", displayName: "Gemini 3.8 Flash")])
    }
}
