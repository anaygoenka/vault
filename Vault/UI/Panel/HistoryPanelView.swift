//
//  HistoryPanelView.swift
//  Vault
//
//  The panel: search on top, filters beneath it, the history on the left
//  and a live preview of the selected clip on the right. Everything works
//  from the keyboard; the footer says how.
//

import SwiftUI

struct HistoryPanelView: View {
    @Bindable var model: PanelModel
    @FocusState private var searchFocused: Bool
    @State private var appeared = false
    private let store = HistoryStore.shared
    private let settings = AppSettings.shared

    var body: some View {
        let items = model.visibleItems
        VStack(spacing: 0) {
            Group {
                searchBar
                FilterBar(model: model)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 10)
            }
            .fixedSize(horizontal: false, vertical: true)
            Divider().opacity(0.5)
            Group {
                if items.isEmpty {
                    EmptyStateView(model: model, hasHistory: !store.items.isEmpty)
                } else {
                    HStack(spacing: 0) {
                        ClipList(model: model, items: items)
                            .frame(width: 340)
                        Divider().opacity(0.5)
                        if let selected = model.selected {
                            PreviewPane(item: selected, model: model)
                                .id(selected.id)
                                .transition(.opacity)
                        }
                    }
                }
            }
            // Content takes what is left and never pushes the search bar or
            // the footer out of the panel.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            Divider().opacity(0.5)
            footer
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: PanelController.size.width, height: PanelController.size.height)
        // Glass alone lets a bright wallpaper wash out the text. A frosted
        // base in the window colour keeps contrast on any background while
        // the glass still refracts at the edges.
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.7), in: .rect(cornerRadius: 26))
        .scaleEffect(appeared ? 1 : 0.97)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: appeared)
        .onChange(of: model.presentation, initial: true) {
            appeared = false
            searchFocused = true
            DispatchQueue.main.async { appeared = true }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Search your clipboard", text: $model.query)
                .textFieldStyle(.plain)
                .font(.system(size: 19, weight: .regular))
                .focused($searchFocused)
            if !model.query.isEmpty {
                Button {
                    model.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
            if settings.isPaused {
                Label("Paused", systemImage: "pause.fill")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .glassEffect(.regular.tint(.orange.opacity(0.18)), in: .capsule)
                    .help("Vault is not recording new copies. Resume from the menu bar.")
            }
            Button {
                PanelController.shared.hide()
                AppDelegate.openSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .frame(width: 26, height: 26)
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .help("Settings (⌘,)")
        }
        .padding(.horizontal, 18)
        .padding(.top, 16)
        .padding(.bottom, 12)
        .animation(.snappy(duration: 0.2), value: model.query.isEmpty)
    }

    private var footer: some View {
        HStack(spacing: 16) {
            KeyHint(keys: ["↩"], label: settings.pasteAutomatically && PermissionGuide.shared.accessibilityGranted ? "Paste" : "Copy")
            KeyHint(keys: ["⇧", "↩"], label: settings.plainTextByDefault ? "With formatting" : "Plain text")
            KeyHint(keys: ["⌘", "P"], label: "Pin")
            KeyHint(keys: ["⌘", "⌫"], label: "Delete")
            KeyHint(keys: ["⇥"], label: "Filter")
            Spacer()
            Text("\(store.items.count) clips · keeping \(settings.retention.label.lowercased())")
                .font(.system(size: 11.5))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 18)
        .frame(height: 38)
    }
}

// MARK: - Filters

private struct FilterBar: View {
    @Bindable var model: PanelModel
    @Namespace private var pill

    var body: some View {
        let counts = model.counts()
        HStack(spacing: 2) {
            ForEach(PanelFilter.allCases) { filter in
                FilterChip(
                    filter: filter,
                    count: counts[filter] ?? 0,
                    selected: model.filter == filter,
                    pill: pill
                ) {
                    withAnimation(.snappy(duration: 0.28)) { model.filter = filter }
                }
            }
            Spacer(minLength: 0)
        }
    }
}

/// Plain text until chosen; the chosen filter sits on a solid pill that
/// slides between them. The panel is already glass, so no glass here.
private struct FilterChip: View {
    let filter: PanelFilter
    let count: Int
    let selected: Bool
    let pill: Namespace.ID
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Image(systemName: selected ? filter.selectedSymbol : filter.symbol)
                    .font(.system(size: 11, weight: .semibold))
                Text(filter.label)
                if filter != .all, count > 0 {
                    Text("\(count)")
                        .monospacedDigit()
                        .opacity(selected ? 0.75 : 0.6)
                }
            }
            .font(.system(size: 12, weight: selected ? .semibold : .medium))
            .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background {
                if selected {
                    Capsule()
                        .fill(Color.accentColor)
                        .matchedGeometryEffect(id: "pill", in: pill)
                } else if hovering {
                    Capsule().fill(Color.primary.opacity(0.07))
                }
            }
            .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .opacity(count == 0 && filter != .all && !selected ? 0.5 : 1)
        .onHover { hovering = $0 }
    }
}

// MARK: - List

private struct ClipList: View {
    @Bindable var model: PanelModel
    let items: [ClipItem]
    @Namespace private var selection

    var body: some View {
        let selectedID = model.selected?.id
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        ClipRow(
                            item: item,
                            index: index,
                            isSelected: item.id == selectedID,
                            selection: selection
                        )
                        .id(item.id)
                        .onTapGesture(count: 2) { model.paste(item) }
                        .onTapGesture {
                            model.selectionFromKeyboard = false
                            model.selectedID = item.id
                        }
                        .contextMenu { ClipContextMenu(item: item, model: model) }
                    }
                }
                .padding(8)
                .animation(.snappy(duration: 0.18), value: model.selectedID)
            }
            .scrollIndicators(.automatic)
            .onChange(of: model.selectedID) { _, id in
                guard model.selectionFromKeyboard, let id else { return }
                withAnimation(.snappy(duration: 0.15)) { proxy.scrollTo(id, anchor: nil) }
            }
            .onChange(of: model.presentation) {
                if let first = items.first { proxy.scrollTo(first.id, anchor: .top) }
            }
        }
    }
}

private struct ClipRow: View {
    let item: ClipItem
    let index: Int
    let isSelected: Bool
    let selection: Namespace.ID
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 11) {
            ClipThumbnail(item: item, size: 32)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
                HStack(spacing: 4) {
                    if item.isPinned {
                        Image(systemName: "pin.fill").font(.system(size: 9, weight: .bold))
                    }
                    Text(subtitle)
                }
                .font(.system(size: 11))
                .foregroundStyle(isSelected ? AnyShapeStyle(.white.opacity(0.78)) : AnyShapeStyle(.secondary))
                .lineLimit(1)
            }
            Spacer(minLength: 4)
            if index < 9 {
                KeyCap("⌘\(index + 1)", prominent: isSelected)
                    .opacity(isSelected || hovering ? 1 : 0.45)
            }
        }
        .foregroundStyle(isSelected ? .white : .primary)
        .padding(.horizontal, 9)
        .padding(.vertical, 7)
        .background {
            if isSelected {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.gradient)
                    .shadow(color: Color.accentColor.opacity(0.35), radius: 6, y: 2)
                    .matchedGeometryEffect(id: "selection", in: selection)
            } else if hovering {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.primary.opacity(0.06))
            }
        }
        .contentShape(.rect(cornerRadius: 12))
        .onHover { hovering = $0 }
    }

    private var subtitle: String {
        let time = RelativeTime.short(item.copiedAt)
        if let app = item.sourceAppName { return "\(app) · \(time)" }
        return time
    }
}

struct ClipContextMenu: View {
    let item: ClipItem
    let model: PanelModel

    var body: some View {
        Button("Paste", systemImage: "doc.on.clipboard") { model.paste(item) }
        if item.kind == .text || item.kind == .link || item.kind == .file {
            Button("Paste as Plain Text", systemImage: "textformat") { model.paste(item, invertPlain: !AppSettings.shared.plainTextByDefault) }
        }
        Button("Copy", systemImage: "doc.on.doc") { model.copyOnly(item) }
        Divider()
        Button(item.isPinned ? "Unpin" : "Pin", systemImage: item.isPinned ? "pin.slash" : "pin") { model.togglePin(item) }
        switch item.kind {
        case .link: Button("Open Link", systemImage: "safari") { model.open(item) }
        case .file: Button("Show in Finder", systemImage: "folder") { model.open(item) }
        case .image: Button("Open in Preview", systemImage: "eye") { model.open(item) }
        default: EmptyView()
        }
        Divider()
        Button("Delete", systemImage: "trash", role: .destructive) { model.delete(item) }
    }
}

// MARK: - Empty

private struct EmptyStateView: View {
    let model: PanelModel
    let hasHistory: Bool

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: hasHistory ? "magnifyingglass" : "list.clipboard")
                .font(.system(size: 40, weight: .light))
                .foregroundStyle(.tint)
                .symbolEffect(.pulse, options: .nonRepeating)
                .frame(width: 84, height: 84)
                .glassEffect(.regular.tint(.accentColor.opacity(0.12)), in: .circle)
            VStack(spacing: 5) {
                Text(hasHistory ? "Nothing matches" : "Your clipboard history starts here")
                    .font(.system(size: 16, weight: .semibold))
                Text(hasHistory
                     ? "Try fewer words, or press ⎋ to clear the search."
                     : "Copy anything with ⌘C and it will be waiting for you here.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            if hasHistory, model.filter != .all {
                Button("Show all clips") { model.filter = .all }
                    .buttonStyle(.glass)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(30)
    }
}
