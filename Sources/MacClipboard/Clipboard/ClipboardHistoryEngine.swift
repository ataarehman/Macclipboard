import Foundation

enum ClipboardHistoryEngine {
    static func upsert(
        items: [ClipboardItem],
        newItem: ClipboardItem,
        maxUnpinned: Int
    ) -> [ClipboardItem] {
        var items = items
        if let index = items.firstIndex(where: { $0.contentHash == newItem.contentHash }) {
            var existing = items.remove(at: index)
            existing.updatedAt = newItem.updatedAt
            existing.kind = newItem.kind
            existing.plainText = newItem.plainText ?? existing.plainText
            existing.urlString = newItem.urlString ?? existing.urlString
            existing.previewText = newItem.previewText.isEmpty ? existing.previewText : newItem.previewText
            existing.filePaths = newItem.filePaths.isEmpty ? existing.filePaths : newItem.filePaths
            existing.fileNames = newItem.fileNames.isEmpty ? existing.fileNames : newItem.fileNames
            existing.rtfRelativePath = newItem.rtfRelativePath ?? existing.rtfRelativePath
            existing.htmlRelativePath = newItem.htmlRelativePath ?? existing.htmlRelativePath
            existing.imageRelativePath = newItem.imageRelativePath ?? existing.imageRelativePath
            existing.thumbnailRelativePath = newItem.thumbnailRelativePath ?? existing.thumbnailRelativePath
            existing.sourceApplicationName = newItem.sourceApplicationName ?? existing.sourceApplicationName
            existing.sourceBundleIdentifier = newItem.sourceBundleIdentifier ?? existing.sourceBundleIdentifier
            items.insert(existing, at: 0)
            return sort(items)
        }

        items.insert(newItem, at: 0)
        return trim(sort(items), maxUnpinned: maxUnpinned)
    }

    static func sort(_ items: [ClipboardItem]) -> [ClipboardItem] {
        items.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned && !rhs.isPinned
            }
            return lhs.updatedAt > rhs.updatedAt
        }
    }

    static func trim(_ items: [ClipboardItem], maxUnpinned: Int) -> [ClipboardItem] {
        let limit = max(1, maxUnpinned)
        var kept: [ClipboardItem] = []
        var unpinnedCount = 0
        for item in sort(items) {
            if item.isPinned {
                kept.append(item)
            } else if unpinnedCount < limit {
                kept.append(item)
                unpinnedCount += 1
            }
        }
        return kept
    }

    static func setPinned(_ items: [ClipboardItem], id: UUID, isPinned: Bool) -> [ClipboardItem] {
        var items = items
        guard let index = items.firstIndex(where: { $0.id == id }) else { return items }
        items[index].isPinned = isPinned
        items[index].updatedAt = items[index].updatedAt
        return sort(items)
    }

    static func delete(_ items: [ClipboardItem], id: UUID) -> [ClipboardItem] {
        items.filter { $0.id != id }
    }

    static func clearUnpinned(_ items: [ClipboardItem]) -> [ClipboardItem] {
        items.filter(\.isPinned)
    }

    static func clearOlderThan(_ items: [ClipboardItem], date: Date) -> [ClipboardItem] {
        items.filter { $0.isPinned || $0.updatedAt >= date }
    }
}
