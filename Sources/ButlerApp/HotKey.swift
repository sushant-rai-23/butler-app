import Carbon.HIToolbox
import Foundation

/// A global hotkey via Carbon `RegisterEventHotKey`. Needs no Accessibility
/// or Input Monitoring permission and works from an unsigned build. The
/// handler runs on the main thread.
final class HotKey {
    private static let signature: OSType = 0x4A525653 // "JRVS"
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let handler: () -> Void

    init(keyCode: UInt32, modifiers: UInt32, handler: @escaping () -> Void) {
        self.handler = handler
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let userData = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetEventDispatcherTarget(), { _, event, userData in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard id.signature == HotKey.signature, let userData else { return OSStatus(eventNotHandledErr) }
            Unmanaged<HotKey>.fromOpaque(userData).takeUnretainedValue().handler()
            return noErr
        }, 1, &spec, userData, &handlerRef)
        let id = EventHotKeyID(signature: HotKey.signature, id: 1)
        RegisterEventHotKey(keyCode, modifiers, id, GetEventDispatcherTarget(), 0, &hotKeyRef)
    }

    static func commandShiftSpace(handler: @escaping () -> Void) -> HotKey {
        HotKey(keyCode: UInt32(kVK_Space), modifiers: UInt32(cmdKey | shiftKey), handler: handler)
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }
}
