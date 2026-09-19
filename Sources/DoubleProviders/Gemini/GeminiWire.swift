import Foundation

/// Gemini generateContent wire shapes (v1beta). Only the fields we use.
/// Reference: https://ai.google.dev/api/generate-content
enum GeminiWire {
    struct Request: Encodable {
        var contents: [Content]
        var systemInstruction: Content?
        var tools: [Tool]?
        var toolConfig: ToolConfig?
        var generationConfig: GenerationConfig?
    }

    struct Content: Codable {
        var role: String?
        var parts: [Part]
    }

    struct Part: Codable {
        var text: String?
        var inlineData: InlineData?
        var functionCall: FunctionCall?
        var functionResponse: FunctionResponse?
        var thoughtSignature: String?
        var thought: Bool?
    }

    struct InlineData: Codable {
        var mimeType: String
        var data: String
    }

    struct FunctionCall: Codable {
        var id: String?
        var name: String
        var args: JSONValue?
    }

    struct FunctionResponse: Codable {
        var id: String?
        var name: String
        var response: JSONValue
    }

    struct Tool: Encodable {
        var functionDeclarations: [FunctionDeclaration]
    }

    struct FunctionDeclaration: Encodable {
        var name: String
        var description: String
        var parametersJsonSchema: JSONValue?
    }

    struct ToolConfig: Encodable {
        struct FunctionCallingConfig: Encodable { var mode: String }
        var functionCallingConfig: FunctionCallingConfig
    }

    struct GenerationConfig: Encodable {
        struct ThinkingConfig: Encodable {
            var thinkingLevel: String?
            var thinkingBudget: Int?
        }
        var thinkingConfig: ThinkingConfig?
    }

    struct Response: Decodable {
        struct Candidate: Decodable {
            var content: Content?
            var finishReason: String?
        }
        struct PromptFeedback: Decodable { var blockReason: String? }
        var candidates: [Candidate]?
        var promptFeedback: PromptFeedback?
    }

    struct ErrorEnvelope: Decodable {
        struct Body: Decodable {
            struct Detail: Decodable { var reason: String? }
            var code: Int
            var message: String
            var status: String
            var details: [Detail]?
        }
        var error: Body
    }

    struct ModelList: Decodable {
        struct Model: Decodable {
            var name: String
            var displayName: String?
            var supportedGenerationMethods: [String]?
        }
        var models: [Model]?
        var nextPageToken: String?
    }
}
