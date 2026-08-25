import SwiftUI

struct StorageSettingsView: View {
    @Environment(AppState.self) private var state
    @State private var confirmClearAll = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            LabeledContent("Clipboard Items", value: "\(state.repository.items.count)")
            LabeledContent("Storage Used", value: ByteCountFormatter.string(fromByteCount: state.repository.storageBytes, countStyle: .file))
            Text("Data location: ~/Library/Application Support/\(AppIdentity.supportDirectoryName)")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("Clear Unpinned History") {
                    state.repository.clearUnpinned()
                    state.panel.reloadContent()
                }
                Button("Clear All History", role: .destructive) {
                    confirmClearAll = true
                }
            }

            Menu("Clear history older than") {
                Button("1 hour") { state.repository.clearOlderThan(Date().addingTimeInterval(-3600)) }
                Button("24 hours") { state.repository.clearOlderThan(Date().addingTimeInterval(-86_400)) }
                Button("7 days") { state.repository.clearOlderThan(Date().addingTimeInterval(-604_800)) }
            }
        }
        .confirmationDialog("Clear everything, including pinned items?", isPresented: $confirmClearAll, titleVisibility: .visible) {
            Button("Clear Everything", role: .destructive) {
                state.repository.clearAll()
                state.panel.reloadContent()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}
