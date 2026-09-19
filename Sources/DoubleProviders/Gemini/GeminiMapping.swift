import Foundation

/// Pure translation between Double's types and Gemini's wire shapes.
/// No networking here, so every branch is unit-testable.
enum GeminiMapping {
    /// Ids we invented because Gemini sent none. Never sent back.
    static let localIDPrefix = "local-"

    static func request(from request: ChatRequest) throws -> GeminiWire.Request {
        var contents: [GeminiWire.Content] = []
        for message in request.messages {
            let content = try content(from: message)
            // Gemini requires alternating user/model turns; parallel tool results
            // and consecutive same-role messages merge into one content.
            if let last = contents.last, last.role == content.role {
                contents[contents.count - 1].parts.append(contentsOf: content.parts)
            } else {
                contents.append(content)
            }
        }
        var wire = GeminiWire.Request(contents: contents)
        if let system = request.system, !system.isEmpty {
            wire.systemInstruction = GeminiWire.Content(role: nil, parts: [GeminiWire.Part(text: system)])
        }
        if !request.tools.isEmpty {
            wire.tools = [GeminiWire.Tool(functionDeclarations: request.tools.map {
                GeminiWire.FunctionDeclaration(name: $0.name, description: $0.description, parametersJsonSchema: JSONValue.parse($0.parametersSchema))
            })]
            wire.toolConfig = GeminiWire.ToolConfig(functionCallingConfig: .init(mode: "AUTO"))
        }
        wire.generationConfig = generationConfig(model: request.model)
        return wire
    }

    private static func content(from message: Message) throws -> GeminiWire.Content {
        switch message.role {
        case .user:
            return GeminiWire.Content(role: "user", parts: message.parts.map(part(from:)))
        case .assistant:
            var parts = message.parts.map(part(from:))
            for call in message.toolCalls {
                var part = GeminiWire.Part(functionCall: GeminiWire.FunctionCall(
                    id: call.id.hasPrefix(localIDPrefix) ? nil : call.id,
                    name: call.name,
                    args: JSONValue.parse(call.arguments) ?? .object([:])
                ))
                part.thoughtSignature = call.opaque
                parts.append(part)
            }
            return GeminiWire.Content(role: "model", parts: parts)
        case .tool:
            guard let name = message.toolName else { throw ProviderError.malformedResponse("tool message without a tool name") }
            let id = message.toolCallID.flatMap { $0.hasPrefix(localIDPrefix) ? nil : $0 }
            let response = GeminiWire.FunctionResponse(id: id, name: name, response: .object(["result": .string(message.text)]))
            return GeminiWire.Content(role: "user", parts: [GeminiWire.Part(functionResponse: response)])
        }
    }

    private static func part(from part: ContentPart) -> GeminiWire.Part {
        switch part {
        case .text(let text):
            return GeminiWire.Part(text: text)
        case .image(let data, let mimeType):
            return GeminiWire.Part(inlineData: GeminiWire.InlineData(mimeType: mimeType, data: data.base64EncodedString()))
        }
    }

    /// Low thinking for chat latency. Gemini 3 takes `thinkingLevel`; 2.5 Flash
    /// takes `thinkingBudget` and 0 disables; 2.5 Pro cannot disable thinking.
    static func generationConfig(model: String) -> GeminiWire.GenerationConfig? {
        if model.hasPrefix("gemini-3") {
            return GeminiWire.GenerationConfig(thinkingConfig: .init(thinkingLevel: "low"))
        }
        if model.hasPrefix("gemini-2.5"), !model.contains("pro") {
            return GeminiWire.GenerationConfig(thinkingConfig: .init(thinkingBudget: 0))
        }
        return nil
    }

    static func events(from chunk: GeminiWire.Response) -> [StreamEvent] {
        var events: [StreamEvent] = []
        guard let candidate = chunk.candidates?.first else {
            if chunk.promptFeedback?.blockReason != nil { events.append(.finished(.contentFiltered)) }
            return events
        }
        for part in candidate.content?.parts ?? [] {
            if part.thought == true { continue }
            if let text = part.text, !text.isEmpty {
                events.append(.textDelta(text))
            }
            if let call = part.functionCall {
                events.append(.toolCall(ToolCall(
                    id: call.id ?? localIDPrefix + UUID().uuidString,
                    name: call.name,
                    arguments: (call.args ?? .object([:])).compactString,
                    opaque: part.thoughtSignature
                )))
            }
        }
        if let reason = candidate.finishReason {
            events.append(.finished(finishReason(reason)))
        }
        return events
    }

    private static func finishReason(_ raw: String) -> FinishReason {
        switch raw {
        case "STOP": return .stop
        case "MAX_TOKENS": return .maxTokens
        case "SAFETY", "RECITATION", "BLOCKLIST", "PROHIBITED_CONTENT", "SPII", "IMAGE_SAFETY", "IMAGE_PROHIBITED_CONTENT": return .contentFiltered
        default: return .other(raw)
        }
    }

    static func error(status: Int, body: Data) -> ProviderError {
        let envelope = try? JSONDecoder().decode(GeminiWire.ErrorEnvelope.self, from: body)
        let message = envelope?.error.message ?? String(decoding: body, as: UTF8.self)
        let reason = envelope?.error.details?.compactMap(\.reason).first
        switch status {
        case 400 where reason == "API_KEY_INVALID" || message.localizedCaseInsensitiveContains("API key not valid"):
            return .invalidKey
        case 401, 403: return .invalidKey
        case 404: return .modelNotFound(message)
        case 429: return .rateLimited
        default: return .server(status: status, message: message)
        }
    }

    static func modelInfos(from list: GeminiWire.ModelList) -> [ModelInfo] {
        (list.models ?? []).compactMap { model in
            guard model.supportedGenerationMethods?.contains("generateContent") == true else { return nil }
            let id = model.name.hasPrefix("models/") ? String(model.name.dropFirst("models/".count)) : model.name
            return ModelInfo(id: id, displayName: model.displayName ?? id)
        }
    }
}
