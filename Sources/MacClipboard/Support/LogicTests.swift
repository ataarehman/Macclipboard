import Foundation

@MainActor
enum LogicTests {
    static func run() -> Int {
        var failures = 0

        func check(_ condition: Bool, _ name: String) {
            if condition {
                print("PASS \(name)")
            } else {
                print("FAIL \(name)")
                failures += 1
            }
        }

        check(
            ClipboardHasher.hashPlainText("Hello") == ClipboardHasher.hashPlainText("Hello"),
            "hashingSameTextProducesSameHash"
        )
        check(
            ClipboardHasher.hashPlainText("Hello") != ClipboardHasher.hashPlainText("World"),
            "hashingDifferentTextProducesDifferentHash"
        )
        check(
            ClipboardHasher.hashURL("https://example.com") == ClipboardHasher.hashURL("https://example.com"),
            "hashingURLNormalizesIdentity"
        )
        check(
            ClipboardHasher.hashFiles(["/tmp/b.txt", "/tmp/a.txt"]) == ClipboardHasher.hashFiles(["/tmp/a.txt", "/tmp/b.txt"]),
            "hashingFilesIsOrderIndependent"
        )

        let first = sampleItem(id: UUID(), text: "Hello", date: Date(timeIntervalSince1970: 1))
        let second = sampleItem(id: UUID(), text: "Other", date: Date(timeIntervalSince1970: 2))
        let duplicate = sampleItem(id: UUID(), text: "Hello", date: Date(timeIntervalSince1970: 3))
        let upserted = ClipboardHistoryEngine.upsert(items: [second, first], newItem: duplicate, maxUnpinned: 100)
        check(upserted.count == 2, "duplicateDoesNotCreateExtraItem")
        check(upserted[0].id == first.id, "duplicateKeepsOriginalIdentity")
        check(upserted[0].updatedAt == duplicate.updatedAt, "duplicateUpdatesTimestamp")

        let pinned = sampleItem(id: UUID(), text: "pinned", date: Date(timeIntervalSince1970: 1), pinned: true)
        let old = sampleItem(id: UUID(), text: "old", date: Date(timeIntervalSince1970: 2))
        let newer = sampleItem(id: UUID(), text: "newer", date: Date(timeIntervalSince1970: 3))
        let newest = sampleItem(id: UUID(), text: "newest", date: Date(timeIntervalSince1970: 4))
        let trimmed = ClipboardHistoryEngine.trim([newest, newer, old, pinned], maxUnpinned: 2)
        let texts = Set(trimmed.compactMap(\.plainText))
        check(trimmed.contains(where: \.isPinned), "pinnedItemSurvivesTrim")
        check(texts.contains("pinned") && texts.contains("newest") && texts.contains("newer"), "newestUnpinnedAreKept")
        check(!texts.contains("old"), "oldestUnpinnedIsRemoved")

        let text = sampleItem(id: UUID(), text: "Deploy Odoo production", date: .now)
        var url = sampleItem(id: UUID(), text: "link", date: .now)
        url.kind = .url
        url.urlString = "https://example.com/odoo"
        url.previewText = url.urlString ?? ""
        var file = sampleItem(id: UUID(), text: "file", date: .now)
        file.kind = .file
        file.fileNames = ["Report.pdf"]
        file.filePaths = ["/Users/app/Documents/Report.pdf"]
        file.previewText = "Report.pdf"
        check(ClipboardSearch.matches(text, query: "odoo"), "searchMatchesTextCaseInsensitive")
        check(ClipboardSearch.matches(url, query: "ODOO"), "searchMatchesURL")
        check(ClipboardSearch.matches(file, query: "report.pdf"), "searchMatchesFilename")
        check(!ClipboardSearch.matches(text, query: "missing"), "searchRejectsNonMatches")

        let parsedText = ClipboardContentParser.parse(
            PasteboardSnapshot(typeIdentifiers: ["public.utf8-plain-text"], string: "Hello", urlString: nil, html: nil, rtf: nil, imageTIFF: nil, fileURLs: [])
        )
        check(parsedText?.kind == .text && parsedText?.plainText == "Hello", "parserReadsPlainText")

        let parsedURL = ClipboardContentParser.parse(
            PasteboardSnapshot(typeIdentifiers: ["public.url"], string: "https://example.com", urlString: "https://example.com", html: nil, rtf: nil, imageTIFF: nil, fileURLs: [])
        )
        check(parsedURL?.kind == .url, "parserReadsURL")

        let parsedFile = ClipboardContentParser.parse(
            PasteboardSnapshot(typeIdentifiers: ["public.file-url"], string: nil, urlString: nil, html: nil, rtf: nil, imageTIFF: nil, fileURLs: [URL(fileURLWithPath: "/tmp/notes.txt")])
        )
        check(parsedFile?.kind == .file && parsedFile?.fileNames == ["notes.txt"], "parserReadsFile")

        let skipped = ClipboardContentParser.parse(
            PasteboardSnapshot(typeIdentifiers: ["org.nspasteboard.TransientType"], string: "secret", urlString: nil, html: nil, rtf: nil, imageTIFF: nil, fileURLs: [])
        )
        check(skipped == nil, "parserSkipsTransient")

        let concealed = ClipboardContentParser.parse(
            PasteboardSnapshot(typeIdentifiers: ["org.nspasteboard.ConcealedType"], string: "password", urlString: nil, html: nil, rtf: nil, imageTIFF: nil, fileURLs: [])
        )
        check(concealed == nil, "parserSkipsConcealed")

        let now = Date()
        check(RelativeTime.string(from: now.addingTimeInterval(-2), now: now) == "Just now", "relativeTimeJustNow")
        check(RelativeTime.string(from: now.addingTimeInterval(-15), now: now) == "15 sec ago", "relativeTimeSeconds")
        check(RelativeTime.string(from: now.addingTimeInterval(-180), now: now) == "3 min ago", "relativeTimeMinutes")
        check(RelativeTime.string(from: now.addingTimeInterval(-3600), now: now) == "1 hr ago", "relativeTimeHours")

        let suite = "MacClipboardTests.\(UUID().uuidString)"
        if let defaults = UserDefaults(suiteName: suite) {
            defaults.removePersistentDomain(forName: suite)
            let store = SettingsStore(defaults: defaults)
            store.maxHistoryItems = 250
            store.shortcut = .default
            let reloaded = SettingsStore(defaults: defaults)
            check(
                reloaded.maxHistoryItems == 250 && reloaded.shortcut == .default,
                "settingsPersistHistorySizeAndShortcut"
            )
            defaults.removePersistentDomain(forName: suite)
        } else {
            check(false, "settingsPersistHistorySizeAndShortcut")
        }

        if failures == 0 {
            print("All tests passed.")
        } else {
            print("\(failures) test(s) failed.")
        }
        return failures
    }
}

private func sampleItem(id: UUID, text: String, date: Date, pinned: Bool = false) -> ClipboardItem {
    ClipboardItem(
        id: id,
        kind: .text,
        plainText: text,
        urlString: nil,
        previewText: text,
        filePaths: [],
        fileNames: [],
        rtfRelativePath: nil,
        htmlRelativePath: nil,
        imageRelativePath: nil,
        thumbnailRelativePath: nil,
        createdAt: date,
        updatedAt: date,
        isPinned: pinned,
        sourceApplicationName: nil,
        sourceBundleIdentifier: nil,
        contentHash: ClipboardHasher.hashPlainText(text)
    )
}
