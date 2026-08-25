import CryptoKit
import Foundation

enum ClipboardHasher {
    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func hashPlainText(_ text: String) -> String {
        sha256(Data(("text:" + text).utf8))
    }

    static func hashURL(_ url: String) -> String {
        sha256(Data(("url:" + normalizedURL(url)).utf8))
    }

    static func hashImage(_ data: Data) -> String {
        var combined = Data("image:".utf8)
        combined.append(data)
        return sha256(combined)
    }

    static func hashFiles(_ paths: [String]) -> String {
        let joined = paths.map(normalizedPath).sorted().joined(separator: "\n")
        return sha256(Data(("files:" + joined).utf8))
    }

    static func hash(parsed: ParsedClipboard) -> String {
        parsed.contentHash
    }

    static func normalizedURL(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func normalizedPath(_ raw: String) -> String {
        URL(fileURLWithPath: raw).standardizedFileURL.path
    }
}
