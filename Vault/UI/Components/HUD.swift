//
//  HUD.swift
//  Vault
//
//  A small glass confirmation that floats up near the bottom of the screen
//  and fades out by itself. It never takes focus.
//

import AppKit
import SwiftUI

enum HUD {
    private static var panel: NSPanel?
    private static var hideWork: DispatchWorkItem?

    static func show(_ title: String, detail: String? = nil, symbol: String) {
        let view = HUDView(title: title, detail: detail, symbol: symbol)
        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize

        let panel = panel ?? makePanel()
        Self.panel = panel
        panel.contentView = hosting

        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrame(NSRect(x: frame.midX - size.width / 2, y: frame.minY + frame.height * 0.14, width: size.width, height: size.height), display: true)
        }

        hideWork?.cancel()
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }

        let work = DispatchWorkItem {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.35
                panel.animator().alphaValue = 0
            } completionHandler: {
                MainActor.assumeIsolated { panel.orderOut(nil) }
            }
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4, execute: work)
    }

    private static func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        return panel
    }
}

private struct HUDView: View {
    let title: String
    let detail: String?
    let symbol: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.tint)
                .symbolEffect(.bounce, options: .nonRepeating)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: .semibold))
                if let detail {
                    Text(detail)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .frame(maxWidth: 320, alignment: .leading)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.7), in: .capsule)
        .glassEffect(.regular, in: .capsule)
        .padding(16)
        .fixedSize()
    }
}
