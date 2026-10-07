//
//  PanelController.swift
//  Vault
//
//  The floating glass panel. It is a non-activating panel, so the app you
//  were typing in stays frontmost while you choose: the paste lands back in
//  it without any window shuffling.
//

import AppKit
import Carbon.HIToolbox
import SwiftUI

final class VaultPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

final class PanelController: NSObject, NSWindowDelegate {
    static let shared = PanelController()

    let model = PanelModel()
    private var panel: VaultPanel?
    private var keyMonitor: Any?
    private var clickMonitor: Any?

    static let size = NSSize(width: 800, height: 520)

    var isVisible: Bool { panel?.isVisible ?? false }
    var window: NSWindow? { panel }

    override private init() {
        super.init()
        model.onDismiss = { [weak self] in self?.hide() }
    }

    func toggle() {
        isVisible ? hide() : show()
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel
        model.prepareForPresentation()
        position(panel)

        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.14
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }
        installMonitors()
    }

    #if DEBUG
    /// Shows the panel for a screenshot without taking focus, at `level`.
    func showForCapture(level: NSWindow.Level) {
        let panel = panel ?? makePanel()
        self.panel = panel
        panel.delegate = nil
        model.prepareForPresentation()
        position(panel)
        panel.level = level
        panel.alphaValue = 1
        panel.orderFrontRegardless()
    }
    #endif

    func hide() {
        guard let panel, panel.isVisible else { return }
        removeMonitors()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.1
            panel.animator().alphaValue = 0
        } completionHandler: {
            MainActor.assumeIsolated { panel.orderOut(nil) }
        }
    }

    // MARK: - NSWindowDelegate

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    // MARK: - Private

    private func makePanel() -> VaultPanel {
        let panel = VaultPanel(
            contentRect: NSRect(origin: .zero, size: Self.size),
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .utilityWindow
        panel.delegate = self
        panel.identifier = NSUserInterfaceItemIdentifier("panel")

        let glass = NSGlassEffectView()
        glass.cornerRadius = 26
        glass.style = .regular
        let hosting = NSHostingView(rootView: HistoryPanelView(model: model))
        hosting.sizingOptions = []
        glass.contentView = hosting
        panel.contentView = glass
        return panel
    }

    private func position(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = Self.size
        let origin = NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.midY - size.height / 2 + frame.height * 0.08
        )
        panel.setFrame(NSRect(origin: origin, size: size), display: false)
    }

    private func installMonitors() {
        removeMonitors()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, event.window === self.panel else { return event }
            return self.handle(event) ? nil : event
        }
        // Clicks in other apps do not always take key status away from a
        // non-activating panel, so close on any outside click too.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.hide() }
        }
    }

    private func removeMonitors() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
        keyMonitor = nil
        clickMonitor = nil
    }

    /// Returns true when the key was handled and should not reach the
    /// search field.
    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let command = flags.contains(.command)

        switch Int(event.keyCode) {
        case kVK_Escape:
            if !model.query.isEmpty { model.query = "" } else if model.filter != .all { model.filter = .all } else { hide() }
            return true
        case kVK_DownArrow:
            command ? model.moveToEnd(true) : model.move(1)
            return true
        case kVK_UpArrow:
            command ? model.moveToEnd(false) : model.move(-1)
            return true
        case kVK_PageDown:
            model.move(8); return true
        case kVK_PageUp:
            model.move(-8); return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if flags.contains(.option) { model.copyOnly() } else { model.paste(invertPlain: flags.contains(.shift)) }
            return true
        case kVK_Tab:
            model.cycleFilter(flags.contains(.shift) ? -1 : 1)
            return true
        default:
            break
        }

        guard command, let chars = event.charactersIgnoringModifiers?.lowercased() else { return false }
        if let digit = Int(chars), (1...9).contains(digit) {
            model.paste(at: digit - 1)
            return true
        }
        switch chars {
        case "p": model.togglePin(); return true
        case "o": model.open(); return true
        case "c" where !searchHasSelection: model.copyOnly(); return true
        case ",": hide(); AppDelegate.openSettings(); return true
        case "w": hide(); return true
        default: break
        }
        if event.keyCode == UInt16(kVK_Delete) {
            model.delete()
            return true
        }
        return false
    }

    private var searchHasSelection: Bool {
        guard let editor = panel?.firstResponder as? NSTextView else { return false }
        return editor.selectedRange().length > 0
    }
}
