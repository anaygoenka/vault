//
//  PasteService.swift
//  Vault
//
//  Puts a clip back on the pasteboard and, with Accessibility granted,
//  presses ⌘V in the app you were using.
//

import AppKit
import ApplicationServices
import Carbon.HIToolbox

enum PasteService {
    enum Outcome { case pasted, copied }

    /// Writes `item` to the general pasteboard.
    static func copy(_ item: ClipItem, plainText: Bool = false) {
        let pb = NSPasteboard.general
        pb.clearContents()
        let store = HistoryStore.shared

        switch item.kind {
        case .image:
            if let blob = item.imageBlob, let data = try? Data(contentsOf: store.blobURL(blob)) {
                pb.setData(data, forType: .png)
                if let tiff = NSImage(data: data)?.tiffRepresentation { pb.setData(tiff, forType: .tiff) }
            }
        case .file:
            let urls = (item.filePaths ?? []).map { URL(fileURLWithPath: $0) as NSURL }
            pb.writeObjects(urls)
            if plainText, let text = item.text { pb.setString(text, forType: .string) }
        case .link:
            if let text = item.text {
                pb.setString(text, forType: .string)
                if !plainText, let url = item.url { pb.setString(url.absoluteString, forType: .URL) }
            }
        case .text, .color:
            if let text = item.text {
                pb.setString(text, forType: .string)
                if !plainText, let rtf = item.rtfBlob, let data = try? Data(contentsOf: store.blobURL(rtf)) {
                    pb.setData(data, forType: .rtf)
                }
            }
        }
        ClipboardMonitor.shared.noteOwnWrite()
    }

    /// Copies a raw string (for example a colour in another notation).
    static func copy(string: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
        ClipboardMonitor.shared.noteOwnWrite()
    }

    /// Copies, then pastes into the frontmost app if allowed. Call after the
    /// panel has gone so the keystroke lands in the right window.
    @discardableResult
    static func paste(_ item: ClipItem, plainText: Bool) -> Outcome {
        copy(item, plainText: plainText)
        HistoryStore.shared.markUsed(item.id)
        #if APPSTORE
        return .copied
        #else
        guard AppSettings.shared.pasteAutomatically, AXIsProcessTrusted() else { return .copied }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { postCommandV() }
        return .pasted
        #endif
    }

    #if !APPSTORE
    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let key = CGKeyCode(kVK_ANSI_V)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        // Set explicitly so a still-held ⇧ from ⇧⌘V does not turn this
        // into Paste and Match Style.
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cgSessionEventTap)
        up?.post(tap: .cgSessionEventTap)
    }
    #endif
}
