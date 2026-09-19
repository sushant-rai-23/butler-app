import Foundation
import XCTest
@testable import DoubleProviders

/// The behaviours every adapter must show. Each adapter's test file supplies
/// wire fixtures for these scenarios and calls the matching function.
/// Phase 4 adapters reuse this file unchanged.
enum ProviderContract {
    /// Fixture yields the text "Hello, sir." across at least two deltas, then finished(.stop).
    static func streamedText(_ provider: any ModelProvider, request: ChatRequest, file: StaticString = #filePath, line: UInt = #line) async throws {
        var deltas: [String] = []
        var finish: FinishReason?
        for try await event in provider.stream(request) {
            switch event {
            case .textDelta(let d): deltas.append(d)
            case .toolCall(let c): XCTFail("unexpected tool call \(c)", file: file, line: line)
            case .finished(let r): finish = r
            }
        }
        XCTAssertGreaterThanOrEqual(deltas.count, 2, "expected streaming in more than one delta", file: file, line: line)
        XCTAssertEqual(deltas.joined(), "Hello, sir.", file: file, line: line)
        XCTAssertEqual(finish, .stop, file: file, line: line)
    }

    /// Fixture yields one tool call: name "echo", arguments {"text":"hi"}, id "call-1", opaque "sig-1".
    static func singleToolCall(_ provider: any ModelProvider, request: ChatRequest, file: StaticString = #filePath, line: UInt = #line) async throws -> ToolCall {
        let message = try await provider.complete(request)
        XCTAssertEqual(message.toolCalls.count, 1, file: file, line: line)
        let call = try XCTUnwrap(message.toolCalls.first, file: file, line: line)
        XCTAssertEqual(call.name, "echo", file: file, line: line)
        XCTAssertEqual(call.arguments, #"{"text":"hi"}"#, file: file, line: line)
        XCTAssertEqual(call.id, "call-1", file: file, line: line)
        XCTAssertEqual(call.opaque, "sig-1", file: file, line: line)
        return call
    }

    /// Fixture yields two tool calls named "echo" with arguments {"text":"a"} and {"text":"b"}.
    static func parallelToolCalls(_ provider: any ModelProvider, request: ChatRequest, file: StaticString = #filePath, line: UInt = #line) async throws {
        let message = try await provider.complete(request)
        XCTAssertEqual(message.toolCalls.map(\.arguments), [#"{"text":"a"}"#, #"{"text":"b"}"#], file: file, line: line)
    }

    static func fails(_ provider: any ModelProvider, request: ChatRequest, with expected: ProviderError, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await provider.complete(request)
            XCTFail("expected \(expected)", file: file, line: line)
        } catch let error as ProviderError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("expected ProviderError, got \(error)", file: file, line: line)
        }
    }

    static func failsMalformed(_ provider: any ModelProvider, request: ChatRequest, file: StaticString = #filePath, line: UInt = #line) async {
        do {
            _ = try await provider.complete(request)
            XCTFail("expected malformedResponse", file: file, line: line)
        } catch let error as ProviderError {
            guard case .malformedResponse = error else { return XCTFail("expected malformedResponse, got \(error)", file: file, line: line) }
        } catch {
            XCTFail("expected ProviderError, got \(error)", file: file, line: line)
        }
    }

    /// Fixtures: two pages. Expect ids ["alpha", "beta"] in order.
    static func listsModelsAcrossPages(_ provider: any ModelProvider, file: StaticString = #filePath, line: UInt = #line) async throws {
        let models = try await provider.listModels()
        XCTAssertEqual(models.map(\.id), ["alpha", "beta"], file: file, line: line)
    }

    static func missingKey(_ provider: any ModelProvider, request: ChatRequest, file: StaticString = #filePath, line: UInt = #line) async {
        await fails(provider, request: request, with: .missingKey, file: file, line: line)
    }
}
