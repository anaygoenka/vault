//
//  WindowPresenter.swift
//  Vault
//
//  Settings and onboarding windows for a menu bar app. Vault has no Dock
//  icon, so it switches to a regular app while one of these is open (so it
//  can be ⌘-tabbed to) and back to an accessory once they all close.
//

import AppKit
import SwiftUI

final class WindowPresenter: NSObject, NSWindowDelegate {
    static let shared = WindowPresenter()

    private var windows: [String: NSWindow] = [:]

    func present<Content: View>(
        id: String,
        title: String,
        size: NSSize,
        hidesTitle: Bool = false,
        content: @autoclosure () -> Content
    ) {
        if let window = windows[id] {
            activate(window)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.identifier = NSUserInterfaceItemIdentifier(id)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = hidesTitle ? .hidden : .visible
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: content())
        window.setContentSize(size)
        window.center()
        window.delegate = self
        windows[id] = window
        activate(window)
    }

    func close(_ id: String) {
        windows[id]?.close()
    }

    private func activate(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              let id = window.identifier?.rawValue else { return }
        windows[id] = nil
        if windows.isEmpty {
            DispatchQueue.main.async { NSApp.setActivationPolicy(.accessory) }
        }
    }
}
