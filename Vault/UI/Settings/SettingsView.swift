//
//  SettingsView.swift
//  Vault
//

import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    /// The tab Settings opens on.
    static var initialTab = "general"
    @State private var tab = SettingsView.initialTab

    var body: some View {
        TabView(selection: $tab) {
            Tab("General", systemImage: "gearshape", value: "general") { GeneralSettings() }
            Tab("History", systemImage: "clock.arrow.circlepath", value: "history") { HistorySettings() }
            Tab("Privacy", systemImage: "hand.raised", value: "privacy") { PrivacySettings() }
            #if !APPSTORE
            Tab("Permissions", systemImage: "lock.shield", value: "permissions") { PermissionSettings() }
            #endif
        }
        .frame(width: 620, height: 560)
    }
}

// MARK: - General

private struct GeneralSettings: View {
    @Bindable private var settings = AppSettings.shared
    private let launch = LaunchAtLogin.shared

    var body: some View {
        Form {
            Section {
                HStack(spacing: 14) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Vault").font(.system(size: 18, weight: .semibold))
                        Text("Everything you copy, one shortcut away.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0")")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 4)
            }

            Section("Shortcut") {
                LabeledContent("Open Vault") {
                    HotKeyRecorder()
                }
                if HotKeyCenter.shared.registrationFailed {
                    Label("Another app is using this shortcut. Choose a different one.", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.callout)
                }
            }

            Section(Edition.canPasteForYou ? "Pasting" : "Copying") {
                #if !APPSTORE
                Toggle(isOn: $settings.pasteAutomatically) {
                    Text("Paste into the current app")
                    Text("Choosing a clip pastes it where your cursor is. When off, Vault copies it and you press ⌘V.")
                }
                #endif
                Toggle(isOn: $settings.plainTextByDefault) {
                    Text(Edition.canPasteForYou ? "Paste as plain text by default" : "Copy as plain text by default")
                    Text("Strips fonts and colours. Hold ⇧ when choosing a clip to do the opposite.")
                }
                Toggle("Move clips to the top when reused", isOn: $settings.moveReusedToTop)
            }

            Section("System") {
                Toggle("Open Vault at login", isOn: Binding(
                    get: { launch.isEnabled },
                    set: { launch.set($0) }
                ))
                if launch.needsApproval {
                    Button("Approve in Login Items…") { launch.openLoginItems() }
                }
                Toggle("Play a sound when something is copied", isOn: $settings.playSounds)
            }
        }
        .formStyle(.grouped)
    }
}

/// Click, then press the new combination. Esc cancels.
private struct HotKeyRecorder: View {
    @State private var recording = false
    @State private var monitor: Any?
    private let settings = AppSettings.shared

    var body: some View {
        HStack(spacing: 8) {
            Button {
                recording ? stop() : start()
            } label: {
                HStack(spacing: 3) {
                    if recording {
                        Text("Type shortcut…")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(settings.hotKey.symbols, id: \.self) { KeyCap($0) }
                    }
                }
                .frame(minWidth: 110, minHeight: 22)
            }
            .buttonStyle(.glass)
            .tint(recording ? .accentColor : nil)

            if settings.hotKey != .default, !recording {
                Button("Reset") {
                    settings.hotKey = .default
                    reRegister()
                }
                .buttonStyle(.borderless)
            }
        }
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        HotKeyCenter.shared.suspend()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Escape
                stop()
                return nil
            }
            if let combo = HotKeyCombo(event: event) {
                settings.hotKey = combo
                stop()
                return nil
            }
            NSSound.beep()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { reRegister() }
        recording = false
    }

    private func reRegister() {
        (NSApp.delegate as? AppDelegate)?.registerHotKey()
    }
}

// MARK: - History

private struct HistorySettings: View {
    @Bindable private var settings = AppSettings.shared
    private let store = HistoryStore.shared
    @State private var pendingRetention: Retention?

    private let limits = [100, 250, 500, 1_000, 2_500, 5_000, 10_000]

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Keep history for")
                        .font(.headline)
                    RetentionPicker(selection: Binding(
                        get: { settings.retention },
                        set: { choose($0) }
                    ))
                    Text(retentionFootnote)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section {
                Picker("Keep at most", selection: $settings.maxItems) {
                    ForEach(limits, id: \.self) { Text("\($0.formatted()) clips").tag($0) }
                }
                .onChange(of: settings.maxItems) { store.purge() }
                Toggle("Record images", isOn: $settings.captureImages)
                Toggle("Record copied files", isOn: $settings.captureFiles)
            }

            Section("Storage") {
                LabeledContent("Clips", value: "\(store.items.count.formatted()) (\(store.pinned.count) pinned)")
                LabeledContent("On disk", value: ByteCountFormatter.string(fromByteCount: Int64(store.diskUsage), countStyle: .file))
                HStack {
                    Button("Show in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.directory])
                    }
                    Spacer()
                    Button("Clear History…", role: .destructive) {
                        if MenuBarContent.confirmClearAlert() { store.clear() }
                    }
                    .disabled(store.items.allSatisfy(\.isPinned))
                }
            }
        }
        .formStyle(.grouped)
        .alert(
            "Shorten your history?",
            isPresented: Binding(get: { pendingRetention != nil }, set: { if !$0 { pendingRetention = nil } }),
            presenting: pendingRetention
        ) { retention in
            Button("Delete \(store.countExpiring(under: retention)) Clips", role: .destructive) {
                settings.retention = retention
                store.purge()
            }
            Button("Cancel", role: .cancel) {}
        } message: { retention in
            Text("\(store.countExpiring(under: retention)) clips are older than \(retention.label.lowercased()) and will be deleted now. Pinned clips are kept.")
        }
    }

    private var retentionFootnote: String {
        switch settings.retention {
        case .forever: "Clips are kept until you delete them or reach the clip limit. Pinned clips are always kept."
        default: "Clips older than \(settings.retention.label.lowercased()) are deleted automatically. Pinned clips are always kept."
        }
    }

    /// Asks before a shorter window deletes anything.
    private func choose(_ retention: Retention) {
        if store.countExpiring(under: retention) > 0 {
            pendingRetention = retention
        } else {
            settings.retention = retention
            store.purge()
        }
    }
}

/// A segmented control: one glass track, with a solid pill that slides to
/// the chosen period.
struct RetentionPicker: View {
    @Binding var selection: Retention
    var options: [Retention] = Retention.allCases
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 0) {
            ForEach(options) { option in
                let selected = option == selection
                Button {
                    withAnimation(.snappy(duration: 0.28)) { selection = option }
                } label: {
                    Text(option.label)
                        .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                        .foregroundStyle(selected ? AnyShapeStyle(.white) : AnyShapeStyle(.secondary))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background {
                            if selected {
                                Capsule()
                                    .fill(Color.accentColor)
                                    .shadow(color: Color.accentColor.opacity(0.3), radius: 4, y: 1)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                        .contentShape(.capsule)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .glassEffect(.regular, in: .capsule)
    }
}

// MARK: - Privacy

private struct PrivacySettings: View {
    @Bindable private var settings = AppSettings.shared
    @State private var selection: ExcludedApp.ID?

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $settings.ignoreConcealed) {
                    Text("Ignore passwords and one-time codes")
                    Text("Skips copies that password managers such as 1Password and Bitwarden mark as private.")
                }
            }

            Section {
                if settings.excludedApps.isEmpty {
                    Text("No apps excluded")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.excludedApps) { app in
                        HStack(spacing: 10) {
                            AppIconView(bundleID: app.bundleID, size: 22)
                            Text(app.name)
                            Spacer()
                            Button {
                                settings.excludedApps.removeAll { $0.id == app.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Stop ignoring \(app.name)")
                        }
                    }
                }
                Button("Add App…", systemImage: "plus") { addApp() }
            } header: {
                Text("Never record copies from")
            } footer: {
                Text("Vault ignores anything copied while one of these apps is in front.")
                    .foregroundStyle(.secondary)
            }

            Section {
                PauseControl()
            }
        }
        .formStyle(.grouped)
    }

    private func addApp() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        panel.prompt = "Exclude"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let bundle = Bundle(url: url), let id = bundle.bundleIdentifier,
                  !settings.excludedApps.contains(where: { $0.bundleID == id }) else { continue }
            let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            settings.excludedApps.append(ExcludedApp(bundleID: id, name: name))
        }
    }
}

private struct PauseControl: View {
    private let settings = AppSettings.shared

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(settings.isPaused ? "Recording is paused" : "Recording is on")
                Text(settings.isPaused ? "Nothing you copy is being saved." : "Pause before copying something sensitive.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if settings.isPaused {
                Button("Resume") { settings.pausedUntil = nil }
                    .buttonStyle(.glassProminent)
            } else {
                Menu("Pause") {
                    Button("For 5 Minutes") { settings.pausedUntil = .now.addingTimeInterval(300) }
                    Button("For 15 Minutes") { settings.pausedUntil = .now.addingTimeInterval(900) }
                    Button("For 1 Hour") { settings.pausedUntil = .now.addingTimeInterval(3_600) }
                    Divider()
                    Button("Until I Resume") { settings.pausedUntil = .distantFuture }
                }
                .fixedSize()
            }
        }
    }
}

// MARK: - Permissions

#if !APPSTORE

private struct PermissionSettings: View {
    private let guide = PermissionGuide.shared

    var body: some View {
        Form {
            Section {
                PermissionCard()
            } footer: {
                Text("Vault records your history and opens with \(AppSettings.shared.hotKey.display) without any permission. Accessibility is only used to press ⌘V for you after you choose a clip. Vault never reads your screen or your keystrokes.")
                    .foregroundStyle(.secondary)
            }

            Section("Troubleshooting") {
                LabeledContent("Pasting still not working?") {
                    Button("Restart Vault") { guide.relaunch() }
                }
                LabeledContent("Open System Settings directly") {
                    Button("Open \(guide.paneName)") {
                        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear { guide.refresh() }
    }
}

/// The Accessibility row, shared by Settings and onboarding.
struct PermissionCard: View {
    private let guide = PermissionGuide.shared

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: guide.accessibilityGranted || guide.needsRelaunch ? "checkmark.shield.fill" : "hand.point.up.left.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(guide.accessibilityGranted || guide.needsRelaunch ? .green : .accentColor)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 46, height: 46)
                .glassEffect(.regular.tint((guide.accessibilityGranted ? Color.green : .accentColor).opacity(0.15)), in: .rect(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 3) {
                Text("Paste for you")
                    .font(.system(size: 14, weight: .semibold))
                Text(guide.accessibilityGranted
                     ? "Granted. Choosing a clip pastes it straight into your app."
                     : guide.needsRelaunch
                        ? "Access granted. Restart Vault once to switch it on."
                        : "Lets Vault press ⌘V for you. Drag Vault into \(guide.paneName) in the window that opens.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if guide.accessibilityGranted {
                Label("Granted", systemImage: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.green)
            } else if guide.needsRelaunch {
                Button("Restart Vault") { guide.relaunch() }
                    .buttonStyle(.glassProminent)
            } else {
                Button("Grant Access") { guide.requestAccessibility() }
                    .buttonStyle(.glassProminent)
            }
        }
        .padding(.vertical, 6)
        .animation(.snappy, value: guide.accessibilityGranted)
        .animation(.snappy, value: guide.needsRelaunch)
    }
}
#endif
