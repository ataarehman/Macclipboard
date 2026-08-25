import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct PrivacySettingsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    Text(AppIdentity.privacyStatement)
                        .font(.headline)
                    Text("\(AppIdentity.displayName) does not upload clipboard history, send analytics, or use network services. Everything stays in this Mac’s Application Support folder.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(4)
            }

            GroupBox("Accessibility") {
                HStack {
                    Circle()
                        .fill(state.accessibility.isTrusted ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                    Text(state.accessibility.isTrusted ? "Enabled" : "Required")
                    Spacer()
                    Button("Enable Accessibility Permission") {
                        state.accessibility.requestPermission()
                    }
                    Button("Open System Settings") {
                        state.accessibility.openSystemSettings()
                    }
                }
                Text("Needed so \(AppIdentity.displayName) can paste the selected item into the app you were using. History still works without it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            GroupBox("Pause Monitoring") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(state.pause.statusTitle)
                    HStack {
                        Button("5 minutes") { state.pause.pause(.minutes(5)); state.menuBar.reload() }
                        Button("15 minutes") { state.pause.pause(.minutes(15)); state.menuBar.reload() }
                        Button("1 hour") { state.pause.pause(.minutes(60)); state.menuBar.reload() }
                        Button("Until resumed") { state.pause.pause(.indefinitely); state.menuBar.reload() }
                    }
                    if state.pause.isPaused {
                        Button("Resume") { state.pause.resume(); state.menuBar.reload() }
                    }
                }
            }

            ExcludedAppsView()
        }
    }
}

struct ExcludedAppsView: View {
    @Environment(AppState.self) private var state

    var body: some View {
        GroupBox("Excluded Applications") {
            VStack(alignment: .leading, spacing: 10) {
                Text("Clipboard copies made while these apps are frontmost are not saved.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button("+ Add Application") {
                    addApplication()
                }

                if state.settings.excludedBundleIdentifiers.isEmpty {
                    Text("None")
                        .foregroundStyle(.tertiary)
                } else {
                    ForEach(state.settings.excludedBundleIdentifiers, id: \.self) { identifier in
                        HStack {
                            if let icon = AppIconService.icon(forBundleIdentifier: identifier) {
                                Image(nsImage: icon)
                                    .resizable()
                                    .frame(width: 16, height: 16)
                            }
                            Text(AppIconService.applicationName(forBundleIdentifier: identifier))
                            Spacer()
                            Button("Remove") {
                                state.settings.removeExcludedApp(bundleIdentifier: identifier)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func addApplication() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.prompt = "Add"
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            if let bundle = Bundle(url: url), let identifier = bundle.bundleIdentifier {
                state.settings.addExcludedApp(bundleIdentifier: identifier)
            }
        }
    }
}
