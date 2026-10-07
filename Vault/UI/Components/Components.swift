//
//  Components.swift
//  Vault
//
//  Small pieces shared across the panel, Settings and onboarding.
//

import SwiftUI

/// A key cap such as ⌘ or ↩, drawn the way macOS menus draw them.
struct KeyCap: View {
    let text: String
    var prominent = false

    init(_ text: String, prominent: Bool = false) {
        self.text = text
        self.prominent = prominent
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .padding(.horizontal, 5)
            .frame(minWidth: 20, minHeight: 19)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(prominent ? Color.white.opacity(0.22) : Color.primary.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .strokeBorder(Color.primary.opacity(prominent ? 0 : 0.08), lineWidth: 0.5)
            )
    }
}

/// A hint in the panel footer: key caps, then what they do.
struct KeyHint: View {
    let keys: [String]
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            HStack(spacing: 2) { ForEach(keys, id: \.self) { KeyCap($0) } }
            Text(label)
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
    }
}

/// The app that a clip was copied from, as its icon.
struct AppIconView: View {
    let bundleID: String?
    var size: CGFloat = 16

    var body: some View {
        if let icon = ThumbnailCache.shared.appIcon(bundleID: bundleID) {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: size, height: size)
        }
    }
}

enum RelativeTime {
    static func short(_ date: Date, now: Date = .now) -> String {
        let seconds = now.timeIntervalSince(date)
        switch seconds {
        case ..<45:      return "Just now"
        case ..<3_600:   return "\(Int(seconds / 60) == 0 ? 1 : Int(seconds / 60))m ago"
        case ..<86_400:  return "\(Int(seconds / 3_600))h ago"
        case ..<172_800: return "Yesterday"
        case ..<604_800: return date.formatted(.dateTime.weekday(.wide))
        default:         return date.formatted(.dateTime.day().month(.abbreviated))
        }
    }
}

extension ClipKind {
    var tint: Color {
        switch self {
        case .text:  .blue
        case .link:  .teal
        case .image: .purple
        case .file:  .orange
        case .color: .pink
        }
    }
}

/// The leading thumbnail for a clip: the picture, the colour, the file
/// icon, or a tinted symbol for text and links.
struct ClipThumbnail: View {
    let item: ClipItem
    var size: CGFloat = 34

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous))
            if item.kind != .file, item.sourceBundleID != nil {
                AppIconView(bundleID: item.sourceBundleID, size: size * 0.48)
                    .shadow(color: .black.opacity(0.25), radius: 1.5, y: 0.5)
                    .offset(x: size * 0.14, y: size * 0.12)
            }
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder private var content: some View {
        switch item.kind {
        case .image:
            if let blob = item.imageBlob, let image = ThumbnailCache.shared.image(blob: blob) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                symbol
            }
        case .color:
            if let color = item.text.flatMap(ColorValue.init(parsing:)) {
                Color(nsColor: color.nsColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
                            .strokeBorder(.primary.opacity(0.15), lineWidth: 0.5)
                    )
            } else {
                symbol
            }
        case .file:
            Image(nsImage: ThumbnailCache.shared.fileIcon(path: item.filePaths?.first ?? "/"))
                .resizable()
                .interpolation(.high)
        default:
            symbol
        }
    }

    private var symbol: some View {
        ZStack {
            item.kind.tint.opacity(0.16)
            Image(systemName: item.kind.symbol)
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(item.kind.tint)
        }
    }
}
