//
//  ClipItem.swift
//  Vault
//
//  One thing that was copied. Text, links and colours live inline; images
//  and rich text live as blobs on disk so the history file stays small.
//

import Foundation

enum ClipKind: String, Codable, CaseIterable, Identifiable {
    case text, link, image, file, color

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .text:  "text.alignleft"
        case .link:  "link"
        case .image: "photo"
        case .file:  "doc"
        case .color: "paintpalette"
        }
    }

    var label: String {
        switch self {
        case .text:  "Text"
        case .link:  "Link"
        case .image: "Image"
        case .file:  "File"
        case .color: "Colour"
        }
    }
}

struct ClipItem: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: ClipKind
    /// Plain text. For files, the paths joined by newlines.
    var text: String?
    /// Blob filename of the RTF that came with the text, if any.
    var rtfBlob: String?
    /// Blob filename of the PNG for images.
    var imageBlob: String?
    var imageWidth: Int?
    var imageHeight: Int?
    var byteSize: Int?
    var filePaths: [String]?

    var sourceBundleID: String?
    var sourceAppName: String?

    var copiedAt: Date = .now
    var lastUsedAt: Date?
    var useCount: Int = 0
    var isPinned = false
    var contentHash: String

    var blobs: [String] { [rtfBlob, imageBlob].compactMap { $0 } }

    /// One line that represents the clip in a list.
    var title: String {
        switch kind {
        case .image:
            if let w = imageWidth, let h = imageHeight { return "Image \(w) × \(h)" }
            return "Image"
        case .file:
            let names = (filePaths ?? []).map { ($0 as NSString).lastPathComponent }
            if names.count > 1 { return "\(names[0]) and \(names.count - 1) more" }
            return names.first ?? "File"
        default:
            let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let firstLine = trimmed.split(whereSeparator: \.isNewline).first.map(String.init) ?? trimmed
            return firstLine.isEmpty ? "Whitespace" : String(firstLine.prefix(300))
        }
    }

    var searchableText: String {
        [text, sourceAppName, kind.label, filePaths?.joined(separator: " ")]
            .compactMap { $0 }
            .joined(separator: " ")
    }

    var url: URL? {
        guard kind == .link, let text else { return nil }
        return URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
