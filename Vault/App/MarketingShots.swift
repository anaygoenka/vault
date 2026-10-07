//
//  MarketingShots.swift
//  Vault
//
//  Debug builds only: `--marketing <scene>` fills Vault with sample clips,
//  lays out one scene over a wallpaper, photographs Vault's own windows and
//  puts the PNG on the clipboard. Capturing your own windows needs no
//  Screen Recording permission, and unlike drawing the view hierarchy it
//  keeps the real Liquid Glass.
//

#if DEBUG
import AppKit
import ScreenCaptureKit
import SwiftUI

enum MarketingShots {
    static func runIfRequested() -> Bool {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--marketing"), args.indices.contains(index + 1) else { return false }
        let scene = args[index + 1]
        guard CGPreflightScreenCaptureAccess() else {
            // Adds this build to Screen & System Audio Recording.
            CGRequestScreenCaptureAccess()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString("CAPTURE-NEEDS-PERMISSION", forType: .string)
            return true
        }
        seed()

        // Everything sits just above the desktop, behind every other app's
        // windows. The capture includes only Vault's windows, so nothing
        // covers the screen or takes focus while it runs.
        let desktop = Int(CGWindowLevelForKey(.desktopWindow))
        let backdrop = makeBackdrop()
        backdrop.level = NSWindow.Level(rawValue: desktop + 1)
        backdrop.orderFrontRegardless()
        let front = NSWindow.Level(rawValue: desktop + 2)

        let model = PanelController.shared.model
        var windows: [NSWindow] = []
        switch scene {
        case "settings", "onboarding":
            let window = NSWindow(
                contentRect: .zero,
                styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
                backing: .buffered, defer: false
            )
            window.titlebarAppearsTransparent = true
            if scene == "settings" {
                SettingsView.initialTab = "history"
                window.title = "Vault Settings"
                window.contentViewController = NSHostingController(rootView: SettingsView())
                window.setContentSize(NSSize(width: 620, height: 560))
            } else {
                window.titleVisibility = .hidden
                window.contentViewController = NSHostingController(rootView: OnboardingView())
                window.setContentSize(NSSize(width: 520, height: 480))
            }
            window.center()
            window.setFrameOrigin(NSPoint(x: window.frame.minX, y: window.frame.minY - 110))
            window.level = front
            window.orderFrontRegardless()
            windows = [window]
        default:
            PanelController.shared.showForCapture(level: front)
            if let panel = PanelController.shared.window {
                panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: panel.frame.minY - 150))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                let items = model.visibleItems
                switch scene {
                case "colour": model.selectedID = items.first { $0.kind == .color }?.id
                case "image": model.selectedID = items.first { $0.kind == .image }?.id
                case "search": model.query = "design"
                default: model.selectedID = items.first { $0.text?.hasPrefix("struct") == true }?.id
                }
            }
            windows = [PanelController.shared.window].compactMap { $0 }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            let ids = Set((windows + [backdrop]).map { CGWindowID($0.windowNumber) })
            Task {
                NSPasteboard.general.clearContents()
                do {
                    let png = try await capture(ids)
                    NSPasteboard.general.setData(png, forType: .png)
                } catch {
                    NSPasteboard.general.setString("CAPTURE-FAILED \(error)", forType: .string)
                }
                NSApp.terminate(nil)
            }
        }
        return true
    }

    // MARK: - Sample history

    private static func seed() {
        let store = HistoryStore.shared
        store.clear(includingPinned: true)
        AppSettings.shared.hasOnboarded = true
        AppSettings.shared.retention = .month

        func text(_ s: String, _ app: String, _ name: String, minutesAgo: Double, pinned: Bool = false) {
            var item = ClipItem(kind: ClipboardMonitor.classify(s), text: s, contentHash: UUID().uuidString)
            item.sourceBundleID = app
            item.sourceAppName = name
            item.copiedAt = .now.addingTimeInterval(-minutesAgo * 60)
            item.isPinned = pinned
            store.add(item)
        }

        // Oldest first, so the newest ends up on top.
        text("hello@vault.app", "com.apple.mail", "Mail", minutesAgo: 2_900, pinned: true)
        text("https://developer.apple.com/design/human-interface-guidelines/materials", "com.apple.Safari", "Safari", minutesAgo: 1_500)
        text("#FF9F0A", "com.apple.dt.Xcode", "Xcode", minutesAgo: 700)
        text("""
        struct ContentView: View {
            var body: some View {
                Text("Hello, Vault")
                    .padding()
                    .glassEffect()
            }
        }
        """, "com.apple.dt.Xcode", "Xcode", minutesAgo: 240)
        if let tiff = NSApp.applicationIconImage.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let out = rep.representation(using: .png, properties: [:]),
           let blob = store.writeBlob(out, ext: "png") {
            var item = ClipItem(kind: .image, imageBlob: blob, imageWidth: rep.pixelsWide, imageHeight: rep.pixelsHigh, byteSize: out.count, contentHash: UUID().uuidString)
            item.sourceBundleID = "com.apple.Preview"
            item.sourceAppName = "Preview"
            item.copiedAt = .now.addingTimeInterval(-95 * 60)
            store.add(item)
        }
        text("Design review moved to Thursday at 3pm. Bring the new onboarding flow and the colour tokens.", "com.apple.Notes", "Notes", minutesAgo: 48)
        text("rgb(94, 92, 230)", "com.apple.Safari", "Safari", minutesAgo: 20)
        text("https://github.com/anaygoenka/vault", "com.apple.Safari", "Safari", minutesAgo: 9)
        text("Dinner at 8 with Maya and Sam. Table for four, I'll book it.", "com.apple.MobileSMS", "Messages", minutesAgo: 1)
    }

    // MARK: - Backdrop and capture

    private static func makeBackdrop() -> NSWindow {
        let screen = NSScreen.main!
        let window = NSWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = true
        window.contentView = NSHostingView(rootView: Wallpaper())
        window.setFrame(screen.frame, display: true)
        return window
    }

    private struct Wallpaper: View {
        var body: some View {
            MeshGradient(
                width: 3, height: 3,
                points: [[0, 0], [0.5, 0], [1, 0], [0, 0.5], [0.45, 0.55], [1, 0.5], [0, 1], [0.5, 1], [1, 1]],
                colors: [
                    Color(red: 0.16, green: 0.12, blue: 0.42), Color(red: 0.33, green: 0.25, blue: 0.86), Color(red: 0.12, green: 0.46, blue: 0.86),
                    Color(red: 0.55, green: 0.24, blue: 0.75), Color(red: 0.95, green: 0.45, blue: 0.55), Color(red: 0.25, green: 0.62, blue: 0.95),
                    Color(red: 0.98, green: 0.62, blue: 0.30), Color(red: 0.92, green: 0.38, blue: 0.48), Color(red: 0.40, green: 0.30, blue: 0.80),
                ]
            )
            .ignoresSafeArea()
        }
    }

    /// Photographs Vault's own windows with ScreenCaptureKit and crops the
    /// result to the App Store's 16:10.
    private static func capture(_ ids: Set<CGWindowID>) async throws -> Data {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        let windows = content.windows.filter { ids.contains($0.windowID) }
        guard let display = content.displays.first(where: { $0.displayID == CGMainDisplayID() }) ?? content.displays.first else {
            throw CocoaError(.featureUnsupported)
        }
        let filter = SCContentFilter(display: display, including: windows)
        let config = SCStreamConfiguration()
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        config.width = Int(CGFloat(display.width) * scale)
        config.height = Int(CGFloat(display.height) * scale)
        config.showsCursor = false
        config.captureResolution = .best
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)

        let w = CGFloat(image.width), h = CGFloat(image.height)
        let cropW = min(w, h * 1.6), cropH = cropW / 1.6
        let crop = CGRect(x: (w - cropW) / 2, y: (h - cropH) / 2, width: cropW, height: cropH).integral
        guard let cropped = image.cropping(to: crop),
              let png = NSBitmapImageRep(cgImage: cropped).representation(using: .png, properties: [:]) else {
            throw CocoaError(.fileWriteUnknown)
        }
        return png
    }
}
#endif
