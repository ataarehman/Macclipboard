import SwiftUI

struct GeneralSettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        @Bindable var settings = state.settings
        Form {
            Section("Startup") {
                Toggle("Launch \(AppIdentity.displayName) at login", isOn: Binding(
                    get: { state.launchAtLogin.isEnabled || settings.launchAtLogin },
                    set: { enabled in
                        settings.launchAtLogin = enabled
                        state.launchAtLogin.setEnabled(enabled)
                    }
                ))
                if let message = state.launchAtLogin.statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Show icon in Dock", isOn: $settings.showDockIcon)
            }

            Section("History") {
                Picker("Maximum history", selection: $settings.maxHistoryItems) {
                    ForEach(HistoryLimit.allCases) { limit in
                        Text(limit.title).tag(limit.rawValue)
                    }
                }
                .onChange(of: settings.maxHistoryItems) { _, _ in
                    state.repository.applyLimit()
                }
            }

            Section("Appearance") {
                Picker("Appearance", selection: $settings.appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
            }

            Section("Popup") {
                Picker("Open on", selection: $settings.panelPlacement) {
                    ForEach(PanelPlacement.allCases) { placement in
                        Text(placement.title).tag(placement)
                    }
                }
                Toggle("Paste immediately after selection", isOn: $settings.pasteImmediatelyOnClick)
            }
        }
        .formStyle(.grouped)
    }
}
