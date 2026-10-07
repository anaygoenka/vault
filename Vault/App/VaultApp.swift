//
//  VaultApp.swift
//  Vault
//
//  A menu bar app: no Dock icon, one glass panel on ⇧⌘V.
//

import SwiftUI


struct VaultApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarContent()
        } label: {
            MenuBarIcon()
        }
        .menuBarExtraStyle(.menu)
    }
}

private struct MenuBarIcon: View {
    private let settings = AppSettings.shared

    var body: some View {
        Image(systemName: settings.isPaused ? "pause.circle" : "list.clipboard")
            .accessibilityLabel(settings.isPaused ? "Vault, paused" : "Vault")
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = HistoryStore.shared
        ClipboardMonitor.shared.start()
        registerHotKey()
        LaunchAtLogin.shared.refresh()

        #if DEBUG
        // Launch flags for checking the windows without a key press.
        let args = ProcessInfo.processInfo.arguments
        DebugSnapshot.scheduleIfRequested()
        if MarketingShots.runIfRequested() { return }
        if args.contains("--show-panel") { DispatchQueue.main.asyncAfter(deadline: .now() + 1) { PanelController.shared.show() }; return }
        if args.contains("--show-settings") { Self.openSettings(); return }
        if args.contains("--show-onboarding") { Self.openOnboarding(); return }
        #endif

        if !AppSettings.shared.hasOnboarded {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { Self.openOnboarding() }
        }
    }

    /// Opening Vault from Finder or Spotlight while it is already running
    /// shows the panel, since there is no window to bring back.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { PanelController.shared.show() }
        return true
    }

    func registerHotKey() {
        HotKeyCenter.shared.register(AppSettings.shared.hotKey) {
            PanelController.shared.toggle()
        }
    }

    static func openSettings() {
        WindowPresenter.shared.present(
            id: "settings",
            title: "Vault Settings",
            size: NSSize(width: 620, height: 560),
            content: SettingsView()
        )
    }

    static func openOnboarding() {
        WindowPresenter.shared.present(
            id: "onboarding",
            title: "Welcome to Vault",
            size: NSSize(width: 520, height: 480),
            hidesTitle: true,
            content: OnboardingView()
        )
    }
}
