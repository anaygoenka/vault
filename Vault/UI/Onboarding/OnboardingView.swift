//
//  OnboardingView.swift
//  Vault
//
//  First launch, in three quiet steps: the shortcut, the one permission,
//  and how long to keep history. Each step is one idea and one action.
//

import SwiftUI

struct OnboardingView: View {
    /// A restart for the Accessibility grant resumes on the next step.
    @State private var step: Int = {
        let resume = UserDefaults.standard.integer(forKey: "onboardingResumeStep")
        UserDefaults.standard.removeObject(forKey: "onboardingResumeStep")
        return resume
    }()
    @Bindable private var settings = AppSettings.shared
    #if !APPSTORE
    private let guide = PermissionGuide.shared
    #endif
    private let launch = LaunchAtLogin.shared

    private enum Step { case welcome, permission, history }

    #if APPSTORE
    private let steps: [Step] = [.welcome, .history]
    #else
    private let steps: [Step] = [.welcome, .permission, .history]
    #endif

    private var stepCount: Int { steps.count }
    private var current: Step { steps[min(step, steps.count - 1)] }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch current {
                case .welcome: welcome
                case .permission: permissionStep
                case .history: history
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .transition(.asymmetric(
                insertion: .offset(x: 24).combined(with: .opacity),
                removal: .offset(x: -24).combined(with: .opacity)
            ))
            .id(step)

            footer
        }
        .padding(.horizontal, 48)
        .padding(.top, 36)
        .padding(.bottom, 26)
        .frame(width: 520, height: 480)
        .background(backdrop)
        #if !APPSTORE
        .onAppear { guide.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .vaultAccessibilityGranted)) { _ in
            if current == .permission, guide.accessibilityGranted { advance() }
        }
        #endif
    }

    private var backdrop: some View {
        ZStack(alignment: .top) {
            Color(nsColor: .windowBackgroundColor)
            RadialGradient(
                colors: [Color.accentColor.opacity(0.22), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 0) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
                .shadow(color: .accentColor.opacity(0.3), radius: 20, y: 8)
            title("Vault", subtitle: Edition.canPasteForYou
                  ? "Everything you copy, one shortcut away."
                  : "Everything you copy, one shortcut away. Pick a clip, then press ⌘V.")
                .padding(.top, 20)
            HStack(spacing: 6) {
                ForEach(settings.hotKey.symbols, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .frame(minWidth: 44, minHeight: 44)
                        .padding(.horizontal, key.count > 1 ? 8 : 0)
                        .glassEffect(.regular, in: .rect(cornerRadius: 11))
                }
            }
            .padding(.top, 32)
        }
    }

    @ViewBuilder private var permissionStep: some View {
        #if !APPSTORE
        permission
        #endif
    }

    #if !APPSTORE
    private var permission: some View {
        VStack(spacing: 0) {
            StepIcon(
                symbol: permissionDone ? "checkmark" : "command",
                tint: permissionDone ? .green : .accentColor
            )
            title(
                "Paste in one keystroke",
                subtitle: permissionDone
                    ? "All set. Choosing a clip pastes it where you’re typing."
                    : "Allow Vault to press ⌘V for you. Nothing else is accessed."
            )
            .padding(.top, 20)

            Group {
                if guide.accessibilityGranted {
                    Label("Allowed", systemImage: "checkmark.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.green)
                } else if guide.needsRelaunch {
                    Button("Restart Vault") { restartForGrant() }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                } else {
                    Button("Allow Access") { guide.requestAccessibility() }
                        .buttonStyle(.glassProminent)
                        .controlSize(.large)
                }
            }
            .frame(height: 36)
            .padding(.top, 28)
        }
        .animation(.snappy, value: guide.accessibilityGranted)
        .animation(.snappy, value: guide.needsRelaunch)
    }

    #endif

    private var history: some View {
        VStack(spacing: 0) {
            StepIcon(symbol: "clock", tint: .accentColor)
            title("Keep history for", subtitle: "Older clips clear themselves. Pinned clips stay.")
                .padding(.top, 20)
            RetentionPicker(selection: $settings.retention, options: [.day, .week, .month, .year, .forever])
                .padding(.top, 28)
            Toggle("Open at login", isOn: Binding(get: { launch.isEnabled }, set: { launch.set($0) }))
                .toggleStyle(.checkbox)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
                .padding(.top, 22)
        }
    }

    // MARK: - Pieces

    #if !APPSTORE
    private var permissionDone: Bool { guide.accessibilityGranted || guide.needsRelaunch }
    #endif

    /// On the permission step, "Not Now" replaces Continue until granted.
    private var waitingOnPermission: Bool {
        #if APPSTORE
        return false
        #else
        return current == .permission && !guide.accessibilityGranted
        #endif
    }

    private func title(_ text: String, subtitle: String) -> some View {
        VStack(spacing: 8) {
            Text(text)
                .font(.system(size: 26, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 6) {
                ForEach(0..<stepCount, id: \.self) { index in
                    Capsule()
                        .fill(index == step ? Color.accentColor : Color.primary.opacity(0.15))
                        .frame(width: index == step ? 18 : 6, height: 6)
                }
            }
            .animation(.snappy, value: step)

            Spacer()

            if step > 0 {
                Button("Back") { withAnimation(.snappy(duration: 0.3)) { step -= 1 } }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
                    .padding(.trailing, 10)
            }
            if waitingOnPermission {
                Button("Not Now") { advance() }
                    .buttonStyle(.glass)
                    .controlSize(.large)
            } else {
                Button(step == stepCount - 1 ? "Done" : "Continue") { advance() }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    #if !APPSTORE
    private func restartForGrant() {
        UserDefaults.standard.set(2, forKey: "onboardingResumeStep")
        guide.relaunch()
    }
    #endif

    private func advance() {
        if step < stepCount - 1 {
            withAnimation(.snappy(duration: 0.3)) { step += 1 }
        } else {
            settings.hasOnboarded = true
            HistoryStore.shared.purge()
            WindowPresenter.shared.close("onboarding")
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                PanelController.shared.show()
            }
        }
    }
}

/// One symbol in a glass circle, used at the top of each step.
private struct StepIcon: View {
    let symbol: String
    let tint: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 30, weight: .medium))
            .foregroundStyle(tint)
            .contentTransition(.symbolEffect(.replace))
            .frame(width: 80, height: 80)
            .glassEffect(.regular.tint(tint.opacity(0.12)), in: .circle)
    }
}
