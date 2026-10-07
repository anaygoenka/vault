//
//  LaunchAtLogin.swift
//  Vault
//

import Observation
import ServiceManagement

@Observable
final class LaunchAtLogin {
    static let shared = LaunchAtLogin()

    private(set) var isEnabled = SMAppService.mainApp.status == .enabled
    private(set) var needsApproval = SMAppService.mainApp.status == .requiresApproval

    func set(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
        } catch {
            NSLog("Vault: launch at login change failed: \(error.localizedDescription)")
        }
        refresh()
    }

    func refresh() {
        isEnabled = SMAppService.mainApp.status == .enabled
        needsApproval = SMAppService.mainApp.status == .requiresApproval
    }

    func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
