import DoubleCore
import DoubleProviders
import Foundation
import Observation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    var role: Message.Role
    var text: String
}

/// This session's transcript for the panel. Survives panel open/close; is
/// cleared on `clear()` or app quit.
@MainActor
@Observable
final class ChatSession {
    private(set) var messages: [ChatMessage] = []
    private(set) var isStreaming = false
    private(set) var errorText: String?
    @ObservationIgnored private let loop: any AgentLoop
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var currentTurn: Task<Void, Never>?

    init(loop: any AgentLoop, settings: AppSettings) {
        self.loop = loop
        self.settings = settings
    }

    func send(_ input: String) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }
        messages.append(ChatMessage(role: .user, text: text))
        messages.append(ChatMessage(role: .assistant, text: ""))
        let replyID = messages[messages.count - 1].id
        isStreaming = true
        errorText = nil
        let model = settings.chatModel
        // Deltas arrive on the provider's thread; a stream keeps them in order
        // and hands them to the main actor one at a time.
        let (deltas, continuation) = AsyncStream<String>.makeStream()
        let consumer = Task { @MainActor [weak self] in
            for await delta in deltas { self?.append(delta, to: replyID) }
        }
        currentTurn = Task {
            do {
                _ = try await loop.send(text, model: model, maximumRisk: .medium) { delta in
                    continuation.yield(delta)
                }
            } catch {
                errorText = error.localizedDescription
            }
            continuation.finish()
            await consumer.value
            if let index = messages.firstIndex(where: { $0.id == replyID }), messages[index].text.isEmpty {
                messages.remove(at: index)
            }
            isStreaming = false
        }
    }

    /// Waits for an in-flight turn. Used by tests.
    func awaitCurrentTurn() async {
        await currentTurn?.value
    }

    /// Ignored while a reply is streaming: resetting the loop mid-turn would
    /// leave an orphaned assistant turn at the head of the new history.
    func clear() {
        guard !isStreaming else { return }
        messages.removeAll()
        errorText = nil
        Task { await loop.reset() }
    }

    private func append(_ delta: String, to id: UUID) {
        guard let index = messages.firstIndex(where: { $0.id == id }) else { return }
        messages[index].text += delta
    }
}
