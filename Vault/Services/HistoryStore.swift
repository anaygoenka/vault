//
//  HistoryStore.swift
//  Vault
//
//  The history itself. Kept in memory, written to Application Support as
//  JSON (debounced, off the main thread) with images and rich text stored
//  beside it as blobs. Retention runs on launch, hourly, and whenever the
//  retention setting changes.
//

import AppKit
import Foundation
import Observation

@Observable
final class HistoryStore {
    static let shared = HistoryStore()

    /// Newest first. Pinned clips are ordered alongside the rest; views put
    /// them on top.
    private(set) var items: [ClipItem] = []

    let directory: URL
    let blobDirectory: URL
    private let historyURL: URL
    @ObservationIgnored private var saveTask: Task<Void, Never>?
    @ObservationIgnored private var purgeTimer: Timer?

    private init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("Vault", isDirectory: true)
        blobDirectory = directory.appendingPathComponent("Blobs", isDirectory: true)
        historyURL = directory.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: blobDirectory, withIntermediateDirectories: true)
        load()
        purge()
        purgeTimer = Timer.scheduledTimer(withTimeInterval: 15 * 60, repeats: true) { _ in
            Task { @MainActor in HistoryStore.shared.purge() }
        }
    }

    // MARK: - Reading

    var pinned: [ClipItem] { items.filter(\.isPinned) }

    func item(_ id: ClipItem.ID?) -> ClipItem? {
        guard let id else { return nil }
        return items.first { $0.id == id }
    }

    func blobURL(_ name: String) -> URL {
        blobDirectory.appendingPathComponent(name)
    }

    var diskUsage: Int {
        let files = (try? FileManager.default.contentsOfDirectory(at: blobDirectory, includingPropertiesForKeys: [.fileSizeKey])) ?? []
        let blobs = files.reduce(0) { $0 + ((try? $1.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) }
        let json = (try? historyURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        return blobs + json
    }

    // MARK: - Writing

    /// Adds a new clip, or, if the same content is already here, brings the
    /// existing one to the top instead of keeping two copies.
    func add(_ item: ClipItem) {
        if let index = items.firstIndex(where: { $0.contentHash == item.contentHash }) {
            var existing = items.remove(at: index)
            item.blobs.filter { !existing.blobs.contains($0) }.forEach(deleteBlob)
            existing.copiedAt = .now
            existing.sourceBundleID = item.sourceBundleID ?? existing.sourceBundleID
            existing.sourceAppName = item.sourceAppName ?? existing.sourceAppName
            items.insert(existing, at: 0)
        } else {
            items.insert(item, at: 0)
        }
        enforceLimit()
        scheduleSave()
    }

    func markUsed(_ id: ClipItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        var item = items[index]
        item.useCount += 1
        item.lastUsedAt = .now
        if AppSettings.shared.moveReusedToTop {
            item.copiedAt = .now
            items.remove(at: index)
            items.insert(item, at: 0)
        } else {
            items[index] = item
        }
        scheduleSave()
    }

    func togglePin(_ id: ClipItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isPinned.toggle()
        scheduleSave()
    }

    func delete(_ id: ClipItem.ID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items.remove(at: index).blobs.forEach(deleteBlob)
        scheduleSave()
    }

    /// Clears the history. Pinned clips stay unless `includingPinned`.
    func clear(includingPinned: Bool = false) {
        let (keep, drop) = items.partitioned { $0.isPinned && !includingPinned }
        drop.flatMap(\.blobs).forEach(deleteBlob)
        items = keep
        scheduleSave()
    }

    /// Applies the retention window and the item limit.
    func purge() {
        if let cutoff = AppSettings.shared.retention.cutoff() {
            let (keep, drop) = items.partitioned { $0.isPinned || $0.copiedAt >= cutoff }
            if !drop.isEmpty {
                drop.flatMap(\.blobs).forEach(deleteBlob)
                items = keep
            }
        }
        enforceLimit()
        removeOrphanBlobs()
        scheduleSave()
    }

    func countExpiring(under retention: Retention) -> Int {
        guard let cutoff = retention.cutoff() else { return 0 }
        return items.filter { !$0.isPinned && $0.copiedAt < cutoff }.count
    }

    func writeBlob(_ data: Data, ext: String) -> String? {
        let name = "\(UUID().uuidString).\(ext)"
        do {
            try data.write(to: blobURL(name), options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    // MARK: - Private

    private func enforceLimit() {
        let limit = max(AppSettings.shared.maxItems, 10)
        let unpinned = items.filter { !$0.isPinned }
        guard unpinned.count > limit else { return }
        let dropIDs = Set(unpinned.suffix(unpinned.count - limit).map(\.id))
        items.filter { dropIDs.contains($0.id) }.flatMap(\.blobs).forEach(deleteBlob)
        items.removeAll { dropIDs.contains($0.id) }
    }

    private func deleteBlob(_ name: String) {
        try? FileManager.default.removeItem(at: blobURL(name))
        ThumbnailCache.shared.forget(name)
    }

    private func removeOrphanBlobs() {
        let known = Set(items.flatMap(\.blobs))
        let files = (try? FileManager.default.contentsOfDirectory(atPath: blobDirectory.path)) ?? []
        for file in files where !known.contains(file) {
            try? FileManager.default.removeItem(at: blobURL(file))
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: historyURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        items = (try? decoder.decode([ClipItem].self, from: data)) ?? []
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = items
        let url = historyURL
        saveTask = Task.detached(priority: .utility) {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            if let data = try? encoder.encode(snapshot) {
                try? data.write(to: url, options: .atomic)
            }
        }
    }
}

extension Array {
    func partitioned(by keep: (Element) -> Bool) -> (keep: [Element], drop: [Element]) {
        var a: [Element] = [], b: [Element] = []
        for element in self { if keep(element) { a.append(element) } else { b.append(element) } }
        return (a, b)
    }
}
