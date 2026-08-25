import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(state: AppState) {
        let window = makeWindowIfNeeded()
        let root = SettingsView()
            .environment(state)
        window.contentView = NSHostingView(rootView: root)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindowIfNeeded() -> NSWindow {
        if let window { return window }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 520),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "\(AppIdentity.displayName) Settings"
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
        return window
    }
}

struct SettingsView: View {
    @Environment(AppState.self) private var state
    @State private var tab = SettingsTab.general

    var body: some View {
        VStack(spacing: 0) {
            Picker("Section", selection: $tab) {
                ForEach(SettingsTab.allCases) { item in
                    Text(item.title).tag(item)
                }
            }
            .pickerStyle(.segmented)
            .padding(16)

            Divider()

            ScrollView {
                Group {
                    switch tab {
                    case .general:
                        GeneralSettingsView()
                    case .keyboard:
                        ShortcutSettingsView()
                    case .privacy:
                        PrivacySettingsView()
                    case .storage:
                        StorageSettingsView()
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 560, height: 520)
        .environment(state)
    }
}

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case keyboard
    case privacy
    case storage

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general: "General"
        case .keyboard: "Keyboard"
        case .privacy: "Privacy"
        case .storage: "Storage"
        }
    }
}
