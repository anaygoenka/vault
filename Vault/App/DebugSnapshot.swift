//
//  DebugSnapshot.swift
//  Vault
//
//  Debug builds only: `--snapshot <dir>` writes each visible window to a PNG
//  so layouts can be checked without Screen Recording access.
//

#if DEBUG
import AppKit

enum DebugSnapshot {
    static func scheduleIfRequested() {
        let args = ProcessInfo.processInfo.arguments
        guard let index = args.firstIndex(of: "--snapshot"), args.indices.contains(index + 1) else { return }
        let dir = URL(fileURLWithPath: args[index + 1])
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            for (n, window) in NSApp.windows.enumerated() where window.isVisible {
                guard let view = window.contentView?.superview ?? window.contentView,
                      let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { continue }
                view.cacheDisplay(in: view.bounds, to: rep)
                let name = window.identifier?.rawValue ?? "window\(n)"
                guard let png = rep.representation(using: .png, properties: [:]) else { continue }
                if (try? png.write(to: dir.appendingPathComponent("\(name).png"))) == nil, name == "panel" {
                    // Sandboxed builds cannot write outside their container;
                    // hand the panel over on the clipboard instead.
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setData(png, forType: .png)
                }
            }
        }
    }
}
#endif

