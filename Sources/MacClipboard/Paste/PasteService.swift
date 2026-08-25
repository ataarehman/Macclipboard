import AppKit
import Carbon.HIToolbox
import CoreGraphics
import Foundation

@MainActor
final class PasteService {
    var onNeedsManualPaste: (() -> Void)?

    func restoreTarget(_ app: NSRunningApplication?) async {
        guard let app, !app.isTerminated else { return }
        if app.isActive { return }

        let pid = app.processIdentifier
        app.activate()

        let started = Date()
        while Date().timeIntervalSince(started) < 0.35 {
            if NSWorkspace.shared.frontmostApplication?.processIdentifier == pid {
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    func pasteCommandV(hasAccessibility: Bool) -> Bool {
        guard hasAccessibility else {
            onNeedsManualPaste?()
            return false
        }
        return Self.postCommandV()
    }

    static func postCommandV() -> Bool {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }
        let command: CGKeyCode = CGKeyCode(kVK_Command)
        let vKey: CGKeyCode = CGKeyCode(kVK_ANSI_V)

        guard
            let commandDown = CGEvent(keyboardEventSource: source, virtualKey: command, keyDown: true),
            let vDown = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true),
            let vUp = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false),
            let commandUp = CGEvent(keyboardEventSource: source, virtualKey: command, keyDown: false)
        else {
            return false
        }

        commandDown.flags = .maskCommand
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand
        commandUp.flags = []

        commandDown.post(tap: .cghidEventTap)
        vDown.post(tap: .cghidEventTap)
        vUp.post(tap: .cghidEventTap)
        commandUp.post(tap: .cghidEventTap)
        return true
    }
}
