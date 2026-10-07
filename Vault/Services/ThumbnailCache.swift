//
//  ThumbnailCache.swift
//  Vault
//
//  Images and app icons, decoded once.
//

import AppKit

final class ThumbnailCache {
    static let shared = ThumbnailCache()

    private let images = NSCache<NSString, NSImage>()
    private var icons: [String: NSImage] = [:]

    private init() { images.countLimit = 300 }

    func image(blob: String) -> NSImage? {
        if let cached = images.object(forKey: blob as NSString) { return cached }
        guard let image = NSImage(contentsOf: HistoryStore.shared.blobURL(blob)) else { return nil }
        images.setObject(image, forKey: blob as NSString)
        return image
    }

    func forget(_ blob: String) {
        images.removeObject(forKey: blob as NSString)
    }

    func appIcon(bundleID: String?) -> NSImage? {
        guard let bundleID else { return nil }
        if let icon = icons[bundleID] { return icon }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icons[bundleID] = icon
        return icon
    }

    func fileIcon(path: String) -> NSImage {
        if let icon = icons[path] { return icon }
        let icon = NSWorkspace.shared.icon(forFile: path)
        icons[path] = icon
        return icon
    }
}
