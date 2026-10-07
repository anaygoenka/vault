//
//  PreviewPane.swift
//  Vault
//
//  The right-hand side of the panel: the selected clip in full, the actions
//  for it, and where and when it came from.
//

import SwiftUI

struct PreviewPane: View {
    let item: ClipItem
    let model: PanelModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 10)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .clipped()
            Divider().opacity(0.5)
            metadata
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 8) {
            Label(item.kind.label, systemImage: item.kind.symbol)
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(item.kind.tint)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(item.kind.tint.opacity(0.13), in: .capsule)
            Spacer()
            HStack(spacing: 6) {
                action(item.isPinned ? "pin.slash" : "pin", help: item.isPinned ? "Unpin (⌘P)" : "Pin (⌘P)") {
                    model.togglePin(item)
                }
                switch item.kind {
                case .link: action("safari", help: "Open link (⌘O)") { model.open(item) }
                case .file: action("folder", help: "Show in Finder (⌘O)") { model.open(item) }
                case .image: action("eye", help: "Open in Preview (⌘O)") { model.open(item) }
                default: EmptyView()
                }
                action("doc.on.doc", help: "Copy without pasting (⌥↩)") { model.copyOnly(item) }
                action("trash", help: "Delete (⌘⌫)") { model.delete(item) }
            }
            Button {
                model.paste(item)
            } label: {
                Label(pasteLabel, systemImage: "arrow.turn.down.left")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(.glassProminent)
            .help("Return")
        }
    }

    private var pasteLabel: String {
        AppSettings.shared.pasteAutomatically && PermissionGuide.shared.accessibilityGranted ? "Paste" : "Copy"
    }

    private func action(_ symbol: String, help: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .medium))
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .help(help)
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .text: TextPreview(text: item.text ?? "")
        case .link: LinkPreview(item: item)
        case .image: ImagePreview(item: item)
        case .file: FilePreview(paths: item.filePaths ?? [])
        case .color: ColorPreview(text: item.text ?? "", model: model)
        }
    }

    // MARK: - Metadata

    /// Where it came from and when, in one quiet line.
    private var metadata: some View {
        HStack(spacing: 6) {
            if let app = item.sourceAppName {
                AppIconView(bundleID: item.sourceBundleID, size: 14)
                Text(app).foregroundStyle(.primary.opacity(0.8))
                dot
            }
            Text(item.copiedAt.formatted(.dateTime.day().month(.abbreviated).hour().minute()))
            if let size = sizeDescription {
                dot
                Text(size)
            }
            Spacer(minLength: 8)
            Label(expiry, systemImage: item.isPinned ? "pin.fill" : "hourglass")
                .labelStyle(.titleAndIcon)
                .help(item.isPinned ? "Pinned clips are kept forever" : "When this clip is deleted automatically")
        }
        .font(.system(size: 11))
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }

    private var dot: some View {
        Text("·").foregroundStyle(.tertiary)
    }

    private var sizeDescription: String? {
        switch item.kind {
        case .text, .link, .color:
            let text = item.text ?? ""
            let words = text.split { $0.isWhitespace || $0.isNewline }.count
            let lines = text.split(whereSeparator: \.isNewline).count
            if lines > 1 { return "\(lines.formatted()) lines" }
            if words > 1 { return "\(words.formatted()) words" }
            return "\(text.count.formatted()) characters"
        case .image:
            return item.byteSize.map { ByteCountFormatter.string(fromByteCount: Int64($0), countStyle: .file) }
        case .file:
            let count = item.filePaths?.count ?? 0
            return count == 1 ? "1 item" : "\(count) items"
        }
    }

    private var expiry: String {
        if item.isPinned { return "Pinned" }
        guard let interval = AppSettings.shared.retention.interval else { return "Kept" }
        let date = item.copiedAt.addingTimeInterval(interval)
        return "Clears " + date.formatted(.relative(presentation: .named))
    }
}

// MARK: - Kinds

private struct TextPreview: View {
    let text: String

    var body: some View {
        ScrollView {
            Text(text.count > 20_000 ? String(text.prefix(20_000)) + "\n…" : text)
                .font(looksLikeCode ? .system(size: 12.5, design: .monospaced) : .system(size: 13.5))
                .lineSpacing(3)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
        }
    }

    private var looksLikeCode: Bool {
        let markers = ["{", "}", ";", "=>", "func ", "def ", "const ", "import ", "</", "$ "]
        let hits = markers.filter { text.contains($0) }.count
        return hits >= 2
    }
}

private struct LinkPreview: View {
    let item: ClipItem

    var body: some View {
        let url = item.url
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "globe")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(.teal)
                    .frame(width: 48, height: 48)
                    .glassEffect(.regular.tint(.teal.opacity(0.15)), in: .rect(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 3) {
                    Text(url?.host(percentEncoded: false)?.replacingOccurrences(of: "www.", with: "") ?? "Link")
                        .font(.system(size: 17, weight: .semibold))
                    if let scheme = url?.scheme {
                        Text(scheme == "https" ? "Secure link" : scheme.uppercased())
                            .font(.system(size: 11.5))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(item.text ?? "")
                .font(.system(size: 12.5, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 6)
    }
}

private struct ImagePreview: View {
    let item: ClipItem

    var body: some View {
        Group {
            if let blob = item.imageBlob, let image = ThumbnailCache.shared.image(blob: blob) {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(contentMode: .fit)
                    .clipShape(.rect(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.18), radius: 8, y: 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Image unavailable", systemImage: "photo.badge.exclamationmark")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
    }
}

private struct FilePreview: View {
    let paths: [String]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(paths, id: \.self) { path in
                    HStack(spacing: 10) {
                        Image(nsImage: ThumbnailCache.shared.fileIcon(path: path))
                            .resizable()
                            .frame(width: 34, height: 34)
                        VStack(alignment: .leading, spacing: 2) {
                            Text((path as NSString).lastPathComponent)
                                .font(.system(size: 13, weight: .medium))
                            Text((path as NSString).deletingLastPathComponent.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .truncationMode(.middle)
                        }
                        .lineLimit(1)
                        Spacer()
                        if !FileManager.default.fileExists(atPath: path) {
                            Text("Missing")
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }
}

private struct ColorPreview: View {
    let text: String
    let model: PanelModel

    var body: some View {
        if let color = ColorValue(parsing: text) {
            VStack(alignment: .leading, spacing: 12) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: color.nsColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .strokeBorder(.primary.opacity(0.12), lineWidth: 0.5)
                    )
                    .overlay(alignment: .bottomLeading) {
                        Text(color.hexString)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(color.isLight ? .black.opacity(0.75) : .white)
                            .padding(16)
                    }
                    .frame(minHeight: 70, maxHeight: 150)
                    .layoutPriority(-1)
                    .shadow(color: Color(nsColor: color.nsColor).opacity(0.3), radius: 10, y: 4)
                VStack(spacing: 4) {
                    formatRow("HEX", color.hexString)
                    formatRow("RGB", color.rgbString)
                    formatRow("HSL", color.hslString)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
        }
    }

    private func formatRow(_ name: String, _ value: String) -> some View {
        Button {
            model.copy(string: value, label: name)
        } label: {
            HStack {
                Text(name)
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 34, alignment: .leading)
                Text(value)
                    .font(.system(size: 12.5, design: .monospaced))
                Spacer()
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(.primary.opacity(0.05), in: .rect(cornerRadius: 9))
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .help("Copy \(name)")
    }
}
