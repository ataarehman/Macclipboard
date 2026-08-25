import SwiftUI

struct OnboardingView: View {
    var shortcut: Shortcut
    var isTrusted: Bool
    var onEnableAccessibility: () -> Void
    var onOpenSettings: () -> Void
    var onFinished: () -> Void

    @State private var page = 0

    var body: some View {
        VStack(spacing: 24) {
            Group {
                switch page {
                case 0:
                    onboardingPage(
                        title: "Meet \(AppIdentity.displayName)",
                        bodyText: "Your Windows-style clipboard history for Mac."
                    )
                case 1:
                    onboardingPage(
                        title: "Copy normally.",
                        bodyText: "⌘C"
                    )
                case 2:
                    onboardingPage(
                        title: "Open your history.",
                        bodyText: shortcut.displayString
                    )
                case 3:
                    onboardingPage(
                        title: "Paste anything you've copied.",
                        bodyText: "↑ ↓ Enter"
                    )
                default:
                    accessibilityPage
                }
            }
            .frame(height: 220)

            HStack {
                if page > 0 {
                    Button("Back") { page -= 1 }
                }
                Spacer()
                if page < 4 {
                    Button("Continue") { page += 1 }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("Done") { onFinished() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .padding(28)
        .frame(width: 460, height: 360)
    }

    private func onboardingPage(title: String, bodyText: String) -> some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)
            Text(bodyText)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var accessibilityPage: some View {
        VStack(spacing: 12) {
            Text("\(AppIdentity.displayName) needs Accessibility permission so it can paste the clipboard item you select into your active application.")
                .multilineTextAlignment(.center)
            Text(AppIdentity.privacyStatement)
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                Circle()
                    .fill(isTrusted ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text(isTrusted ? "Accessibility  Enabled" : "Accessibility  Required")
            }
            Button("Enable Accessibility Permission", action: onEnableAccessibility)
            Button("Open System Settings", action: onOpenSettings)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

@MainActor
final class OnboardingWindowController {
    private var window: NSWindow?

    func show(state: AppState) {
        let window = makeWindow()
        let root = OnboardingView(
            shortcut: state.settings.shortcut,
            isTrusted: state.accessibility.isTrusted,
            onEnableAccessibility: { state.accessibility.requestPermission() },
            onOpenSettings: { state.accessibility.openSystemSettings() },
            onFinished: { [weak self] in
                state.settings.hasCompletedOnboarding = true
                self?.window?.close()
            }
        )
        window.contentView = NSHostingView(rootView: root)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        if let window { return window }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 360),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = AppIdentity.displayName
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        return window
    }
}
