import AppKit
import SwiftUI

/// The panel's input. SwiftUI TextField by default; the AppKit field behind
/// the Settings toggle claims first responder directly if SwiftUI focus
/// fails on some macOS build. Return sends, Escape closes.
struct ChatInputField: View {
    @Binding var text: String
    var useAppKit: Bool
    var onSubmit: () -> Void
    var onEscape: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        if useAppKit {
            AppKitInputField(text: $text, onSubmit: onSubmit, onEscape: onEscape)
                .frame(minHeight: 22)
        } else {
            TextField("Talk to Butler…", text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($focused)
                .onSubmit(onSubmit)
                .onExitCommand(perform: onEscape)
                .task { focused = true }
        }
    }
}

struct AppKitInputField: NSViewRepresentable {
    @Binding var text: String
    var onSubmit: () -> Void
    var onEscape: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.placeholderString = "Talk to Butler…"
        field.isBordered = false
        field.focusRingType = .none
        field.backgroundColor = .clear
        field.delegate = context.coordinator
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text { field.stringValue = text }
        if let window = field.window, window.isKeyWindow, window.firstResponder !== field.currentEditor() {
            DispatchQueue.main.async { window.makeFirstResponder(field) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: AppKitInputField
        init(_ parent: AppKitInputField) { self.parent = parent }

        func controlTextDidChange(_ notification: Notification) {
            parent.text = (notification.object as? NSTextField)?.stringValue ?? ""
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.cancelOperation(_:)): parent.onEscape(); return true
            case #selector(NSResponder.insertNewline(_:)): parent.onSubmit(); return true
            default: return false
            }
        }
    }
}
