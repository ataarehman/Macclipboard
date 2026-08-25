import AppKit
import Carbon
import CoreGraphics
import Foundation

final class EventTapRuntime: @unchecked Sendable {
    var tap: CFMachPort?
    var source: CFRunLoopSource?
    var shortcut: Shortcut
    var isEnabled = true
    var onHotKey: (@Sendable () -> Void)?

    init(shortcut: Shortcut) {
        self.shortcut = shortcut
    }

    func start() -> Bool {
        stop()
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let pointer = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: { _, type, event, refcon in
                guard let refcon else {
                    return Unmanaged.passUnretained(event)
                }
                let runtime = Unmanaged<EventTapRuntime>.fromOpaque(refcon).takeUnretainedValue()
                return runtime.handle(type: type, event: event)
            },
            userInfo: pointer
        ) else {
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        tap = nil
        source = nil
    }

    func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }
        guard isEnabled, type == .keyDown, shortcut.matches(event: event) else {
            return Unmanaged.passUnretained(event)
        }
        onHotKey?()
        return nil
    }
}

@MainActor
@Observable
final class GlobalHotKeyManager {
    private(set) var isUsingEventTap = false
    private(set) var lastError: String?
    var onPressed: (() -> Void)?

    private var runtime: EventTapRuntime
    private var carbonHotKey: EventHotKeyRef?
    private var carbonHandler: EventHandlerRef?
    private var currentShortcut: Shortcut

    init(shortcut: Shortcut) {
        self.currentShortcut = shortcut
        self.runtime = EventTapRuntime(shortcut: shortcut)
        runtime.onHotKey = { [weak self] in
            DispatchQueue.main.async {
                self?.handlePress()
            }
        }
    }

    func start() {
        register(currentShortcut)
    }

    func stop() {
        runtime.stop()
        unregisterCarbon()
        isUsingEventTap = false
    }

    func setShortcut(_ shortcut: Shortcut) {
        currentShortcut = shortcut
        runtime.shortcut = shortcut
        register(shortcut)
    }

    func setEnabled(_ enabled: Bool) {
        runtime.isEnabled = enabled
    }

    private func handlePress() {
        onPressed?()
    }

    private func register(_ shortcut: Shortcut) {
        stop()
        currentShortcut = shortcut
        runtime.shortcut = shortcut
        runtime.onHotKey = { [weak self] in
            DispatchQueue.main.async {
                self?.handlePress()
            }
        }

        if runtime.start() {
            isUsingEventTap = true
            lastError = nil
            return
        }

        isUsingEventTap = false
        if registerCarbon(shortcut) {
            lastError = nil
        } else {
            lastError = "Could not register the global shortcut. Try a different key combination."
        }
    }

    private func registerCarbon(_ shortcut: Shortcut) -> Bool {
        unregisterCarbon()
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: OSType(0x4D434C50), id: 1)
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr, let hotKeyRef else { return false }
        carbonHotKey = hotKeyRef

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.handlePress()
                }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &carbonHandler
        )
        return handlerStatus == noErr
    }

    private func unregisterCarbon() {
        if let carbonHotKey {
            UnregisterEventHotKey(carbonHotKey)
            self.carbonHotKey = nil
        }
        if let carbonHandler {
            RemoveEventHandler(carbonHandler)
            self.carbonHandler = nil
        }
    }
}
