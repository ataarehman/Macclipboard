import SwiftUI

struct ShortcutSettingsView: View {
    @Environment(AppState.self) private var state
    @State private var pendingShortcut: Shortcut?
    @State private var pendingConflict: ShortcutConflict?

    var body: some View {
        @Bindable var settings = state.settings
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcut")
                .font(.headline)
            Text("Open Clipboard")
                .foregroundStyle(.secondary)

            ShortcutRecorderView(
                shortcut: settings.shortcut,
                onRecorded: { candidate in
                    if let conflict = ShortcutConflictDetector.conflict(for: candidate) {
                        pendingShortcut = candidate
                        pendingConflict = conflict
                    } else {
                        apply(candidate)
                    }
                },
                onRecordingChange: { recording in
                    state.hotKey.setEnabled(!recording)
                }
            )

            Button("Reset to Default") {
                apply(.default)
            }

            if let error = state.hotKey.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("Press a combination to change the shortcut.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .alert(
            pendingConflict?.title ?? "Shortcut in use",
            isPresented: Binding(
                get: { pendingConflict != nil },
                set: { if !$0 { pendingConflict = nil; pendingShortcut = nil } }
            )
        ) {
            Button("Cancel", role: .cancel) {
                pendingConflict = nil
                pendingShortcut = nil
            }
            Button("Use Anyway") {
                if let pendingShortcut {
                    apply(pendingShortcut)
                }
                pendingConflict = nil
                pendingShortcut = nil
            }
        } message: {
            Text(pendingConflict?.message ?? "")
        }
    }

    private func apply(_ shortcut: Shortcut) {
        state.settings.shortcut = shortcut
        state.hotKey.setShortcut(shortcut)
        state.menuBar.reload()
    }
}

struct ShortcutRecorderView: View {
    let shortcut: Shortcut
    var onRecorded: (Shortcut) -> Void
    var onRecordingChange: (Bool) -> Void = { _ in }
    @State private var isRecording = false

    var body: some View {
        VStack(spacing: 12) {
            Text(shortcut.displayString)
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .accessibilityLabel("Current shortcut \(shortcut.displayString)")

            if isRecording {
                Text("Press your desired keyboard combination…")
                    .foregroundStyle(.secondary)
            }

            Button(isRecording ? "Cancel" : "Record Shortcut") {
                isRecording.toggle()
                onRecordingChange(isRecording)
            }
            .keyboardShortcut(.defaultAction)
        }
        .background(
            ShortcutCaptureRepresentable(isRecording: $isRecording) { captured in
                isRecording = false
                onRecordingChange(false)
                onRecorded(captured)
            }
        )
    }
}

private struct ShortcutCaptureRepresentable: NSViewRepresentable {
    @Binding var isRecording: Bool
    var onCapture: (Shortcut) -> Void

    func makeNSView(context: Context) -> ShortcutCaptureView {
        let view = ShortcutCaptureView()
        view.onCapture = onCapture
        return view
    }

    func updateNSView(_ nsView: ShortcutCaptureView, context: Context) {
        nsView.onCapture = onCapture
        nsView.isRecording = isRecording
    }
}

final class ShortcutCaptureView: NSView {
    var isRecording = false
    var onCapture: ((Shortcut) -> Void)?
    private var monitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            install()
        } else {
            remove()
        }
    }

    private func install() {
        remove()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else { return event }
            if event.keyCode == 53 {
                self.isRecording = false
                return nil
            }
            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let shortcut = Shortcut(keyCode: event.keyCode, modifierFlags: modifiers.rawValue)
            guard shortcut.hasModifier else { return nil }
            self.onCapture?(shortcut)
            return nil
        }
    }

    private func remove() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
