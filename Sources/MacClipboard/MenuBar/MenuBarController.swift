import AppKit

@MainActor
final class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private let pause: PauseService
    private let settings: SettingsStore
    var onOpenClipboard: (() -> Void)?
    var onOpenSettings: (() -> Void)?
    var onClearHistory: (() -> Void)?
    var onAbout: (() -> Void)?
    var onQuit: (() -> Void)?
    var onPause: ((PauseDuration) -> Void)?
    var onResume: (() -> Void)?

    init(pause: PauseService, settings: SettingsStore) {
        self.pause = pause
        self.settings = settings
    }

    func install() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: AppIdentity.displayName)
            button.toolTip = AppIdentity.displayName
        }
        item.menu = buildMenu()
        statusItem = item
    }

    func reload() {
        statusItem?.button?.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: AppIdentity.displayName)
        statusItem?.menu = buildMenu()
    }

    private var symbolName: String {
        pause.isPaused ? "clipboard.fill" : "clipboard"
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        let open = NSMenuItem(
            title: "Open Clipboard",
            action: #selector(openClipboard),
            keyEquivalent: settings.shortcut.keyDisplay.lowercased()
        )
        open.target = self
        open.keyEquivalentModifierMask = settings.shortcut.nsModifiers
        menu.addItem(open)
        menu.addItem(.separator())

        let pauseMenu = NSMenuItem(title: "Pause Clipboard Monitoring", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        submenu.addItem(menuItem("Pause for 5 minutes", #selector(pauseFive)))
        submenu.addItem(menuItem("Pause for 15 minutes", #selector(pauseFifteen)))
        submenu.addItem(menuItem("Pause for 1 hour", #selector(pauseHour)))
        submenu.addItem(menuItem("Pause until resumed", #selector(pauseForever)))
        if pause.isPaused {
            submenu.addItem(.separator())
            submenu.addItem(menuItem("Resume", #selector(resume)))
        }
        pauseMenu.submenu = submenu
        menu.addItem(pauseMenu)

        menu.addItem(menuItem("Clear History", #selector(clearHistory)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Settings…", #selector(openSettings)))
        menu.addItem(menuItem("About \(AppIdentity.displayName)", #selector(about)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Quit \(AppIdentity.displayName)", #selector(quit)))
        return menu
    }

    private func menuItem(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }

    @objc private func openClipboard() { onOpenClipboard?() }
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func clearHistory() { onClearHistory?() }
    @objc private func about() { onAbout?() }
    @objc private func quit() { onQuit?() }
    @objc private func pauseFive() { onPause?(.minutes(5)) }
    @objc private func pauseFifteen() { onPause?(.minutes(15)) }
    @objc private func pauseHour() { onPause?(.minutes(60)) }
    @objc private func pauseForever() { onPause?(.indefinitely) }
    @objc private func resume() { onResume?() }
}
