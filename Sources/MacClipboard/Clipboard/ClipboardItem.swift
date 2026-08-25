import Foundation

enum ClipboardItemKind: String, Codable, Sendable, CaseIterable {
    case text
    case url
    case image
    case file
    case richText

    var title: String {
        switch self {
        case .text: "Text"
        case .url: "URL"
        case .image: "Image"
        case .file: "File"
        case .richText: "Rich Text"
        }
    }

    var symbolName: String {
        switch self {
        case .text: "doc.text"
        case .url: "link"
        case .image: "photo"
        case .file: "doc"
        case .richText: "doc.richtext"
        }
    }
}

struct ClipboardItem: Identifiable, Codable, Equatable, Sendable, Hashable {
    var id: UUID
    var kind: ClipboardItemKind
    var plainText: String?
    var urlString: String?
    var previewText: String
    var filePaths: [String]
    var fileNames: [String]
    var rtfRelativePath: String?
    var htmlRelativePath: String?
    var imageRelativePath: String?
    var thumbnailRelativePath: String?
    var createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var sourceApplicationName: String?
    var sourceBundleIdentifier: String?
    var contentHash: String

    var primaryFilePath: String? { filePaths.first }
    var primaryFileName: String? { fileNames.first ?? primaryFilePath.map { URL(fileURLWithPath: $0).lastPathComponent } }

    var searchCorpus: String {
        var parts: [String] = [previewText]
        if let plainText { parts.append(plainText) }
        if let urlString { parts.append(urlString) }
        parts.append(contentsOf: fileNames)
        parts.append(contentsOf: filePaths)
        if let sourceApplicationName { parts.append(sourceApplicationName) }
        return parts.joined(separator: "\n")
    }
}

struct ParsedClipboard: Equatable, Sendable {
    var kind: ClipboardItemKind
    var plainText: String?
    var urlString: String?
    var previewText: String
    var filePaths: [String]
    var fileNames: [String]
    var rtfData: Data?
    var htmlData: Data?
    var imageData: Data?
    var contentHash: String
}

struct SourceApplication: Equatable, Sendable {
    var name: String
    var bundleIdentifier: String
}

struct PasteboardSnapshot: Equatable, Sendable {
    var typeIdentifiers: [String]
    var string: String?
    var urlString: String?
    var html: Data?
    var rtf: Data?
    var imageTIFF: Data?
    var fileURLs: [URL]
}
