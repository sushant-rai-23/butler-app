import Foundation

enum GeminiFixtures {
    static func sse(_ chunks: [String]) -> Data {
        Data(chunks.map { "data: \($0)\r\n\r\n" }.joined().utf8)
    }

    static let streamedText = sse([
        #"{"candidates":[{"content":{"parts":[{"text":"Hello, "}],"role":"model"},"index":0}]}"#,
        #"{"candidates":[{"content":{"parts":[{"text":"sir."}],"role":"model"},"finishReason":"STOP","index":0}],"usageMetadata":{"promptTokenCount":4,"candidatesTokenCount":3,"totalTokenCount":7}}"#,
    ])

    static let singleToolCall = sse([
        #"{"candidates":[{"content":{"parts":[{"functionCall":{"id":"call-1","name":"echo","args":{"text":"hi"}},"thoughtSignature":"sig-1"}],"role":"model"},"finishReason":"STOP","index":0}]}"#,
    ])

    static let parallelToolCalls = sse([
        #"{"candidates":[{"content":{"parts":[{"functionCall":{"id":"c-a","name":"echo","args":{"text":"a"}},"thoughtSignature":"sig-a"},{"functionCall":{"id":"c-b","name":"echo","args":{"text":"b"}}}],"role":"model"},"finishReason":"STOP","index":0}]}"#,
    ])

    static let invalidKey = Data(#"{"error":{"code":400,"message":"API key not valid. Please pass a valid API key.","status":"INVALID_ARGUMENT","details":[{"@type":"type.googleapis.com/google.rpc.ErrorInfo","reason":"API_KEY_INVALID","domain":"googleapis.com"}]}}"#.utf8)
    static let rateLimited = Data(#"{"error":{"code":429,"message":"Resource has been exhausted","status":"RESOURCE_EXHAUSTED"}}"#.utf8)
    static let modelNotFound = Data(#"{"error":{"code":404,"message":"models/nope is not found for API version v1beta","status":"NOT_FOUND"}}"#.utf8)
    static let malformed = Data("data: {this is not json\r\n\r\n".utf8)

    static let modelsPage1 = Data(#"{"models":[{"name":"models/alpha","displayName":"Alpha","supportedGenerationMethods":["generateContent"]},{"name":"models/embed","displayName":"Embed","supportedGenerationMethods":["embedContent"]}],"nextPageToken":"page2"}"#.utf8)
    static let modelsPage2 = Data(#"{"models":[{"name":"models/beta","displayName":"Beta","supportedGenerationMethods":["generateContent"]}]}"#.utf8)
}
