import AppKit
import Darwin
import SwiftUI

@main
enum MacClipboardMain {
    static func main() {
        if CommandLine.arguments.contains("--run-tests") {
            let failed = MainActor.assumeIsolated { LogicTests.run() }
            Darwin.exit(Int32(failed == 0 ? EXIT_SUCCESS : EXIT_FAILURE))
        }
        MacClipboardApp.main()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(state.settings.showDockIcon ? .regular : .accessory)
        Task { @MainActor in
            await state.start()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.stop()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            state.panel.show()
        }
        return false
    }
}

struct MacClipboardApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environment(appDelegate.state)
        }
    }
}
