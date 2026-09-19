import Foundation

public enum ProviderError: Error, Equatable, Sendable {
    case missingKey
    case invalidKey
    case rateLimited
    case modelNotFound(String)
    case network(String)
    case server(status: Int, message: String)
    case malformedResponse(String)
}

extension ProviderError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .missingKey: return "No API key is saved. Open Settings and paste one."
        case .invalidKey: return "The API key was rejected."
        case .rateLimited: return "Rate limited. Wait a moment, or pick a model with more headroom."
        case .modelNotFound(let model): return "Model \(model) was not found."
        case .network(let detail): return "Network error: \(detail)"
        case .server(let status, let message): return "Server error \(status): \(message)"
        case .malformedResponse(let detail): return "Unexpected response: \(detail)"
        }
    }
}
