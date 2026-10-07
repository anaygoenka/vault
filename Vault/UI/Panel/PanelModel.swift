//
//  PanelModel.swift
//  Vault
//
//  State behind the ⇧⌘V panel: the search, the filter, what is selected,
//  and every action a key or click can take on a clip.
//

import AppKit
import Observation

enum PanelFilter: String, CaseIterable, Identifiable {
    case all, pinned, text, link, image, file, color

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all:    "All"
        case .pinned: "Pinned"
        case .text:   "Text"
        case .link:   "Links"
        case .image:  "Images"
        case .file:   "Files"
        case .color:  "Colours"
        }
    }

    var symbol: String {
        switch self {
        case .all:    "square.stack"
        case .pinned: "pin"
        case .text:   ClipKind.text.symbol
        case .link:   ClipKind.link.symbol
        case .image:  ClipKind.image.symbol
        case .file:   ClipKind.file.symbol
        case .color:  ClipKind.color.symbol
        }
    }

    var selectedSymbol: String {
        switch self {
        case .text, .link: symbol
        default: symbol + ".fill"
        }
    }

    func includes(_ item: ClipItem) -> Bool {
        switch self {
        case .all:    true
        case .pinned: item.isPinned
        case .text:   item.kind == .text
        case .link:   item.kind == .link
        case .image:  item.kind == .image
        case .file:   item.kind == .file
        case .color:  item.kind == .color
        }
    }
}

@Observable
final class PanelModel {
    var query = "" { didSet { if query != oldValue { selectFirst() } } }
    var filter: PanelFilter = .all { didSet { if filter != oldValue { selectFirst() } } }
    var selectedID: ClipItem.ID?
    /// Bumped on every open, so the view can re-focus search and animate in.
    var presentation = 0
    /// Whether the last selection change came from the keyboard, so the list
    /// only scrolls to follow arrows, not the pointer.
    var selectionFromKeyboard = false

    var onDismiss: (() -> Void)?

    private let store = HistoryStore.shared
    private let settings = AppSettings.shared

    // MARK: - Derived

    var visibleItems: [ClipItem] {
        let tokens = query
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        let matches = store.items.filter { item in
            filter.includes(item) && tokens.allSatisfy { item.searchableText.localizedStandardContains($0) }
        }
        guard filter == .all else { return matches }
        let (pinned, rest) = matches.partitioned(by: \.isPinned)
        return pinned + rest
    }

    var selected: ClipItem? {
        let items = visibleItems
        return items.first { $0.id == selectedID } ?? items.first
    }

    func counts() -> [PanelFilter: Int] {
        var result: [PanelFilter: Int] = [:]
        for filter in PanelFilter.allCases {
            result[filter] = store.items.lazy.filter(filter.includes).count
        }
        return result
    }

    // MARK: - Navigation

    func prepareForPresentation() {
        query = ""
        filter = .all
        selectFirst()
        presentation += 1
    }

    func selectFirst() {
        selectedID = visibleItems.first?.id
    }

    func move(_ delta: Int) {
        let items = visibleItems
        guard !items.isEmpty else { return }
        let current = items.firstIndex { $0.id == selectedID } ?? -1
        let next = min(max(current + delta, 0), items.count - 1)
        selectionFromKeyboard = true
        selectedID = items[next].id
    }

    func moveToEnd(_ last: Bool) {
        selectionFromKeyboard = true
        selectedID = last ? visibleItems.last?.id : visibleItems.first?.id
    }

    func cycleFilter(_ delta: Int) {
        let all = PanelFilter.allCases
        let index = all.firstIndex(of: filter) ?? 0
        filter = all[(index + delta + all.count) % all.count]
    }

    // MARK: - Actions

    func paste(_ item: ClipItem? = nil, invertPlain: Bool = false) {
        guard let item = item ?? selected else { return }
        let plain = settings.plainTextByDefault != invertPlain
        onDismiss?()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if PasteService.paste(item, plainText: plain) == .copied {
                HUD.show("Copied", detail: "Press ⌘V to paste", symbol: "doc.on.clipboard")
            }
        }
    }

    func paste(at index: Int) {
        let items = visibleItems
        guard items.indices.contains(index) else { return }
        paste(items[index])
    }

    func copyOnly(_ item: ClipItem? = nil) {
        guard let item = item ?? selected else { return }
        PasteService.copy(item)
        store.markUsed(item.id)
        onDismiss?()
        HUD.show("Copied", detail: item.title, symbol: "doc.on.clipboard")
    }

    func copy(string: String, label: String) {
        PasteService.copy(string: string)
        HUD.show("Copied \(label)", detail: string, symbol: "doc.on.clipboard")
    }

    func togglePin(_ item: ClipItem? = nil) {
        guard let item = item ?? selected else { return }
        store.togglePin(item.id)
    }

    func delete(_ item: ClipItem? = nil) {
        guard let item = item ?? selected else { return }
        let items = visibleItems
        if item.id == selectedID, let index = items.firstIndex(where: { $0.id == item.id }) {
            let neighbour = items.indices.contains(index + 1) ? items[index + 1] : (index > 0 ? items[index - 1] : nil)
            selectedID = neighbour?.id
        }
        store.delete(item.id)
    }

    func open(_ item: ClipItem? = nil) {
        guard let item = item ?? selected else { return }
        switch item.kind {
        case .link:
            if let url = item.url { onDismiss?(); NSWorkspace.shared.open(url) }
        case .file:
            let urls = (item.filePaths ?? []).map { URL(fileURLWithPath: $0) }
            onDismiss?()
            NSWorkspace.shared.activateFileViewerSelecting(urls)
        case .image:
            if let blob = item.imageBlob { onDismiss?(); NSWorkspace.shared.open(store.blobURL(blob)) }
        default:
            break
        }
    }
}
