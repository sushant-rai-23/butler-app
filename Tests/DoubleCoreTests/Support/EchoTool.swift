import Foundation
import DoubleTools

/// Test-only tool: returns the "text" argument. Never registered in the app.
struct EchoTool: Tool {
    var name: String { "echo" }
    var description: String { "Returns the text you give it." }
    var parametersSchema: String { #"{"type":"object","properties":{"text":{"type":"string"}},"required":["text"]}"# }
    var risk: RiskLevel = .low

    func invoke(arguments: String) async throws -> String {
        let data = Data(arguments.utf8)
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        return object?["text"] as? String ?? ""
    }
}
