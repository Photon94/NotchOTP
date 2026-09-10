import AppKit
import Carbon
import SwiftUI

struct Shortcut: Codable {
    var keyCode: UInt32
    var modifiers: UInt32
    var keyLabel: String
    static let standard = Shortcut(keyCode: 49, modifiers: UInt32(controlKey | optionKey), keyLabel: "Space")
    var label: String {
        (modifiers & UInt32(controlKey) != 0 ? "⌃" : "") +
        (modifiers & UInt32(optionKey) != 0 ? "⌥" : "") +
        (modifiers & UInt32(shiftKey) != 0 ? "⇧" : "") +
        (modifiers & UInt32(cmdKey) != 0 ? "⌘" : "") + keyLabel
    }
    static func from(_ event: NSEvent) -> Shortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard !flags.intersection([.command, .control, .option]).isEmpty,
              ![36, 48, 51, 53, 123, 124, 125, 126].contains(Int(event.keyCode)) else { return nil }
        var modifiers: UInt32 = 0
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        let label = event.keyCode == 49 ? "Space" : (event.charactersIgnoringModifiers ?? "").uppercased()
        guard !label.isEmpty else { return nil }
        return Shortcut(keyCode: UInt32(event.keyCode), modifiers: modifiers, keyLabel: label)
    }
}

final class GlobalHotKey {
    private var reference: EventHotKeyRef?
    private var handler: EventHandlerRef?
    var action: (() -> Void)?
    init() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let object = Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue()
            object.action?()
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func register(_ shortcut: Shortcut) -> Bool {
        // Register replacement first: a conflict must leave the old shortcut working.
        var newReference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: 0x4E4F5450, id: 1)
        let status = RegisterEventHotKey(shortcut.keyCode, shortcut.modifiers, identifier,
                                        GetApplicationEventTarget(), 0, &newReference)
        guard status == noErr else { return false }
        if let reference { UnregisterEventHotKey(reference) }
        reference = newReference
        return true
    }
    deinit {
        if let reference { UnregisterEventHotKey(reference) }
        if let handler { RemoveEventHandler(handler) }
    }
}

struct ShortcutRecorder: NSViewRepresentable {
    let label: String
    let onRecord: (Shortcut) -> Void
    func makeNSView(context: Context) -> RecorderButton {
        let button = RecorderButton()
        button.onRecord = onRecord
        button.target = button
        button.action = #selector(RecorderButton.beginRecording)
        button.bezelStyle = .rounded
        button.title = label
        return button
    }
    func updateNSView(_ view: RecorderButton, context: Context) {
        view.savedLabel = label
        if !view.recording { view.title = label }
    }
}

final class RecorderButton: NSButton {
    var onRecord: ((Shortcut) -> Void)?
    var savedLabel = ""
    var recording = false
    override var acceptsFirstResponder: Bool { true }
    @objc func beginRecording() {
        recording = true
        title = "Нажмите сочетание…"
        window?.makeFirstResponder(self)
    }
    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        if event.keyCode == 53 { recording = false; title = savedLabel; return }
        if let shortcut = Shortcut.from(event) {
            recording = false
            onRecord?(shortcut)
            title = savedLabel
        } else { NSSound.beep() }
    }
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if recording { keyDown(with: event); return true }
        return super.performKeyEquivalent(with: event)
    }
    override func resignFirstResponder() -> Bool {
        recording = false; title = savedLabel
        return super.resignFirstResponder()
    }
}
