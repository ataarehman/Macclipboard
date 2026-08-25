import AppKit
import Foundation

enum AppearanceMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }
}

enum PanelPlacement: String, Codable, CaseIterable, Identifiable, Sendable {
    case activeWindow
    case mouse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .activeWindow: "Active window display"
        case .mouse: "Mouse pointer display"
        }
    }
}

enum HistoryLimit: Int, CaseIterable, Identifiable, Sendable {
    case twentyFive = 25
    case fifty = 50
    case hundred = 100
    case twoFifty = 250
    case fiveHundred = 500

    var id: Int { rawValue }
    var title: String { "\(rawValue)" }
}

@MainActor
@Observable
final class SettingsStore {
    private let defaults: UserDefaults

    var maxHistoryItems: Int {
        didSet { defaults.set(maxHistoryItems, forKey: Keys.maxHistoryItems) }
    }

    var appearance: AppearanceMode {
        didSet {
            defaults.set(appearance.rawValue, forKey: Keys.appearance)
            applyAppearance()
        }
    }

    var showDockIcon: Bool {
        didSet {
            defaults.set(showDockIcon, forKey: Keys.showDockIcon)
            applyDockPolicy()
        }
    }

    var pasteImmediatelyOnClick: Bool {
        didSet { defaults.set(pasteImmediatelyOnClick, forKey: Keys.pasteImmediatelyOnClick) }
    }

    var panelPlacement: PanelPlacement {
        didSet { defaults.set(panelPlacement.rawValue, forKey: Keys.panelPlacement) }
    }

    var shortcut: Shortcut {
        didSet { persistShortcut() }
    }

    var excludedBundleIdentifiers: [String] {
        didSet { defaults.set(excludedBundleIdentifiers, forKey: Keys.excludedBundleIdentifiers) }
    }

    var hasCompletedOnboarding: Bool {
        didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.hasCompletedOnboarding) }
    }

    var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let storedLimit = defaults.object(forKey: Keys.maxHistoryItems) as? Int
        self.maxHistoryItems = HistoryLimit(rawValue: storedLimit ?? 100)?.rawValue ?? 100
        self.appearance = AppearanceMode(rawValue: defaults.string(forKey: Keys.appearance) ?? "") ?? .system
        self.showDockIcon = defaults.bool(forKey: Keys.showDockIcon)
        self.pasteImmediatelyOnClick = defaults.object(forKey: Keys.pasteImmediatelyOnClick) as? Bool ?? true
        self.panelPlacement = PanelPlacement(rawValue: defaults.string(forKey: Keys.panelPlacement) ?? "") ?? .mouse
        self.excludedBundleIdentifiers = defaults.stringArray(forKey: Keys.excludedBundleIdentifiers) ?? []
        self.hasCompletedOnboarding = defaults.bool(forKey: Keys.hasCompletedOnboarding)
        self.launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        self.shortcut = Self.loadShortcut(from: defaults)
    }

    func applyAppearance() {
        switch appearance {
        case .system:
            NSApp.appearance = nil
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        }
    }

    func applyDockPolicy() {
        NSApp.setActivationPolicy(showDockIcon ? .regular : .accessory)
    }

    func resetShortcut() {
        shortcut = .default
    }

    func isExcluded(bundleIdentifier: String?) -> Bool {
        guard let bundleIdentifier else { return false }
        return excludedBundleIdentifiers.contains(bundleIdentifier)
    }

    func addExcludedApp(bundleIdentifier: String) {
        guard !bundleIdentifier.isEmpty else { return }
        if !excludedBundleIdentifiers.contains(bundleIdentifier) {
            excludedBundleIdentifiers.append(bundleIdentifier)
        }
    }

    func removeExcludedApp(bundleIdentifier: String) {
        excludedBundleIdentifiers.removeAll { $0 == bundleIdentifier }
    }

    private func persistShortcut() {
        if let data = try? JSONEncoder().encode(shortcut) {
            defaults.set(data, forKey: Keys.shortcut)
        }
    }

    private static func loadShortcut(from defaults: UserDefaults) -> Shortcut {
        guard let data = defaults.data(forKey: Keys.shortcut),
              let shortcut = try? JSONDecoder().decode(Shortcut.self, from: data) else {
            return .default
        }
        return shortcut
    }

    private enum Keys {
        static let maxHistoryItems = "MacClipboard.maxHistoryItems"
        static let appearance = "MacClipboard.appearance"
        static let showDockIcon = "MacClipboard.showDockIcon"
        static let pasteImmediatelyOnClick = "MacClipboard.pasteImmediatelyOnClick"
        static let panelPlacement = "MacClipboard.panelPlacement"
        static let shortcut = "MacClipboard.shortcut"
        static let excludedBundleIdentifiers = "MacClipboard.excludedBundleIdentifiers"
        static let hasCompletedOnboarding = "MacClipboard.hasCompletedOnboarding"
        static let launchAtLogin = "MacClipboard.launchAtLogin"
    }
}
