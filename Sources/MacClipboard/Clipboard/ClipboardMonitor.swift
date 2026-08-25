import AppKit
import Foundation

@MainActor
@Observable
final class ClipboardMonitor {
    private let repository: ClipboardRepository
    private let settings: SettingsStore
    private let pause: PauseService
    private var timer: Timer?
    private var lastChangeCount: Int = NSPasteboard.general.changeCount
    private var ignoredChangeCounts: Set<Int> = []
    private let interval: TimeInterval = 0.4

    init(repository: ClipboardRepository, settings: SettingsStore, pause: PauseService) {
        self.repository = repository
        self.settings = settings
        self.pause = pause
    }

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
        timer.tolerance = 0.15
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func ignoreCurrentPasteboard() {
        ignoredChangeCounts.insert(NSPasteboard.general.changeCount)
    }

    func performingInternalWrite(_ work: () -> Void) {
        work()
        ignoreCurrentPasteboard()
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        if ignoredChangeCounts.contains(count) {
            ignoredChangeCounts.remove(count)
            return
        }

        if pause.isPaused { return }

        let snapshot = Self.snapshot(from: pasteboard)
        if PasteboardPrivacyMarker.isInternalWrite(snapshot.typeIdentifiers) {
            return
        }
        guard let parsed = ClipboardContentParser.parse(snapshot) else { return }

        let front = NSWorkspace.shared.frontmostApplication
        if settings.isExcluded(bundleIdentifier: front?.bundleIdentifier) {
            return
        }

        let source = front.map {
            SourceApplication(
                name: $0.localizedName ?? $0.bundleIdentifier ?? "Unknown",
                bundleIdentifier: $0.bundleIdentifier ?? ""
            )
        }
        repository.ingest(parsed, source: source)
    }

    static func snapshot(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let types = pasteboard.types ?? []
        let identifiers = types.map(\.rawValue)

        var fileURLs: [URL] = []
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL] {
            fileURLs = urls
        }

        let imageTIFF = pasteboard.data(forType: .tiff)
            ?? pasteboard.data(forType: .png)
            ?? NSImage(pasteboard: pasteboard)?.tiffRepresentation

        return PasteboardSnapshot(
            typeIdentifiers: identifiers,
            string: pasteboard.string(forType: .string),
            urlString: pasteboard.string(forType: .URL),
            html: pasteboard.data(forType: .html),
            rtf: pasteboard.data(forType: .rtf),
            imageTIFF: imageTIFF,
            fileURLs: fileURLs
        )
    }
}
