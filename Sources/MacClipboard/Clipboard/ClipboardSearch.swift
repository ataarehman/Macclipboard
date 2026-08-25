import Foundation

enum ClipboardSearch {
    static func matches(_ item: ClipboardItem, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        return item.searchCorpus.localizedStandardContains(trimmed)
    }

    static func filter(_ items: [ClipboardItem], query: String) -> [ClipboardItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return items }
        return items.filter { matches($0, query: trimmed) }
    }
}
