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
                try? rep.representation(using: .png, properties: [:])?.write(to: dir.appendingPathComponent("\(name).png"))
            }
        }
    }
}
#endif
