import XCTest
@testable import DoubleProviders

final class GeminiProviderTests: XCTestCase {
    private var keychain: InMemoryKeychainStore!

    override func setUp() {
        super.setUp()
        FakeURLProtocol.reset()
        keychain = InMemoryKeychainStore()
        try? keychain.set("test-key", for: GeminiProvider.keychainKey)
    }

    private func makeProvider() -> GeminiProvider {
        GeminiProvider(keychain: keychain, session: FakeURLProtocol.makeSession())
    }

    private var request: ChatRequest {
        ChatRequest(model: "gemini-3.8-flash", system: "Jarvis", messages: [Message(role: .user, text: "hi")])
    }

    func testStreamedText() async throws {
        FakeURLProtocol.respond(with: [(200, GeminiFixtures.streamedText)])
        try await ProviderContract.streamedText(makeProvider(), request: request)
    }

    func testSingleToolCall() async throws {
        FakeURLProtocol.respond(with: [(200, GeminiFixtures.singleToolCall)])
        _ = try await ProviderContract.singleToolCall(makeProvider(), request: request)
    }

    func testParallelToolCalls() async throws {
        FakeURLProtocol.respond(with: [(200, GeminiFixtures.parallelToolCalls)])
        try await ProviderContract.parallelToolCalls(makeProvider(), request: request)
    }

    func testInvalidKey() async {
        FakeURLProtocol.respond(with: [(400, GeminiFixtures.invalidKey)])
        await ProviderContract.fails(makeProvider(), request: request, with: .invalidKey)
    }

    func testRateLimited() async {
        FakeURLProtocol.respond(with: [(429, GeminiFixtures.rateLimited)])
        await ProviderContract.fails(makeProvider(), request: request, with: .rateLimited)
    }

    func testModelNotFound() async {
        FakeURLProtocol.respond(with: [(404, GeminiFixtures.modelNotFound)])
        await ProviderContract.fails(makeProvider(), request: request, with: .modelNotFound("models/nope is not found for API version v1beta"))
    }

    func testMalformedChunk() async {
        FakeURLProtocol.respond(with: [(200, GeminiFixtures.malformed)])
        await ProviderContract.failsMalformed(makeProvider(), request: request)
    }

    func testMissingKey() async {
        try? keychain.delete(GeminiProvider.keychainKey)
        await ProviderContract.missingKey(makeProvider(), request: request)
        XCTAssertTrue(FakeURLProtocol.recorded.isEmpty, "no request is sent without a key")
    }

    func testListModelsAcrossPages() async throws {
        FakeURLProtocol.respond(with: [(200, GeminiFixtures.modelsPage1), (200, GeminiFixtures.modelsPage2)])
        try await ProviderContract.listsModelsAcrossPages(makeProvider())
        let urls = FakeURLProtocol.recorded.map { $0.request.url!.absoluteString }
        XCTAssertTrue(urls[1].contains("pageToken=page2"), urls[1])
    }

    func testRequestShapeAndHeaders() async throws {
        FakeURLProtocol.respond(with: [(200, GeminiFixtures.streamedText)])
        _ = try await makeProvider().complete(request)
        let recorded = try XCTUnwrap(FakeURLProtocol.recorded.first)
        let url = recorded.request.url!.absoluteString
        XCTAssertEqual(url, "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.8-flash:streamGenerateContent?alt=sse")
        XCTAssertEqual(recorded.request.value(forHTTPHeaderField: "x-goog-api-key"), "test-key")
        XCTAssertEqual(recorded.request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertFalse(url.contains("test-key"), "key never goes in the URL")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: recorded.body) as? [String: Any])
        XCTAssertNotNil(body["contents"])
        XCTAssertNotNil(body["systemInstruction"])
    }

    func testToolResultRoundTripEchoesIDAndSignature() async throws {
        FakeURLProtocol.respond(with: [(200, GeminiFixtures.singleToolCall), (200, GeminiFixtures.streamedText)])
        let provider = makeProvider()
        let call = try await ProviderContract.singleToolCall(provider, request: request)
        var followUp = request
        followUp.messages += [Message(role: .assistant, parts: [], toolCalls: [call]), .toolResult(for: call, content: "hi back")]
        _ = try await provider.complete(followUp)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: FakeURLProtocol.recorded[1].body) as? [String: Any])
        let contents = try XCTUnwrap(body["contents"] as? [[String: Any]])
        let modelParts = try XCTUnwrap(contents[1]["parts"] as? [[String: Any]])
        XCTAssertEqual(modelParts[0]["thoughtSignature"] as? String, "sig-1")
        XCTAssertEqual((modelParts[0]["functionCall"] as? [String: Any])?["id"] as? String, "call-1")
        let response = try XCTUnwrap((contents[2]["parts"] as? [[String: Any]])?[0]["functionResponse"] as? [String: Any])
        XCTAssertEqual(response["id"] as? String, "call-1")
    }

    func testCatalogBuildsGeminiWithoutNamingIt() {
        let descriptor = ProviderCatalog.defaultProvider
        XCTAssertEqual(descriptor.id, "gemini")
        XCTAssertEqual(descriptor.defaultModel, "gemini-3.8-flash")
        XCTAssertNotNil(ProviderCatalog.makeProvider(id: "gemini", keychain: keychain))
        XCTAssertNil(ProviderCatalog.makeProvider(id: "nope", keychain: keychain))
    }
}
