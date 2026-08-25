import AppKit
import Foundation

struct RememberedApplication: Equatable {
    var bundleIdentifier: String?
    var processIdentifier: pid_t
    var name: String?
}

@MainActor
@Observable
final class ActiveApplicationService {
    private(set) var lastExternalApp: RememberedApplication?
    private var observer: NSObjectProtocol?

    func start() {
        stop()
        captureIfExternal(NSWorkspace.shared.frontmostApplication)
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            Task { @MainActor in
                self?.captureIfExternal(app)
            }
        }
    }

    func stop() {
        if let observer {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            self.observer = nil
        }
    }

    func runningApplication() -> NSRunningApplication? {
        guard let remembered = lastExternalApp else { return nil }
        if let bundle = remembered.bundleIdentifier,
           let match = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first(where: { $0.processIdentifier == remembered.processIdentifier }) {
            return match
        }
        return NSRunningApplication(processIdentifier: remembered.processIdentifier)
    }

    private func captureIfExternal(_ app: NSRunningApplication?) {
        guard let app else { return }
        if app.bundleIdentifier == AppIdentity.bundleIdentifier { return }
        if app.isTerminated { return }
        lastExternalApp = RememberedApplication(
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            name: app.localizedName
        )
    }
}
