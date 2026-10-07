//
//  MenuBarContent.swift
//  Vault
//
//  The menu under the menu bar icon: open the panel, paste one of the
//  latest clips, pause recording, and the usual app items.
//

import SwiftUI

struct MenuBarContent: View {
    private let store = HistoryStore.shared
    private let settings = AppSettings.shared

    var body: some View {
        Button("Open Vault") { PanelController.shared.show() }
            .keyboardShortcut(openShortcut)

        let recent = Array(store.items.prefix(6))
        if !recent.isEmpty {
            Divider()
            Section("Recent") {
                ForEach(Array(recent.enumerated()), id: \.element.id) { index, item in
                    Button {
                        // The menu closes first, which hands focus back to
                        // the app that was in front.
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            if PasteService.paste(item, plainText: settings.plainTextByDefault) == .copied {
                                HUD.show("Copied", detail: "Press ⌘V to paste", symbol: "doc.on.clipboard")
                            }
                        }
                    } label: {
                        Label(menuTitle(item), systemImage: item.isPinned ? "pin" : item.kind.symbol)
                    }
                    .keyboardShortcut(KeyEquivalent(Character("\(index + 1)")), modifiers: .command)
                }
            }
        }

        Divider()
        if settings.isPaused {
            Button("Resume Recording", systemImage: "play.fill") { settings.pausedUntil = nil }
            if let until = settings.pausedUntil, until < .distantFuture.addingTimeInterval(-1) {
                Text("Paused until \(until.formatted(date: .omitted, time: .shortened))")
            }
        } else {
            Menu("Pause Recording", systemImage: "pause") {
                Button("For 5 Minutes") { pause(minutes: 5) }
                Button("For 15 Minutes") { pause(minutes: 15) }
                Button("For 1 Hour") { pause(minutes: 60) }
                Divider()
                Button("Until I Resume") { settings.pausedUntil = .distantFuture }
            }
        }
        Button("Clear History…", systemImage: "trash") { confirmClear() }
            .disabled(store.items.allSatisfy(\.isPinned))

        Divider()
        Button("Settings…") { AppDelegate.openSettings() }
            .keyboardShortcut(",")
        Button("About Vault") {
            NSApp.activate()
            NSApp.orderFrontStandardAboutPanel(nil)
        }
        Button("Quit Vault") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// The global shortcut, shown beside "Open Vault" when it is a single
    /// character the menu can draw.
    private var openShortcut: KeyboardShortcut? {
        let label = settings.hotKey.keyLabel
        guard label.count == 1, let char = label.lowercased().first else { return nil }
        return KeyboardShortcut(KeyEquivalent(char), modifiers: modifiers)
    }

    private var modifiers: EventModifiers {
        let m = settings.hotKey.modifiers
        var result: EventModifiers = []
        if m & 256 != 0 { result.insert(.command) }   // cmdKey
        if m & 512 != 0 { result.insert(.shift) }     // shiftKey
        if m & 2048 != 0 { result.insert(.option) }   // optionKey
        if m & 4096 != 0 { result.insert(.control) }  // controlKey
        return result
    }

    private func menuTitle(_ item: ClipItem) -> String {
        let title = item.title
        return title.count > 42 ? String(title.prefix(40)) + "…" : title
    }

    private func pause(minutes: Double) {
        settings.pausedUntil = .now.addingTimeInterval(minutes * 60)
    }

    static func confirmClearAlert() -> Bool {
        NSApp.activate()
        let alert = NSAlert()
        alert.messageText = "Clear your clipboard history?"
        alert.informativeText = "Every clip except pinned ones will be deleted. This cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Clear History").hasDestructiveAction = true
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    private func confirmClear() {
        if Self.confirmClearAlert() { store.clear() }
    }
}
