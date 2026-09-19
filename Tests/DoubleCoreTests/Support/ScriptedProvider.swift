import DoubleProviders
import Foundation

/// Replays queued event lists, one per stream call, and records every request.
final class ScriptedProvider: ModelProvider, @unchecked Sendable {
    let id = "scripted"
    private let lock = NSLock()
    private var scripts: [[StreamEvent]]
    private(set) var requests: [ChatRequest] = []
    var failNext: Error?

    init(_ scripts: [[StreamEvent]]) { self.scripts = scripts }

    func listModels() async throws -> [ModelInfo] { [] }

    func stream(_ request: ChatRequest) -> AsyncThrowingStream<StreamEvent, Error> {
        lock.withLock { requests.append(request) }
        let events: [StreamEvent] = lock.withLock { scripts.isEmpty ? [.finished(.stop)] : scripts.removeFirst() }
        let failure = lock.withLock { let f = failNext; failNext = nil; return f }
        return AsyncThrowingStream { continuation in
            if let failure { continuation.finish(throwing: failure); return }
            for event in events { continuation.yield(event) }
            continuation.finish()
        }
    }
}
