import DoubleProviders
import SwiftUI

struct RootView: View {
    let model: AppModel
    var onOpenSettings: () -> Void
    var onClose: () -> Void

    var body: some View {
        switch model.screen {
        case .onboarding:
            OnboardingView(model: model, onClose: onClose)
        case .keyEntry:
            KeyEntryView(descriptor: model.settings.providerDescriptor, onSave: model.saveKey, onClose: onClose)
        case .chat:
            ChatView(session: model.session, settings: model.settings, onOpenSettings: onOpenSettings, onClose: onClose)
        }
    }
}

struct OnboardingView: View {
    private static let questions = [
        "What should I call you, sir?",
        "What do you do, in a line or two?",
        "What hours are you usually working?",
        "Which apps or sites are always work for you?",
        "What helps most when you are stuck?",
    ]
    @Bindable var model: AppModel
    var onClose: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        let step = model.onboarding.step
        VStack(alignment: .leading, spacing: 12) {
            Text("Double").font(.title2.bold())
            Text("Five questions, then we work.").foregroundStyle(.secondary)
            Spacer().frame(height: 12)
            Text("\(step + 1) of \(Self.questions.count)").font(.caption).foregroundStyle(.secondary)
            Text(Self.questions[step]).font(.headline)
            TextField("", text: $model.onboarding.answers[step])
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(next)
                .onExitCommand(perform: onClose)
            HStack {
                if step > 0 { Button("Back") { model.onboarding.step -= 1 } }
                Spacer()
                Button(step == Self.questions.count - 1 ? "Done" : "Next", action: next)
                    .keyboardShortcut(.defaultAction)
                    .disabled(model.onboarding.answers[step].trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Spacer()
        }
        .padding(20).padding(.top, 20)
        .frame(width: FloatingPanel.contentSize.width, height: FloatingPanel.contentSize.height)
        .task { focused = true }
    }

    private func next() {
        guard !model.onboarding.answers[model.onboarding.step].trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if model.onboarding.step < Self.questions.count - 1 {
            model.onboarding.step += 1
        } else {
            model.finishOnboarding()
        }
    }
}

struct KeyEntryView: View {
    let descriptor: ProviderDescriptor
    var onSave: (String) -> Void
    var onClose: () -> Void
    @State private var key = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("One more thing, sir.").font(.title2.bold())
            Text("Paste your \(descriptor.displayName) key. It goes to the macOS Keychain and nowhere else.").foregroundStyle(.secondary)
            SecureField("API key", text: $key)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(save)
                .onExitCommand(perform: onClose)
            HStack {
                Link("Get a key", destination: descriptor.keyHelpURL)
                Spacer()
                Button("Save", action: save).keyboardShortcut(.defaultAction).disabled(key.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            Spacer()
        }
        .padding(20).padding(.top, 20)
        .frame(width: FloatingPanel.contentSize.width, height: FloatingPanel.contentSize.height)
        .task { focused = true }
    }

    private func save() {
        guard !key.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        onSave(key)
    }
}
