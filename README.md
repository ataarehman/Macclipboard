# MacClipboard

Windows-style clipboard history for macOS.

Copy with **⌘C**, open history with **⌃⌥V**, then use the arrow keys and **Enter** to paste an older item into the app you were using. History is stored only on this Mac.

## What it is

MacClipboard is a native Apple Silicon menu-bar utility. It recreates the essential **Windows + V** workflow without Electron, Tauri, or a web UI.

- Swift 6, SwiftUI, and AppKit
- Apple Silicon / `arm64`
- macOS 14+

## Features

- Continuously monitors `NSPasteboard.general` (about every 400 ms)
- History for text, URLs, images, files, and rich text (with a plain-text fallback)
- Duplicate detection via content hashing (duplicates move to the top)
- Configurable limit: 25 / 50 / 100 / 250 / 500 items (default 100)
- Global shortcut, default **⌃⌥V**, with an in-Settings recorder
- Conflict warnings for common shortcuts such as ⌘C / ⌘V / ⌘F (Cancel or Use Anyway)
- Floating clipboard panel with search, pinning, delete, and keyboard navigation
- Select → Enter → paste into the previous app (synthetic ⌘V)
- Application exclusions, pause monitoring, launch at login
- Optional Dock icon (off by default)
- Light / Dark / System appearance
- 100% local. No network, analytics, accounts, or cloud sync

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 14 Sonoma or later
- Accessibility permission for automatic paste (history still works without it)

## Install

1. Build the app (see below) or copy `dist/MacClipboard.app`.
2. Move `MacClipboard.app` into `/Applications` (recommended so Accessibility and Launch at Login stay stable).
3. Open it once. A clipboard icon appears in the menu bar.
4. Grant Accessibility permission when asked, or from Settings inside the app.

## Development setup

This repository is a Swift Package. Full Xcode is optional.

```text
swift --version          # Swift 6+
# Command Line Tools are enough to compile and package
```

Open `MacClipboard.xcodeproj` in Xcode 16+ if you have it.

## Build instructions

From the project root:

```bash
# Debug compile
swift build

# Unit tests (Command Line Tools do not ship XCTest)
./scripts/test.sh

# Release .app (arm64, ad-hoc signed)
./scripts/package-app.sh
```

The packaged app is written to:

```text
dist/MacClipboard.app
```

Run it with:

```bash
open dist/MacClipboard.app
```

## Keyboard shortcut

Default: **⌃⌥V** (Control + Option + V)

Change it in **Settings → Keyboard**. Record a new combination, or reset to default.

While the popup is open:

| Key | Action |
| --- | --- |
| ↑ / ↓ | Move selection |
| Enter | Paste selected item |
| Esc | Close |
| ⌘F | Focus search (unless that is the global shortcut) |
| ⌘P | Pin / unpin |
| Delete | Remove the selected unpinned item |

Clicking an item pastes immediately unless you turn that off in Settings.

## Accessibility permission

Automatic paste needs macOS Accessibility so MacClipboard can restore the previous app and send ⌘V.

**System Settings → Privacy & Security → Accessibility → enable MacClipboard**

The app can open that pane for you. Clipboard history, search, pin, and copy still work if permission is off; you would then paste with ⌘V yourself.

Ad-hoc signed builds are tied to the exact binary path. If you rebuild and move the `.app`, you may need to enable Accessibility again.

## Privacy

Your clipboard history stays on this Mac. MacClipboard does not upload data, talk to APIs, or include analytics.

Treat local history as sensitive. Use:

- Excluded applications (password managers, banking apps)
- Pause clipboard monitoring
- Clear history
- Transient / concealed pasteboard markers (`org.nspasteboard.*`) are skipped when apps set them

## Data location

```text
~/Library/Application Support/MacClipboard/history.json
~/Library/Application Support/MacClipboard/media/
```

Preferences live in UserDefaults under the `MacClipboard.` key prefix.

## Reset / clear data

- **Clear History** in the popup or menu bar removes unpinned items and keeps pins.
- **Settings → Storage → Clear All History** removes everything, including pins, after confirmation.
- To wipe on-disk data: quit the app, then delete `~/Library/Application Support/MacClipboard`.

## Architecture

```text
Sources/MacClipboard/
  App/           App identity, SwiftUI entry, composition root
  Clipboard/     Monitor, parser, hasher, history engine, repository
  HotKey/        CGEventTap + Carbon fallback, shortcut model
  Paste/         CGEvent ⌘V + Accessibility permission
  Panel/         Non-activating NSPanel + SwiftUI content
  MenuBar/       NSStatusItem
  Settings/      General, Keyboard, Privacy, Storage
  Storage/       Application Support JSON + image files
  Services/      Frontmost app, launch at login, pause
  Onboarding/    First-run flow
```

Clipboard writes that MacClipboard itself performs are tagged with `com.macclipboard.internal` and ignored by the monitor so paste-back does not create a history loop.

### App Sandbox

**Off.** The entitlements file is empty on purpose.

App Sandbox blocks `CGEvent.post` and session-level `CGEventTap`. Both are required for:

- A global shortcut that still fires inside Cursor / Zed
- Injecting ⌘V into the previous application

This is a personal, direct-distributed utility, not a Mac App Store app. Do not enable App Sandbox unless you replace paste injection with a different mechanism.

### Global shortcut

`GlobalHotKeyManager` prefers a session `CGEventTap` (works when Accessibility is granted). If the tap cannot be created, it falls back to Carbon `RegisterEventHotKey`, which does not need Accessibility but can miss keypresses in some terminals and self-drawn apps.

## Known limitations

- The source app is inferred from the frontmost app at capture time. macOS does not guarantee pasteboard authorship.
- Some apps ignore synthetic ⌘V. The selected item is still placed on the clipboard.
- `SMAppService` launch-at-login can fail or need approval for ad-hoc / unsigned builds.
- Rebuilding or moving an ad-hoc signed app can require granting Accessibility again.
- Color swatches, iCloud sync, numbered ⌘1–⌘9 paste, and Quick Look preview are not in this MVP.

## Rename later

Change `AppIdentity.displayName` and `AppIdentity.bundleIdentifier` in `Sources/MacClipboard/App/AppIdentity.swift`, plus `Resources/Info.plist`.
