import AppKit
import SwiftUI

@MainActor
@Observable
final class PanelSession {
    var query = ""
    var selectedID: ClipboardItem.ID?
    var searchFocused = false
    var now = Date()
    var toast: String?

    func reset(items: [ClipboardItem]) {
        query = ""
        searchFocused = false
        now = Date()
        toast = nil
        selectedID = items.first?.id
    }

    func moveSelection(in items: [ClipboardItem], delta: Int) {
        guard !items.isEmpty else {
            selectedID = nil
            return
        }
        let current = items.firstIndex(where: { $0.id == selectedID }) ?? -1
        let next = min(max(current + delta, 0), items.count - 1)
        selectedID = items[next].id
    }

    func selected(in items: [ClipboardItem]) -> ClipboardItem? {
        if let selectedID, let match = items.first(where: { $0.id == selectedID }) {
            return match
        }
        return items.first
    }
}

struct ClipboardPanelView: View {
    var items: [ClipboardItem]
    var shortcut: Shortcut
    var accessibilityGranted: Bool
    var pasteImmediatelyOnClick: Bool
    var paths: StoragePaths
    var session: PanelSession
    var onPaste: (ClipboardItem) -> Void
    var onCopy: (ClipboardItem) -> Void
    var onPin: (ClipboardItem) -> Void
    var onDelete: (ClipboardItem) -> Void
    var onClearUnpinned: () -> Void
    var onOpenSettings: () -> Void
    var onClose: () -> Void

    @FocusState private var searchFocused: Bool

    private var filtered: [ClipboardItem] {
        ClipboardSearch.filter(items, query: session.query)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
            Divider().opacity(0.35)
            content
            if let toast = session.toast {
                Text(toast)
                    .font(.caption)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .foregroundStyle(.secondary)
            }
            footer
        }
        .background(VisualEffectBackground())
        .frame(width: 430, height: 500)
        .onAppear {
            if session.selectedID == nil {
                session.selectedID = filtered.first?.id
            }
            searchFocused = session.searchFocused
        }
        .onChange(of: session.searchFocused) { _, newValue in
            searchFocused = newValue
        }
        .onChange(of: session.query) { _, _ in
            session.selectedID = filtered.first?.id
        }
    }

    private var header: some View {
        HStack {
            Text("Clipboard")
                .font(.headline)
            Spacer()
            if !accessibilityGranted {
                Text("Paste requires Accessibility")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Button(action: onOpenSettings) {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search clipboard…", text: Binding(
                get: { session.query },
                set: { session.query = $0 }
            ))
            .textFieldStyle(.plain)
            .focused($searchFocused)
        }
        .padding(8)
        .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        if filtered.isEmpty {
            emptyState
        } else {
            itemList
        }
    }

    private var itemList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(filtered) { item in
                        row(for: item)
                            .id(item.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: session.selectedID) { _, newValue in
                if let newValue {
                    withAnimation(.easeOut(duration: 0.12)) {
                        proxy.scrollTo(newValue, anchor: .center)
                    }
                }
            }
        }
    }

    private func row(for item: ClipboardItem) -> some View {
        ClipboardItemRow(
            item: item,
            isSelected: item.id == session.selectedID,
            now: session.now,
            thumbnail: ImageStorage.loadImage(
                relativePath: item.thumbnailRelativePath ?? item.imageRelativePath,
                paths: paths
            ),
            pasteImmediatelyOnClick: pasteImmediatelyOnClick,
            onSelect: { session.selectedID = item.id },
            onPaste: { onPaste(item) },
            onCopy: { onCopy(item) },
            onPin: { onPin(item) },
            onDelete: { confirmDelete(item) }
        )
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Spacer()
            if items.isEmpty {
                Text("Nothing copied yet")
                    .font(.headline)
                Text("Copy something with ⌘C and it will\nappear here.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            } else {
                Text("No matching items")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack {
            Button("Clear History", action: onClearUnpinned)
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            Spacer()
            Text(AppIdentity.privacyStatement)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func confirmDelete(_ item: ClipboardItem) {
        if item.isPinned {
            session.toast = "Unpin this item before deleting it."
            return
        }
        onDelete(item)
    }
}
