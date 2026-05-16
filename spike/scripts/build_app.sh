#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/BarShelfSpike.app"
IDENTITY="Developer ID Application: CHUNYU XIA (XKR29B92B2)"

swift build -c release --arch arm64

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp ".build/release/BarShelfSpike" "$APP/Contents/MacOS/BarShelfSpike"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

codesign --force --options runtime --timestamp \
  --sign "$IDENTITY" "$APP"
codesign --verify --verbose "$APP"
echo "Built and signed: $APP"
