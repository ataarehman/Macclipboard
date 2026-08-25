import AppKit
import SwiftUI

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let now: Date
    let thumbnail: NSImage?
    var pasteImmediatelyOnClick: Bool
    var onSelect: () -> Void
    var onPaste: () -> Void
    var onCopy: () -> Void
    var onPin: () -> Void
    var onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: item.kind.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 4) {
                header
                preview
                Text(RelativeTime.string(from: item.updatedAt, now: now))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(rowBackground)
        .overlay(rowBorder)
        .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onTapGesture(count: 2, perform: onPaste)
        .onTapGesture(count: 1, perform: handleClick)
        .contextMenu {
            Button("Paste", action: onPaste)
            Button("Copy", action: onCopy)
            Button(item.isPinned ? "Unpin" : "Pin", action: onPin)
            Divider()
            Button("Delete", role: .destructive, action: onDelete)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.kind.title). \(item.previewText)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint("Paste this clipboard item")
    }

    private var header: some View {
        HStack {
            Text(item.kind.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            if let source = item.sourceApplicationName {
                Text(source)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button(action: onPin) {
                Image(systemName: item.isPinned ? "pin.fill" : "pin")
                    .foregroundStyle(item.isPinned ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help(item.isPinned ? "Unpin" : "Pin")
        }
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(isSelected ? Color.accentColor.opacity(0.18) : Color.primary.opacity(0.045))
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(isSelected ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1)
    }

    @ViewBuilder
    private var preview: some View {
        switch item.kind {
        case .image:
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                Text("Image")
                    .foregroundStyle(.secondary)
            }
        case .file:
            HStack(spacing: 8) {
                if let path = item.primaryFilePath {
                    Image(nsImage: AppIconService.icon(forFile: path))
                        .resizable()
                        .frame(width: 20, height: 20)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.primaryFileName ?? "File")
                        .font(.body)
                        .lineLimit(1)
                    if let path = item.primaryFilePath {
                        Text(FileManager.default.fileExists(atPath: path) ? path : "File is unavailable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
        case .url:
            VStack(alignment: .leading, spacing: 2) {
                if let host = item.urlString.flatMap(URL.init(string:))?.host {
                    Text(host)
                        .font(.subheadline.weight(.medium))
                }
                Text(item.urlString ?? item.previewText)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        case .text, .richText:
            Text(item.previewText)
                .lineLimit(4)
                .truncationMode(.tail)
        }
    }

    private func handleClick() {
        onSelect()
        if pasteImmediatelyOnClick {
            onPaste()
        }
    }
}

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .behindWindow
        view.state = .active
        view.wantsLayer = true
        view.layer?.cornerRadius = 14
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
