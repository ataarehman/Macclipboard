import AppKit
import ServiceManagement

@MainActor
@Observable
final class LaunchAtLoginService {
    private(set) var statusMessage: String?

    var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    func refresh() {
        switch SMAppService.mainApp.status {
        case .enabled:
            statusMessage = nil
        case .requiresApproval:
            statusMessage = "macOS needs approval in System Settings → General → Login Items."
        case .notFound:
            statusMessage = "Login item could not be found. Try a packaged .app rather than `swift run`."
        case .notRegistered:
            statusMessage = nil
        @unknown default:
            statusMessage = nil
        }
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            }
            statusMessage = nil
        } catch {
            statusMessage = error.localizedDescription
        }
        refresh()
    }
}

enum AppIconService {
    static func icon(forBundleIdentifier identifier: String?) -> NSImage? {
        guard let identifier, !identifier.isEmpty else { return nil }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        return nil
    }

    static func icon(forFile path: String) -> NSImage {
        NSWorkspace.shared.icon(forFile: path)
    }

    static func applicationName(forBundleIdentifier identifier: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: identifier) {
            return FileManager.default.displayName(atPath: url.path)
        }
        return identifier
    }
}
