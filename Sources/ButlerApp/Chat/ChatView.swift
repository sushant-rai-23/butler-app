import SwiftUI

struct ChatView: View {
    let session: ChatSession
    let settings: AppSettings
    var onOpenSettings: () -> Void
    var onClose: () -> Void
    @State private var draft = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Butler").font(.headline)
                // The model actually used for the next message, read from the
                // same setting `ChatSession.send` reads.
                Text(settings.chatModel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .help("Model used for the next message")
                Spacer()
                Button { session.clear() } label: { Image(systemName: "trash") }
                    .buttonStyle(.plain).help("Clear this conversation")
                Button { onOpenSettings() } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.plain).help("Settings")
            }
            .padding(.horizontal, 16).padding(.top, 28).padding(.bottom, 8)
            Divider()
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        if session.messages.isEmpty {
                            Text("At your service, sir.").foregroundStyle(.secondary)
                        }
                        ForEach(session.messages) { message in
                            bubble(message).id(message.id)
                        }
                        if let error = session.errorText {
                            Text(error).font(.caption).foregroundStyle(.red)
                        }
                    }
                    .padding(16)
                }
                .onChange(of: session.messages) { _, messages in
                    if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            Divider()
            ChatInputField(text: $draft, useAppKit: settings.useAppKitInputField, onSubmit: send, onEscape: onClose)
                .padding(12)
        }
        .frame(width: FloatingPanel.contentSize.width, height: FloatingPanel.contentSize.height)
    }

    private func send() {
        let text = draft
        draft = ""
        session.send(text)
    }

    @ViewBuilder
    private func bubble(_ message: ChatMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text.isEmpty && session.isStreaming ? "…" : message.text)
                .textSelection(.enabled)
                .padding(10)
                .background(message.role == .user ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            if message.role != .user { Spacer(minLength: 40) }
        }
    }
}
