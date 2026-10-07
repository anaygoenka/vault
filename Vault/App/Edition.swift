//
//  Edition.swift
//  Vault
//
//  Vault ships in two editions from one codebase. The App Store edition is
//  sandboxed and copies the chosen clip for you to paste. The direct edition
//  can also press ⌘V for you, which needs Accessibility.
//

import ApplicationServices

enum Edition {
    #if APPSTORE
    static let canPasteForYou = false
    #else
    static let canPasteForYou = true
    #endif

    /// Whether choosing a clip will paste it right now, rather than only
    /// copying it.
    static var pastesForYou: Bool {
        #if APPSTORE
        return false
        #else
        return AppSettings.shared.pasteAutomatically && PermissionGuide.shared.accessibilityGranted
        #endif
    }

    /// The verb for choosing a clip: "Paste" or "Copy".
    static var chooseVerb: String { pastesForYou ? "Paste" : "Copy" }
}
