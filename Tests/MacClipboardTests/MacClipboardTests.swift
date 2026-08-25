import Foundation

/// These XCTest-style cases document the intended coverage.
/// Command Line Tools on this machine do not include XCTest, so the runnable
/// suite lives in `Sources/MacClipboard/Support/LogicTests.swift` and is invoked with:
/// `swift build && .build/debug/MacClipboard --run-tests`
enum MacClipboardTestCatalog {
    static let cases = [
        "hashing",
        "duplicate handling",
        "history limits",
        "search",
        "parser",
        "settings persistence",
        "relative time"
    ]
}
