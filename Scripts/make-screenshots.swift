// Adds headlines to raw captures and writes 2880×1800 App Store screenshots.
// Usage: swift Scripts/make-screenshots.swift <raw-dir> <out-dir>
import AppKit

let shots: [(file: String, title: String, subtitle: String)] = [
    ("history", "Everything you copy, one ⇧⌘V away", "Search, preview and reuse anything you’ve copied."),
    ("colour", "Colours, decoded", "Copy any colour, then re-copy it as HEX, RGB or HSL."),
    ("image", "Text, links, images and files", "Every clip gets a proper preview."),
    ("settings", "Keep it for an hour, or forever", "You choose how long Vault remembers. Pinned clips always stay."),
]
let raw = URL(fileURLWithPath: CommandLine.arguments[1])
let out = URL(fileURLWithPath: CommandLine.arguments[2])
let size = NSSize(width: 2880, height: 1800)

for (index, shot) in shots.enumerated() {
    guard let source = NSImage(contentsOf: raw.appendingPathComponent("\(shot.file).png")) else { continue }
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 2880, pixelsHigh: 1800, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    source.draw(in: NSRect(origin: .zero, size: size))

    let centred = NSMutableParagraphStyle()
    centred.alignment = .center
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
    shadow.shadowBlurRadius = 18
    shadow.shadowOffset = NSSize(width: 0, height: -3)
    let title = NSAttributedString(string: shot.title, attributes: [
        .font: NSFont.systemFont(ofSize: 104, weight: .bold),
        .foregroundColor: NSColor.white,
        .paragraphStyle: centred,
        .shadow: shadow,
        .kern: -1.5,
    ])
    let subtitle = NSAttributedString(string: shot.subtitle, attributes: [
        .font: NSFont.systemFont(ofSize: 48, weight: .medium),
        .foregroundColor: NSColor.white.withAlphaComponent(0.85),
        .paragraphStyle: centred,
        .shadow: shadow,
    ])
    title.draw(in: NSRect(x: 100, y: size.height - 290, width: size.width - 200, height: 140))
    subtitle.draw(in: NSRect(x: 100, y: size.height - 380, width: size.width - 200, height: 70))
    NSGraphicsContext.restoreGraphicsState()

    let name = String(format: "%02d-%@.png", index + 1, shot.file)
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
    print(name)
}
