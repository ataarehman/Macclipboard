import AppKit
import Carbon.HIToolbox
import SwiftUI

@MainActor
@Observable
final class AppState {
    let settings: SettingsStore
    let repository: ClipboardRepository
    let pause: PauseService
    let accessibility: AccessibilityPermissionManager
    let activeApp: ActiveApplicationService
    let launchAtLogin: LaunchAtLoginService
    let paste: PasteService
    let monitor: ClipboardMonitor
    let hotKey: GlobalHotKeyManager
    let panel: ClipboardPanelController
    let menuBar: MenuBarController
    let settingsWindow = SettingsWindowController()
    let onboarding = OnboardingWindowController()
    let session = PanelSession()
    var manualPasteHint = false

    init() {
        let settings = SettingsStore()
        let repository = ClipboardRepository(settings: settings)
        let pause = PauseService()
        let accessibility = AccessibilityPermissionManager()
        let activeApp = ActiveApplicationService()
        let launchAtLogin = LaunchAtLoginService()
        let paste = PasteService()
        let monitor = ClipboardMonitor(repository: repository, settings: settings, pause: pause)
        let hotKey = GlobalHotKeyManager(shortcut: settings.shortcut)
        let panel = ClipboardPanelController(settings: settings, activeApp: activeApp)
        let menuBar = MenuBarController(pause: pause, settings: settings)

        self.settings = settings
        self.repository = repository
        self.pause = pause
        self.accessibility = accessibility
        self.activeApp = activeApp
        self.launchAtLogin = launchAtLogin
        self.paste = paste
        self.monitor = monitor
        self.hotKey = hotKey
        self.panel = panel
        self.menuBar = menuBar

        paste.onNeedsManualPaste = { [weak self] in
            self?.manualPasteHint = true
            self?.notifyManualPaste()
        }
        hotKey.onPressed = { [weak self] in
            self?.panel.toggle()
        }
        panel.onWillShow = { [weak self] in
            self?.preparePanel()
        }
        panel.onKeyDown = { [weak self] event in
            self?.handlePanelKey(event) ?? false
        }
        panel.contentProvider = { [weak self] in
            guard let self else { return AnyView(EmptyView()) }
            return AnyView(self.makePanelView())
        }
        menuBar.onOpenClipboard = { [weak self] in self?.panel.show() }
        menuBar.onOpenSettings = { [weak self] in self?.openSettings() }
        menuBar.onClearHistory = { [weak self] in self?.repository.clearUnpinned() }
        menuBar.onAbout = { [weak self] in self?.showAbout() }
        menuBar.onQuit = { NSApp.terminate(nil) }
        menuBar.onPause = { [weak self] duration in
            self?.pause.pause(duration)
            self?.menuBar.reload()
        }
        menuBar.onResume = { [weak self] in
            self?.pause.resume()
            self?.menuBar.reload()
        }
    }

    func start() async {
        settings.applyAppearance()
        settings.applyDockPolicy()
        launchAtLogin.refresh()
        if settings.launchAtLogin && !launchAtLogin.isEnabled {
            launchAtLogin.setEnabled(true)
        }
        await repository.load()
        activeApp.start()
        accessibility.start()
        monitor.start()
        hotKey.start()
        menuBar.install()
        if !settings.hasCompletedOnboarding {
            onboarding.show(state: self)
        }
    }

    func stop() {
        monitor.stop()
        hotKey.stop()
        accessibility.stop()
        activeApp.stop()
    }

    func openSettings() {
        panel.hide()
        settingsWindow.show(state: self)
    }

    func pasteSelected() {
        let items = repository.filtered(query: session.query)
        guard let item = session.selected(in: items) else { return }
        Task { await pasteItem(item) }
    }

    func pasteItem(_ item: ClipboardItem) async {
        let target = activeApp.runningApplication()
        monitor.performingInternalWrite {
            repository.writeToPasteboard(item)
        }
        panel.hide()
        await paste.restoreTarget(target)
        _ = paste.pasteCommandV(hasAccessibility: accessibility.isTrusted)
    }

    func copyItem(_ item: ClipboardItem) {
        monitor.performingInternalWrite {
            repository.writeToPasteboard(item)
        }
    }

    func handlePanelKey(_ event: NSEvent) -> Bool {
        let items = repository.filtered(query: session.query)
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        switch Int(event.keyCode) {
        case kVK_Escape:
            panel.hide()
            return true
        case kVK_UpArrow:
            session.moveSelection(in: items, delta: -1)
            panel.reloadContent()
            return true
        case kVK_DownArrow:
            session.moveSelection(in: items, delta: 1)
            panel.reloadContent()
            return true
        case kVK_Return, kVK_ANSI_KeypadEnter:
            if let item = session.selected(in: items) {
                Task { await pasteItem(item) }
            }
            return true
        case kVK_Delete, kVK_ForwardDelete:
            if let item = session.selected(in: items) {
                if item.isPinned {
                    session.toast = "Unpin this item before deleting it."
                    panel.reloadContent()
                } else {
                    repository.delete(id: item.id)
                    session.selectedID = repository.filtered(query: session.query).first?.id
                    panel.reloadContent()
                }
            }
            return true
        case kVK_ANSI_F where modifiers == .command:
            if settings.shortcut.matches(keyCode: UInt16(kVK_ANSI_F), flags: .command) {
                return false
            }
            session.searchFocused = true
            panel.reloadContent()
            return true
        case kVK_ANSI_P where modifiers == .command:
            if let item = session.selected(in: items) {
                repository.togglePin(id: item.id)
                panel.reloadContent()
            }
            return true
        default:
            return false
        }
    }

    private func preparePanel() {
        session.reset(items: repository.items)
        panel.reloadContent()
    }

    private func makePanelView() -> some View {
        ClipboardPanelView(
            items: repository.items,
            shortcut: settings.shortcut,
            accessibilityGranted: accessibility.isTrusted,
            pasteImmediatelyOnClick: settings.pasteImmediatelyOnClick,
            paths: repository.paths,
            session: session,
            onPaste: { item in
                Task { await self.pasteItem(item) }
            },
            onCopy: { item in
                self.copyItem(item)
            },
            onPin: { item in
                self.repository.togglePin(id: item.id)
                self.panel.reloadContent()
            },
            onDelete: { item in
                self.repository.delete(id: item.id)
                self.session.selectedID = self.repository.filtered(query: self.session.query).first?.id
                self.panel.reloadContent()
            },
            onClearUnpinned: {
                self.repository.clearUnpinned()
                self.panel.reloadContent()
            },
            onOpenSettings: {
                self.openSettings()
            },
            onClose: {
                self.panel.hide()
            }
        )
    }

    private func showAbout() {
        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: AppIdentity.displayName,
            .applicationVersion: AppIdentity.version,
            .credits: NSAttributedString(string: AppIdentity.privacyStatement)
        ])
        NSApp.activate(ignoringOtherApps: true)
    }

    private func notifyManualPaste() {
        NSSound.beep()
    }
}
