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

# Copy SwiftPM resource bundle into Contents/Resources/ so Bundle.barshelfResources
# resolves correctly in the shipped .app, and codesign can seal it.
#
# Placement rationale (from BundleResources.swift):
#   Bundle.barshelfResources first checks Bundle.main.resourceURL + "BarShelf_BarShelf.bundle"
#   = .app/Contents/Resources/BarShelf_BarShelf.bundle  (the standard codesign-safe location).
#
# Why NOT .app root: macOS codesign only allows items inside Contents/; anything at the .app
# root that looks like a bundle is rejected as "unsealed contents present in the bundle root".
#
# Bundle layout: SwiftPM's CLI build produces a flat bundle (Resources/ subdir, no Info.plist).
# codesign requires a proper macOS bundle structure (Contents/Info.plist + Contents/Resources/).
# We reconstruct it here; Bundle.url(forResource:withExtension:) searches Contents/Resources/,
# so "forResource: 'Resources/foo'" finds Contents/Resources/Resources/foo.png — matching
# what the source code requests (the Resources/ subdirectory is preserved as-is).
RESBUNDLE="$(swift build -c release --arch arm64 --show-bin-path)/BarShelf_BarShelf.bundle"
BUNDLED_RES="$APP/Contents/Resources/BarShelf_BarShelf.bundle"
if [ -d "$RESBUNDLE" ]; then
  mkdir -p "$BUNDLED_RES/Contents/Resources"
  cp -R "$RESBUNDLE/Resources" "$BUNDLED_RES/Contents/Resources/Resources"
  cat > "$BUNDLED_RES/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.chunyuxia.barshelf.resources</string>
  <key>CFBundlePackageType</key><string>BNDL</string>
  <key>CFBundleVersion</key><string>1</string>
</dict></plist>
PLIST
fi

# Sign the nested resource bundle first (inside-out rule), then seal the .app.
if [ -d "$BUNDLED_RES" ]; then
  codesign --force --options runtime --timestamp \
    --sign "$IDENTITY" "$BUNDLED_RES"
fi

codesign --force --options runtime --timestamp \
  --sign "$IDENTITY" "$APP"
codesign --verify --strict --verbose=2 "$APP"
echo "Built and signed: $APP"
