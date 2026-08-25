import AppKit
import Foundation

@MainActor
@Observable
final class ClipboardRepository {
    private(set) var items: [ClipboardItem] = []
    private(set) var storageBytes: Int64 = 0
    private(set) var isLoaded = false

    let paths: StoragePaths
    private let settings: SettingsStore
    private let persistence: HistoryPersistence
    private var saveTask: Task<Void, Never>?

    init(settings: SettingsStore, paths: StoragePaths = StoragePaths()) {
        self.settings = settings
        self.paths = paths
        self.persistence = HistoryPersistence(paths: paths)
    }

    func load() async {
        let loaded = await persistence.load()
        items = ClipboardHistoryEngine.sort(loaded)
        isLoaded = true
        await refreshStorageSize()
    }

    func ingest(_ parsed: ParsedClipboard, source: SourceApplication?) {
        do {
            var item = try ImageStorage.save(parsed: parsed, id: UUID(), paths: paths)
            item.sourceApplicationName = source?.name
            item.sourceBundleIdentifier = source?.bundleIdentifier
            let previousIDs = Set(items.map(\.id))
            items = ClipboardHistoryEngine.upsert(
                items: items,
                newItem: item,
                maxUnpinned: settings.maxHistoryItems
            )
            let kept = Set(items.map(\.id))
            if !kept.contains(item.id), let existing = items.first(where: { $0.contentHash == item.contentHash }) {
                ImageStorage.deleteMedia(id: item.id, paths: paths)
                _ = existing
            }
            for dropped in previousIDs.subtracting(kept) {
                ImageStorage.deleteMedia(id: dropped, paths: paths)
            }
            scheduleSave()
        } catch {
            // Ignore unreadable clipboard payloads rather than crashing.
        }
    }

    func togglePin(id: UUID) {
        guard let current = items.first(where: { $0.id == id }) else { return }
        items = ClipboardHistoryEngine.setPinned(items, id: id, isPinned: !current.isPinned)
        items = ClipboardHistoryEngine.trim(items, maxUnpinned: settings.maxHistoryItems)
        scheduleSave()
    }

    func delete(id: UUID) {
        ImageStorage.deleteMedia(id: id, paths: paths)
        items = ClipboardHistoryEngine.delete(items, id: id)
        scheduleSave()
    }

    func clearUnpinned() {
        let removed = items.filter { !$0.isPinned }
        for item in removed {
            ImageStorage.deleteMedia(id: item.id, paths: paths)
        }
        items = ClipboardHistoryEngine.clearUnpinned(items)
        scheduleSave()
    }

    func clearAll() {
        for item in items {
            ImageStorage.deleteMedia(id: item.id, paths: paths)
        }
        items = []
        scheduleSave()
    }

    func clearOlderThan(_ date: Date) {
        let removed = items.filter { !$0.isPinned && $0.updatedAt < date }
        for item in removed {
            ImageStorage.deleteMedia(id: item.id, paths: paths)
        }
        items = ClipboardHistoryEngine.clearOlderThan(items, date: date)
        scheduleSave()
    }

    func applyLimit() {
        let previous = Set(items.map(\.id))
        items = ClipboardHistoryEngine.trim(items, maxUnpinned: settings.maxHistoryItems)
        for dropped in previous.subtracting(Set(items.map(\.id))) {
            ImageStorage.deleteMedia(id: dropped, paths: paths)
        }
        scheduleSave()
    }

    func item(id: UUID) -> ClipboardItem? {
        items.first { $0.id == id }
    }

    func filtered(query: String) -> [ClipboardItem] {
        ClipboardSearch.filter(items, query: query)
    }

    func writeToPasteboard(_ item: ClipboardItem, pasteboard: NSPasteboard = .general) {
        pasteboard.clearContents()
        var objects: [NSPasteboardWriting] = []

        if item.kind == .file {
            let urls = item.filePaths.map { URL(fileURLWithPath: $0) }.filter { FileManager.default.fileExists(atPath: $0.path) }
            if !urls.isEmpty {
                objects.append(contentsOf: urls.map { $0 as NSURL })
            }
        }

        if let image = ImageStorage.loadImage(relativePath: item.imageRelativePath, paths: paths) {
            objects.append(image)
        }

        if objects.isEmpty {
            pasteboard.declareTypes([.string, NSPasteboard.PasteboardType(AppIdentity.internalPasteboardType)], owner: nil)
        } else {
            pasteboard.writeObjects(objects)
        }

        if let rtf = ImageStorage.loadData(relativePath: item.rtfRelativePath, paths: paths) {
            pasteboard.setData(rtf, forType: .rtf)
        }
        if let html = ImageStorage.loadData(relativePath: item.htmlRelativePath, paths: paths) {
            pasteboard.setData(html, forType: .html)
        }
        let text = item.plainText ?? item.urlString ?? item.previewText
        if !text.isEmpty {
            pasteboard.setString(text, forType: .string)
        }
        if let urlString = item.urlString {
            pasteboard.setString(urlString, forType: .URL)
        }
        pasteboard.setData(Data(), forType: NSPasteboard.PasteboardType(AppIdentity.internalPasteboardType))
    }

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = items
        saveTask = Task { [persistence] in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            try? await persistence.save(snapshot)
            await refreshStorageSize()
        }
    }

    private func refreshStorageSize() async {
        storageBytes = await persistence.directorySize()
    }
}
