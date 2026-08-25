import AppKit
import Carbon.HIToolbox
import CoreGraphics

struct Shortcut: Codable, Equatable, Hashable, Sendable {
    var keyCode: UInt16
    var modifierFlags: UInt

    static let `default` = Shortcut(
        keyCode: UInt16(kVK_ANSI_V),
        modifierFlags: NSEvent.ModifierFlags([.control, .option]).rawValue
    )

    var nsModifiers: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifierFlags).intersection(.deviceIndependentFlagsMask)
    }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        let flags = nsModifiers
        if flags.contains(.command) { value |= UInt32(cmdKey) }
        if flags.contains(.shift) { value |= UInt32(shiftKey) }
        if flags.contains(.option) { value |= UInt32(optionKey) }
        if flags.contains(.control) { value |= UInt32(controlKey) }
        return value
    }

    var cgFlags: CGEventFlags {
        var flags: CGEventFlags = []
        let ns = nsModifiers
        if ns.contains(.command) { flags.insert(.maskCommand) }
        if ns.contains(.shift) { flags.insert(.maskShift) }
        if ns.contains(.option) { flags.insert(.maskAlternate) }
        if ns.contains(.control) { flags.insert(.maskControl) }
        return flags
    }

    var hasModifier: Bool {
        nsModifiers.contains(.command)
            || nsModifiers.contains(.option)
            || nsModifiers.contains(.control)
            || nsModifiers.contains(.shift)
    }

    var displayString: String {
        nsModifiers.symbolic + keyDisplay
    }

    var keyDisplay: String {
        Self.keyNames[Int(keyCode)] ?? "Key \(keyCode)"
    }

    func matches(keyCode: UInt16, flags: NSEvent.ModifierFlags) -> Bool {
        self.keyCode == keyCode && nsModifiers == flags.intersection(.deviceIndependentFlagsMask)
    }

    func matches(event: CGEvent) -> Bool {
        let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let flags = NSEvent.ModifierFlags(rawValue: UInt(event.flags.rawValue)).intersection(.deviceIndependentFlagsMask)
        return matches(keyCode: code, flags: flags)
    }

    static let keyNames: [Int: String] = {
        let map: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
            kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
            kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
            kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
            kVK_ANSI_8: "8", kVK_ANSI_9: "9",
            kVK_Space: "Space",
            kVK_Return: "Return",
            kVK_Tab: "Tab",
            kVK_Delete: "Delete",
            kVK_Escape: "Esc",
            kVK_ForwardDelete: "Fwd Delete",
            kVK_LeftArrow: "←",
            kVK_RightArrow: "→",
            kVK_DownArrow: "↓",
            kVK_UpArrow: "↑",
            kVK_ANSI_Minus: "-",
            kVK_ANSI_Equal: "=",
            kVK_ANSI_LeftBracket: "[",
            kVK_ANSI_RightBracket: "]",
            kVK_ANSI_Backslash: "\\",
            kVK_ANSI_Semicolon: ";",
            kVK_ANSI_Quote: "'",
            kVK_ANSI_Comma: ",",
            kVK_ANSI_Period: ".",
            kVK_ANSI_Slash: "/",
            kVK_ANSI_Grave: "`",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
            kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
            kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12"
        ]
        return map
    }()
}

extension NSEvent.ModifierFlags {
    var symbolic: String {
        var result = ""
        if contains(.control) { result += "⌃" }
        if contains(.option) { result += "⌥" }
        if contains(.shift) { result += "⇧" }
        if contains(.command) { result += "⌘" }
        return result
    }
}

struct ShortcutConflict: Equatable, Sendable {
    var title: String
    var message: String
}

enum ShortcutConflictDetector {
    static func conflict(for shortcut: Shortcut) -> ShortcutConflict? {
        let flags = shortcut.nsModifiers
        let key = shortcut.keyCode
        let commandOnly = flags == .command

        if commandOnly && key == UInt16(kVK_ANSI_C) {
            return ShortcutConflict(title: "Command + C is Copy", message: "Command + C is commonly used for Copy. Using this shortcut globally may override Copy while \(AppIdentity.displayName) is running.")
        }
        if commandOnly && key == UInt16(kVK_ANSI_V) {
            return ShortcutConflict(title: "Command + V is Paste", message: "Command + V is commonly used for Paste. Using this shortcut globally may override Paste while \(AppIdentity.displayName) is running.")
        }
        if commandOnly && key == UInt16(kVK_ANSI_A) {
            return ShortcutConflict(title: "Command + A is Select All", message: "Command + A is commonly used for Select All. Using this shortcut globally may override Select All while \(AppIdentity.displayName) is running.")
        }
        if commandOnly && key == UInt16(kVK_ANSI_Z) {
            return ShortcutConflict(title: "Command + Z is Undo", message: "Command + Z is commonly used for Undo. Using this shortcut globally may override Undo while \(AppIdentity.displayName) is running.")
        }
        if commandOnly && key == UInt16(kVK_ANSI_F) {
            return ShortcutConflict(title: "Command + F is Find", message: "Command + F is commonly used for Find. Using this shortcut globally may override Find while \(AppIdentity.displayName) is running.")
        }
        if commandOnly && key == UInt16(kVK_ANSI_X) {
            return ShortcutConflict(title: "Command + X is Cut", message: "Command + X is commonly used for Cut. Using this shortcut globally may override Cut while \(AppIdentity.displayName) is running.")
        }
        if commandOnly && key == UInt16(kVK_ANSI_S) {
            return ShortcutConflict(title: "Command + S is Save", message: "Command + S is commonly used for Save. Using this shortcut globally may override Save while \(AppIdentity.displayName) is running.")
        }
        if commandOnly && key == UInt16(kVK_ANSI_Q) {
            return ShortcutConflict(title: "Command + Q is Quit", message: "Command + Q is commonly used to quit the frontmost application. Using this shortcut globally may override Quit while \(AppIdentity.displayName) is running.")
        }
        if commandOnly && key == UInt16(kVK_ANSI_W) {
            return ShortcutConflict(title: "Command + W is Close", message: "Command + W is commonly used to close a window. Using this shortcut globally may override Close while \(AppIdentity.displayName) is running.")
        }
        return nil
    }
}
