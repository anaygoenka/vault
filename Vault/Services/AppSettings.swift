//
//  AppSettings.swift
//  Vault
//
//  Every preference, observable and stored in UserDefaults.
//

import Foundation
import Observation
import Carbon.HIToolbox

struct HotKeyCombo: Codable, Equatable {
    var keyCode: UInt32
    /// Carbon modifier flags (cmdKey, shiftKey, optionKey, controlKey).
    var modifiers: UInt32
    var keyLabel: String

    static let `default` = HotKeyCombo(
        keyCode: UInt32(kVK_ANSI_V),
        modifiers: UInt32(cmdKey | shiftKey),
        keyLabel: "V"
    )

    var symbols: [String] {
        var parts: [String] = []
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        parts.append(keyLabel)
        return parts
    }

    var display: String { symbols.joined() }
}

@Observable
final class AppSettings {
    static let shared = AppSettings()

    private let defaults = UserDefaults.standard

    var retention: Retention { didSet { save(retention.rawValue, "retention") } }
    var maxItems: Int { didSet { save(maxItems, "maxItems") } }
    var pasteAutomatically: Bool { didSet { save(pasteAutomatically, "pasteAutomatically") } }
    var plainTextByDefault: Bool { didSet { save(plainTextByDefault, "plainTextByDefault") } }
    var captureImages: Bool { didSet { save(captureImages, "captureImages") } }
    var captureFiles: Bool { didSet { save(captureFiles, "captureFiles") } }
    var ignoreConcealed: Bool { didSet { save(ignoreConcealed, "ignoreConcealed") } }
    var moveReusedToTop: Bool { didSet { save(moveReusedToTop, "moveReusedToTop") } }
    var playSounds: Bool { didSet { save(playSounds, "playSounds") } }
    var excludedApps: [ExcludedApp] { didSet { saveCodable(excludedApps, "excludedApps") } }
    var hotKey: HotKeyCombo { didSet { saveCodable(hotKey, "hotKey") } }
    var hasOnboarded: Bool { didSet { save(hasOnboarded, "hasOnboarded") } }
    /// When set, capture is paused until this date. `distantFuture` means
    /// paused until resumed by hand.
    var pausedUntil: Date? { didSet { save(pausedUntil, "pausedUntil") } }

    var isPaused: Bool {
        guard let pausedUntil else { return false }
        return pausedUntil > .now
    }

    private init() {
        let d = UserDefaults.standard
        retention = Retention(rawValue: d.string(forKey: "retention") ?? "") ?? .month
        maxItems = d.object(forKey: "maxItems") as? Int ?? 1_000
        pasteAutomatically = d.object(forKey: "pasteAutomatically") as? Bool ?? true
        plainTextByDefault = d.object(forKey: "plainTextByDefault") as? Bool ?? false
        captureImages = d.object(forKey: "captureImages") as? Bool ?? true
        captureFiles = d.object(forKey: "captureFiles") as? Bool ?? true
        ignoreConcealed = d.object(forKey: "ignoreConcealed") as? Bool ?? true
        moveReusedToTop = d.object(forKey: "moveReusedToTop") as? Bool ?? true
        playSounds = d.object(forKey: "playSounds") as? Bool ?? false
        hasOnboarded = d.bool(forKey: "hasOnboarded")
        pausedUntil = d.object(forKey: "pausedUntil") as? Date
        excludedApps = Self.decode([ExcludedApp].self, d.data(forKey: "excludedApps")) ?? ExcludedApp.defaults
        hotKey = Self.decode(HotKeyCombo.self, d.data(forKey: "hotKey")) ?? .default
    }

    func isExcluded(_ bundleID: String?) -> Bool {
        guard let bundleID else { return false }
        return excludedApps.contains { $0.bundleID == bundleID }
    }

    private func save(_ value: Any?, _ key: String) {
        defaults.set(value, forKey: key)
    }

    private func saveCodable<T: Encodable>(_ value: T, _ key: String) {
        defaults.set(try? JSONEncoder().encode(value), forKey: key)
    }

    private static func decode<T: Decodable>(_ type: T.Type, _ data: Data?) -> T? {
        data.flatMap { try? JSONDecoder().decode(type, from: $0) }
    }
}

struct ExcludedApp: Codable, Hashable, Identifiable {
    var bundleID: String
    var name: String
    var id: String { bundleID }

    /// Password managers that do not mark their copies as concealed.
    static let defaults: [ExcludedApp] = [
        .init(bundleID: "com.apple.keychainaccess", name: "Keychain Access"),
        .init(bundleID: "com.apple.Passwords", name: "Passwords"),
    ]
}
