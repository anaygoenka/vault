//
//  HotKeyCenter.swift
//  Vault
//
//  The global shortcut (⇧⌘V by default). Carbon's RegisterEventHotKey is
//  still the only global-shortcut API that needs no privacy permission, so
//  the panel opens even before Accessibility is granted.
//

import AppKit
import Carbon.HIToolbox
import Observation

@Observable
final class HotKeyCenter {
    static let shared = HotKeyCenter()

    @ObservationIgnored private var hotKeyRef: EventHotKeyRef?
    @ObservationIgnored private var handlerRef: EventHandlerRef?
    @ObservationIgnored private var action: (() -> Void)?
    private(set) var registrationFailed = false

    private init() {}

    /// Registers `combo`, replacing any previous shortcut. Returns false if
    /// another app already owns it.
    @discardableResult
    func register(_ combo: HotKeyCombo, action: @escaping () -> Void) -> Bool {
        self.action = action
        installHandlerIfNeeded()
        unregister()

        let id = EventHotKeyID(signature: OSType(0x5641_4C54), id: 1) // "VALT"
        let status = RegisterEventHotKey(combo.keyCode, combo.modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        registrationFailed = status != noErr
        return !registrationFailed
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    /// Temporarily releases the shortcut, so the recorder in Settings can
    /// capture the current combination as a plain key press.
    func suspend() { unregister() }

    func resume() {
        guard let action else { return }
        register(AppSettings.shared.hotKey, action: action)
    }

    fileprivate func fire() { action?() }

    private func installHandlerIfNeeded() {
        guard handlerRef == nil else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            // Carbon delivers hot keys on the main thread.
            MainActor.assumeIsolated { HotKeyCenter.shared.fire() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
    }
}

extension HotKeyCombo {
    /// Builds a combo from a key press, or nil if it has no modifier that
    /// makes it safe as a global shortcut.
    init?(event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var carbon: UInt32 = 0
        if flags.contains(.command) { carbon |= UInt32(cmdKey) }
        if flags.contains(.option) { carbon |= UInt32(optionKey) }
        if flags.contains(.control) { carbon |= UInt32(controlKey) }
        if flags.contains(.shift) { carbon |= UInt32(shiftKey) }
        guard carbon & UInt32(cmdKey | optionKey | controlKey) != 0 else { return nil }

        let label = Self.label(for: event.keyCode)
            ?? event.charactersIgnoringModifiers?.uppercased()
            ?? "?"
        self.init(keyCode: UInt32(event.keyCode), modifiers: carbon, keyLabel: label)
    }

    private static func label(for keyCode: UInt16) -> String? {
        switch Int(keyCode) {
        case kVK_Space: "Space"
        case kVK_Return: "↩"
        case kVK_Tab: "⇥"
        case kVK_Delete: "⌫"
        case kVK_ForwardDelete: "⌦"
        case kVK_Escape: "⎋"
        case kVK_LeftArrow: "←"
        case kVK_RightArrow: "→"
        case kVK_UpArrow: "↑"
        case kVK_DownArrow: "↓"
        case kVK_F1: "F1"
        case kVK_F2: "F2"
        case kVK_F3: "F3"
        case kVK_F4: "F4"
        case kVK_F5: "F5"
        case kVK_F6: "F6"
        case kVK_F7: "F7"
        case kVK_F8: "F8"
        case kVK_F9: "F9"
        case kVK_F10: "F10"
        case kVK_F11: "F11"
        case kVK_F12: "F12"
        default: nil
        }
    }
}
