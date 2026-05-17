#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP="dist/BarShelf.app"
IDENTITY="Developer ID Application: CHUNYU XIA (XKR29B92B2)"

swift build -c release --arch arm64

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/arm64-apple-macosx/release/BarShelf" "$APP/Contents/MacOS/BarShelf"
cp "Sources/BarShelf/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
cp "Sources/BarShelf/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

codesign --force --options runtime --timestamp \
  --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "Built and signed: $APP"
