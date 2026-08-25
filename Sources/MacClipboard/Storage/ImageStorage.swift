import AppKit
import Foundation

struct StoragePaths: Sendable {
    let root: URL
    let historyURL: URL
    let mediaRoot: URL

    init(root: URL? = nil) {
        let base: URL
        if let root {
            base = root
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? URL(fileURLWithPath: NSTemporaryDirectory())
            base = appSupport.appendingPathComponent(AppIdentity.supportDirectoryName, isDirectory: true)
        }
        self.root = base
        self.historyURL = base.appendingPathComponent("history.json")
        self.mediaRoot = base.appendingPathComponent("media", isDirectory: true)
    }

    func mediaDirectory(for id: UUID) -> URL {
        mediaRoot.appendingPathComponent(id.uuidString, isDirectory: true)
    }
}

struct HistoryFile: Codable, Sendable {
    var items: [ClipboardItem]
}

actor HistoryPersistence {
    private let paths: StoragePaths
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(paths: StoragePaths) {
        self.paths = paths
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func prepare() throws {
        try FileManager.default.createDirectory(at: paths.root, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: paths.mediaRoot, withIntermediateDirectories: true)
    }

    func load() -> [ClipboardItem] {
        do {
            try prepare()
            guard FileManager.default.fileExists(atPath: paths.historyURL.path) else { return [] }
            let data = try Data(contentsOf: paths.historyURL)
            return try decoder.decode(HistoryFile.self, from: data).items
        } catch {
            return []
        }
    }

    func save(_ items: [ClipboardItem]) throws {
        try prepare()
        let data = try encoder.encode(HistoryFile(items: items))
        let temp = paths.historyURL.appendingPathExtension("tmp")
        try data.write(to: temp, options: .atomic)
        if FileManager.default.fileExists(atPath: paths.historyURL.path) {
            _ = try FileManager.default.replaceItemAt(paths.historyURL, withItemAt: temp)
        } else {
            try FileManager.default.moveItem(at: temp, to: paths.historyURL)
        }
    }

    func directorySize() -> Int64 {
        directorySize(at: paths.root)
    }

    private func directorySize(at url: URL) -> Int64 {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else {
            return 0
        }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]), let size = values.fileSize {
                total += Int64(size)
            }
        }
        return total
    }
}

enum ImageStorage {
    static func save(parsed: ParsedClipboard, id: UUID, paths: StoragePaths) throws -> ClipboardItem {
        let folder = paths.mediaDirectory(for: id)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)

        var item = ClipboardItem(
            id: id,
            kind: parsed.kind,
            plainText: parsed.plainText,
            urlString: parsed.urlString,
            previewText: ClipboardContentParser.previewLines(parsed.previewText),
            filePaths: parsed.filePaths,
            fileNames: parsed.fileNames,
            rtfRelativePath: nil,
            htmlRelativePath: nil,
            imageRelativePath: nil,
            thumbnailRelativePath: nil,
            createdAt: .now,
            updatedAt: .now,
            isPinned: false,
            sourceApplicationName: nil,
            sourceBundleIdentifier: nil,
            contentHash: parsed.contentHash
        )

        if let rtf = parsed.rtfData, !rtf.isEmpty {
            let url = folder.appendingPathComponent("content.rtf")
            try rtf.write(to: url, options: .atomic)
            item.rtfRelativePath = relative(url, paths: paths)
        }
        if let html = parsed.htmlData, !html.isEmpty {
            let url = folder.appendingPathComponent("content.html")
            try html.write(to: url, options: .atomic)
            item.htmlRelativePath = relative(url, paths: paths)
        }
        if let image = parsed.imageData, !image.isEmpty {
            let original = folder.appendingPathComponent("original.tiff")
            try image.write(to: original, options: .atomic)
            item.imageRelativePath = relative(original, paths: paths)
            if let thumb = makeThumbnail(from: image) {
                let thumbURL = folder.appendingPathComponent("thumb.jpg")
                try thumb.write(to: thumbURL, options: .atomic)
                item.thumbnailRelativePath = relative(thumbURL, paths: paths)
            }
        }
        return item
    }

    static func loadData(relativePath: String?, paths: StoragePaths) -> Data? {
        guard let relativePath else { return nil }
        let url = paths.root.appendingPathComponent(relativePath)
        return try? Data(contentsOf: url)
    }

    static func loadImage(relativePath: String?, paths: StoragePaths) -> NSImage? {
        guard let relativePath else { return nil }
        let url = paths.root.appendingPathComponent(relativePath)
        return NSImage(contentsOf: url)
    }

    static func deleteMedia(id: UUID, paths: StoragePaths) {
        let folder = paths.mediaDirectory(for: id)
        try? FileManager.default.removeItem(at: folder)
    }

    static func makeThumbnail(from tiff: Data, maxDimension: CGFloat = 240) -> Data? {
        guard let image = NSImage(data: tiff) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let scale = min(1, maxDimension / max(size.width, size.height))
        let target = NSSize(width: max(1, size.width * scale), height: max(1, size.height * scale))
        let thumb = NSImage(size: target)
        thumb.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: target), from: NSRect(origin: .zero, size: size), operation: .copy, fraction: 1)
        thumb.unlockFocus()
        guard let tiffRep = thumb.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffRep) else { return nil }
        return bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.72])
    }

    private static func relative(_ url: URL, paths: StoragePaths) -> String {
        url.path.replacingOccurrences(of: paths.root.path + "/", with: "")
    }
}
