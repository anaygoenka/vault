// Renders Vault's app icon into the asset catalog. Run: swift Scripts/make-icon.swift
import AppKit

let out = URL(fileURLWithPath: "Vault/Resources/Assets.xcassets/AppIcon.appiconset")

func render(_ px: Int) -> Data {
    let s = CGFloat(px)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // macOS icon grid: 824/1024 body, centred.
    let inset = s * 100 / 1024
    let body = CGRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let radius = body.width * 0.225
    let path = NSBezierPath(roundedRect: body, xRadius: radius, yRadius: radius)

    // Drop shadow.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.012), blur: s * 0.03, color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor.black.setFill(); path.fill()
    ctx.restoreGState()

    // Background gradient.
    ctx.saveGState()
    path.addClip()
    NSGradient(colors: [
        NSColor(srgbRed: 0.42, green: 0.36, blue: 1.00, alpha: 1),
        NSColor(srgbRed: 0.27, green: 0.20, blue: 0.86, alpha: 1),
        NSColor(srgbRed: 0.13, green: 0.10, blue: 0.45, alpha: 1),
    ])!.draw(in: body, angle: -90)

    // Soft glow blobs.
    for (c, x, y, r) in [(NSColor(srgbRed: 0.95, green: 0.45, blue: 1, alpha: 0.55), 0.2, 0.25, 0.55),
                         (NSColor(srgbRed: 0.35, green: 0.85, blue: 1, alpha: 0.45), 0.85, 0.8, 0.5)] {
        let center = CGPoint(x: body.minX + body.width * x, y: body.minY + body.height * y)
        NSGradient(colors: [c, c.withAlphaComponent(0)])!.draw(fromCenter: center, radius: 0, toCenter: center, radius: body.width * r, options: [])
    }

    // Glass card stack.
    func card(_ rect: CGRect, alpha: CGFloat) {
        let p = NSBezierPath(roundedRect: rect, xRadius: rect.width * 0.12, yRadius: rect.width * 0.12)
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.03, color: NSColor.black.withAlphaComponent(0.25).cgColor)
        NSColor.white.withAlphaComponent(alpha).setFill(); p.fill()
        ctx.restoreGState()
        NSGradient(colors: [NSColor.white.withAlphaComponent(0.55), NSColor.white.withAlphaComponent(0.05)])!.draw(in: p, angle: -90)
        NSColor.white.withAlphaComponent(0.7).setStroke(); p.lineWidth = s * 0.004; p.stroke()
    }
    let cw = body.width * 0.50, ch = body.height * 0.58
    let cx = body.midX - cw / 2, cy = body.midY - ch / 2 - body.height * 0.02
    card(CGRect(x: cx + cw * 0.16, y: cy + ch * 0.16, width: cw, height: ch), alpha: 0.12)
    card(CGRect(x: cx + cw * 0.08, y: cy + ch * 0.08, width: cw, height: ch), alpha: 0.18)
    let front = CGRect(x: cx, y: cy, width: cw, height: ch)
    card(front, alpha: 0.28)

    // Text lines on the front card.
    NSColor.white.withAlphaComponent(0.92).setFill()
    for (i, w) in [0.62, 0.78, 0.48].enumerated() {
        let lh = ch * 0.07
        let r = CGRect(x: front.minX + cw * 0.14, y: front.maxY - ch * 0.30 - CGFloat(i) * ch * 0.16, width: cw * w, height: lh)
        NSBezierPath(roundedRect: r, xRadius: lh / 2, yRadius: lh / 2).fill()
    }
    // Clip at the top.
    let clip = CGRect(x: front.midX - cw * 0.2, y: front.maxY - ch * 0.07, width: cw * 0.4, height: ch * 0.13)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.006), blur: s * 0.012, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    NSColor.white.setFill()
    NSBezierPath(roundedRect: clip, xRadius: clip.height * 0.45, yRadius: clip.height * 0.45).fill()
    ctx.restoreGState()

    // Specular rim.
    ctx.restoreGState()
    ctx.saveGState()
    path.addClip()
    NSGradient(colors: [NSColor.white.withAlphaComponent(0.35), NSColor.white.withAlphaComponent(0)])!
        .draw(in: CGRect(x: body.minX, y: body.midY + body.height * 0.15, width: body.width, height: body.height * 0.35), angle: -90)
    ctx.restoreGState()
    NSColor.white.withAlphaComponent(0.35).setStroke()
    path.lineWidth = s * 0.004
    path.stroke()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let name = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        try! render(px).write(to: out.appendingPathComponent(name))
        images.append(["idiom": "mac", "size": "\(base)x\(base)", "scale": "\(scale)x", "filename": name])
    }
}
let json = try! JSONSerialization.data(withJSONObject: ["images": images, "info": ["author": "xcode", "version": 1]], options: [.prettyPrinted, .sortedKeys])
try! json.write(to: out.appendingPathComponent("Contents.json"))
print("ok")
