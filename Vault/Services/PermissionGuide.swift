//
//  PermissionGuide.swift
//  Vault
//
//  The one way Vault asks macOS for a privacy grant, built the same way as
//  FocusDragon's: PermissionFlow opens the pane and docks its drag card
//  under System Settings carrying Vault's own icon. Drag it into the list,
//  confirm, done. The card closes and Vault comes back the moment the grant
//  lands.
//
//  Vault needs exactly one grant, Accessibility, and only for one thing:
//  posting ⌘V into the app you were in, so a chosen clip lands where your
//  cursor is. Without it Vault still records history and copies the clip;
//  you press ⌘V yourself.
//
//  No system alert is fired alongside it. AXIsProcessTrustedWithOptions with
//  the prompt option puts a second, competing dialog on top of the pane.
//

import AppKit
import ApplicationServices
import Observation
import PermissionFlow

@Observable
final class PermissionGuide {
    static let shared = PermissionGuide()

    /// Live Accessibility state, refreshed on activation and while a grant
    /// is being watched.
    private(set) var accessibilityGranted = AXIsProcessTrusted()
    /// macOS has the grant, but this process still sees the old answer.
    /// Only a restart fixes that.
    private(set) var needsRelaunch = false

    @ObservationIgnored private let controller = PermissionFlow.makeController(
        configuration: .init(requiredAppURLs: [Bundle.main.bundleURL], promptForAccessibilityTrust: false)
    )
    @ObservationIgnored private var grantTimer: Timer?
    @ObservationIgnored private var grantDeadline = Date.distantPast

    private init() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated { PermissionGuide.shared.refresh() }
        }
    }

    @ObservationIgnored private var checking = false
    @ObservationIgnored private var ticks = 0

    func refresh() {
        let now = AXIsProcessTrusted()
        if now != accessibilityGranted { accessibilityGranted = now }
        if now {
            if needsRelaunch { needsRelaunch = false }
        } else {
            checkFreshProcess()
        }
    }

    /// Asks a new copy of Vault whether it is trusted. If it is and this
    /// process is not, the grant landed and only a restart is missing.
    private func checkFreshProcess() {
        guard !checking, !needsRelaunch, let executable = Bundle.main.executableURL else { return }
        checking = true
        Task.detached(priority: .userInitiated) {
            let process = Process()
            process.executableURL = executable
            process.arguments = ["--check-accessibility"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            var granted = false
            if (try? process.run()) != nil {
                process.waitUntilExit()
                let output = String(decoding: pipe.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
                granted = output.contains("granted")
            }
            await MainActor.run { PermissionGuide.shared.finishFreshCheck(granted: granted) }
        }
    }

    private func finishFreshCheck(granted: Bool) {
        checking = false
        guard granted, !accessibilityGranted, !needsRelaunch else { return }
        needsRelaunch = true
        grantLanded()
    }

    /// What System Settings calls the pane on this Mac. macOS 27 renamed
    /// Accessibility to "Device Control and Data Access"; the deep link did
    /// not change.
    var paneName: String {
        String(localized: PermissionFlowResources.accessibilityNameResource)
    }

    /// Opens the pane with the drag card beside it. Call only from a click:
    /// the card flies out from the pointer.
    func requestAccessibility() {
        refresh()
        guard !accessibilityGranted else {
            NSWorkspace.shared.open(PermissionFlowPane.accessibility.settingsURL)
            return
        }
        let pointer = NSEvent.mouseLocation
        controller.authorize(
            pane: .accessibility,
            suggestedAppURLs: [Bundle.main.bundleURL],
            sourceFrameInScreen: CGRect(x: pointer.x - 16, y: pointer.y - 16, width: 32, height: 32)
        )
        watchForGrant()
    }

    /// PermissionFlow closes its card when System Settings closes, but not
    /// when the grant lands. Poll for up to ten minutes; on grant, close the
    /// card and bring Vault forward.
    private func watchForGrant() {
        grantTimer?.invalidate()
        grantDeadline = Date().addingTimeInterval(10 * 60)
        grantTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { _ in
            Task { @MainActor in PermissionGuide.shared.tick() }
        }
    }

    private func tick() {
        ticks += 1
        let now = AXIsProcessTrusted()
        if now != accessibilityGranted { accessibilityGranted = now }
        if accessibilityGranted {
            grantLanded()
        } else if Date() > grantDeadline {
            stopWatching()
        } else if ticks % 3 == 0 {
            checkFreshProcess()
        }
    }

    private func grantLanded() {
        stopWatching()
        controller.closePanel()
        NSApp.activate()
        NotificationCenter.default.post(name: .vaultAccessibilityGranted, object: nil)
    }

    private func stopWatching() {
        grantTimer?.invalidate()
        grantTimer = nil
    }

    /// Restarts Vault. macOS sometimes only applies a fresh Accessibility
    /// grant to a new process.
    func relaunch() {
        UserDefaults.standard.synchronize()
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.6; /usr/bin/open \"$0\"", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}

extension Notification.Name {
    static let vaultAccessibilityGranted = Notification.Name("VaultAccessibilityGranted")
}
