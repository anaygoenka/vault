//
//  ColorValue.swift
//  Vault
//
//  Recognises colours people copy as text (#hex, rgb(), rgba(), hsl()) so
//  they can be shown as swatches and re-copied in other notations.
//

import AppKit

struct ColorValue: Equatable {
    var red: Double, green: Double, blue: Double, alpha: Double

    init?(parsing raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if let value = Self.hex(text) { self = value; return }
        if let value = Self.functional(text) { self = value; return }
        return nil
    }

    init(red: Double, green: Double, blue: Double, alpha: Double = 1) {
        self.red = red; self.green = green; self.blue = blue; self.alpha = alpha
    }

    var nsColor: NSColor {
        NSColor(srgbRed: red, green: green, blue: blue, alpha: alpha)
    }

    var hexString: String {
        let base = String(format: "#%02X%02X%02X", byte(red), byte(green), byte(blue))
        return alpha < 1 ? base + String(format: "%02X", byte(alpha)) : base
    }

    var rgbString: String {
        alpha < 1
            ? "rgba(\(byte(red)), \(byte(green)), \(byte(blue)), \(String(format: "%.2g", alpha)))"
            : "rgb(\(byte(red)), \(byte(green)), \(byte(blue)))"
    }

    var hslString: String {
        let maxV = max(red, green, blue), minV = min(red, green, blue)
        let l = (maxV + minV) / 2
        var h = 0.0, s = 0.0
        let d = maxV - minV
        if d > 0 {
            s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
            switch maxV {
            case red:   h = (green - blue) / d + (green < blue ? 6 : 0)
            case green: h = (blue - red) / d + 2
            default:    h = (red - green) / d + 4
            }
            h /= 6
        }
        return "hsl(\(Int((h * 360).rounded())), \(Int((s * 100).rounded()))%, \(Int((l * 100).rounded()))%)"
    }

    /// True when dark text reads better on top of this colour.
    var isLight: Bool {
        (0.299 * red + 0.587 * green + 0.114 * blue) > 0.6 || alpha < 0.4
    }

    private func byte(_ v: Double) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }

    private static func hex(_ text: String) -> ColorValue? {
        var s = text
        if s.hasPrefix("#") { s.removeFirst() } else if s.hasPrefix("0x") { s.removeFirst(2) } else { return nil }
        guard [3, 4, 6, 8].contains(s.count), s.allSatisfy(\.isHexDigit) else { return nil }
        if s.count <= 4 { s = s.map { "\($0)\($0)" }.joined() }
        guard let value = UInt64(s, radix: 16) else { return nil }
        let hasAlpha = s.count == 8
        let shift: UInt64 = hasAlpha ? 8 : 0
        return ColorValue(
            red: Double((value >> (16 + shift)) & 0xFF) / 255,
            green: Double((value >> (8 + shift)) & 0xFF) / 255,
            blue: Double((value >> shift) & 0xFF) / 255,
            alpha: hasAlpha ? Double(value & 0xFF) / 255 : 1
        )
    }

    private static func functional(_ text: String) -> ColorValue? {
        guard let open = text.firstIndex(of: "("), text.hasSuffix(")") else { return nil }
        let name = text[..<open].trimmingCharacters(in: .whitespaces)
        let body = text[text.index(after: open)..<text.index(before: text.endIndex)]
        let parts = body
            .replacingOccurrences(of: "/", with: " ")
            .split(whereSeparator: { $0 == "," || $0 == " " })
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 3 || parts.count == 4 else { return nil }

        func number(_ s: String, scale: Double) -> Double? {
            if s.hasSuffix("%") { return Double(s.dropLast()).map { $0 / 100 } }
            return Double(s).map { $0 / scale }
        }
        let alpha = parts.count == 4 ? number(parts[3], scale: 1) : 1

        switch name {
        case "rgb", "rgba":
            guard let r = number(parts[0], scale: 255), let g = number(parts[1], scale: 255),
                  let b = number(parts[2], scale: 255), let a = alpha else { return nil }
            return ColorValue(red: r, green: g, blue: b, alpha: a)
        case "hsl", "hsla":
            guard let h = Double(parts[0].replacingOccurrences(of: "deg", with: "")),
                  let s = number(parts[1], scale: 100), let l = number(parts[2], scale: 100),
                  let a = alpha else { return nil }
            let c = (1 - abs(2 * l - 1)) * s
            let hp = (h.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360) / 60
            let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
            let (r1, g1, b1): (Double, Double, Double) = switch Int(hp) {
                case 0: (c, x, 0)
                case 1: (x, c, 0)
                case 2: (0, c, x)
                case 3: (0, x, c)
                case 4: (x, 0, c)
                default: (c, 0, x)
            }
            let m = l - c / 2
            return ColorValue(red: r1 + m, green: g1 + m, blue: b1 + m, alpha: a)
        default:
            return nil
        }
    }
}
