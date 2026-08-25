#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CONFIGURATION="${1:-release}"
ARCH="${2:-arm64}"

echo "Building MacClipboard ($CONFIGURATION, $ARCH)…"
swift build -c "$CONFIGURATION" --arch "$ARCH"

if [[ "$CONFIGURATION" == "release" ]]; then
  BIN="$ROOT/.build/release/MacClipboard"
else
  BIN="$ROOT/.build/debug/MacClipboard"
fi

if [[ ! -x "$BIN" ]]; then
  echo "error: missing binary at $BIN" >&2
  exit 1
fi

APP="$ROOT/dist/MacClipboard.app"
CONTENTS="$APP/Contents"
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"

cp "$BIN" "$CONTENTS/MacOS/MacClipboard"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

if [[ -f "$ROOT/Resources/AppIcon.icns" ]]; then
  cp "$ROOT/Resources/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
fi

chmod +x "$CONTENTS/MacOS/MacClipboard"
codesign --force --sign - --identifier com.macclipboard.app "$APP"

echo "BUILD SUCCEEDED"
echo "App: $APP"
file "$CONTENTS/MacOS/MacClipboard"
