import AppKit
import SwiftUI

@MainActor
final class ClipboardPanelController: NSObject, NSWindowDelegate {
    private var panel: NSPanel?
    private var hosting: NSHostingView<AnyView>?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private let settings: SettingsStore
    private let activeApp: ActiveApplicationService
    var isVisible: Bool { panel?.isVisible == true }

    var contentProvider: (() -> AnyView)?
    var onWillShow: (() -> Void)?
    var onDidHide: (() -> Void)?
    var onKeyDown: ((NSEvent) -> Bool)?

    init(settings: SettingsStore, activeApp: ActiveApplicationService) {
        self.settings = settings
        self.activeApp = activeApp
    }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        onWillShow?()
        let panel = makePanelIfNeeded()
        if let contentProvider {
            hosting?.rootView = contentProvider()
        }
        position(panel)
        panel.makeKeyAndOrderFront(nil)
        installMonitors()
    }

    func hide() {
        removeMonitors()
        panel?.orderOut(nil)
        onDidHide?()
    }

    func reloadContent() {
        guard isVisible, let contentProvider else { return }
        hosting?.rootView = contentProvider()
    }

    func windowDidResignKey(_ notification: Notification) {
        hide()
    }

    private func makePanelIfNeeded() -> NSPanel {
        if let panel { return panel }
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 500),
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.delegate = self
        panel.animationBehavior = .utilityWindow

        let hosting = NSHostingView(rootView: AnyView(EmptyView()))
        hosting.wantsLayer = true
        hosting.layer?.cornerRadius = 14
        hosting.layer?.masksToBounds = true
        panel.contentView = hosting
        self.hosting = hosting
        self.panel = panel
        return panel
    }

    private func position(_ panel: NSPanel) {
        let size = NSSize(width: 430, height: 500)
        panel.setContentSize(size)
        let screen = preferredScreen()
        let visible = screen.visibleFrame
        var origin = NSPoint(
            x: visible.midX - size.width / 2,
            y: visible.midY - size.height / 2
        )
        origin.x = min(max(origin.x, visible.minX + 12), visible.maxX - size.width - 12)
        origin.y = min(max(origin.y, visible.minY + 12), visible.maxY - size.height - 12)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    private func preferredScreen() -> NSScreen {
        switch settings.panelPlacement {
        case .mouse:
            return screen(containing: NSEvent.mouseLocation) ?? NSScreen.main ?? NSScreen.screens[0]
        case .activeWindow:
            if let app = activeApp.runningApplication() {
                let pid = app.processIdentifier
                let info = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]]
                if let match = info?.first(where: { ($0[kCGWindowOwnerPID as String] as? pid_t) == pid }),
                   let bounds = match[kCGWindowBounds as String] as? [String: CGFloat] {
                    let rect = CGRect(x: bounds["X"] ?? 0, y: bounds["Y"] ?? 0, width: bounds["Width"] ?? 0, height: bounds["Height"] ?? 0)
                    let point = CGPoint(x: rect.midX, y: NSMaxY(NSScreen.screens.first?.frame ?? .zero) - rect.midY)
                    if let screen = screen(containing: point) {
                        return screen
                    }
                }
            }
            return screen(containing: NSEvent.mouseLocation) ?? NSScreen.main ?? NSScreen.screens[0]
        }
    }

    private func screen(containing point: NSPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    private func installMonitors() {
        removeMonitors()
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in
                self?.hideIfClickOutside()
            }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown]) { [weak self] event in
            guard let self else { return event }
            if event.type == .keyDown, self.onKeyDown?(event) == true {
                return nil
            }
            if event.type == .leftMouseDown || event.type == .rightMouseDown {
                self.hideIfClickOutside()
            }
            return event
        }
    }

    private func hideIfClickOutside() {
        guard let panel, panel.isVisible else { return }
        if !panel.frame.contains(NSEvent.mouseLocation) {
            hide()
        }
    }

    private func removeMonitors() {
        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
}
