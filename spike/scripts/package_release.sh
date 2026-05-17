#!/usr/bin/env bash
# Notarized DMG packaging for the BarShelf central-risk spike.
# Pipeline mirrors the proven LidRun release flow:
#   build -> Developer ID sign (hardened runtime) -> notarize app -> staple
#   -> DMG -> sign DMG -> notarize DMG -> staple -> checksums -> verify.
#
#   VERSION=0.1.0.dev1 NOTARYTOOL_PROFILE=CodeRelayNotary ./scripts/package_release.sh
#
# Requires a one-time, machine-local notarytool keychain profile:
#   xcrun notarytool store-credentials <PROFILE>   (LidRun uses CodeRelayNotary)
# No secrets live in this repo.
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0.dev1}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-CodeRelayNotary}"
APP_NAME="BarShelfSpike"
VOL_NAME="BarShelf Spike"
DIST="dist"
APP="${DIST}/${APP_NAME}.app"
DMG_NAME="BarShelf-${VERSION}-macOS26-Tahoe-arm64.dmg"
DMG="${DIST}/${DMG_NAME}"

# Auto-detect Developer ID Application identity (mirrors LidRun: Team ID never committed).
IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null \
  | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n 1)"
[ -n "$IDENTITY" ] || { echo "ERROR: no 'Developer ID Application' identity in keychain" >&2; exit 1; }
echo "==> Identity:  $IDENTITY"
echo "==> Version:   $VERSION"
echo "==> Notary:    $NOTARYTOOL_PROFILE"

# 1. Clean build (release, arm64 only).
rm -rf "$DIST"
mkdir -p "$DIST"
swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/${APP_NAME}"

# 2. Assemble the .app bundle.
mkdir -p "${APP}/Contents/MacOS"
cp "$BIN" "${APP}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP}/Contents/Info.plist"
printf 'APPL????' > "${APP}/Contents/PkgInfo"

# 3. Strip xattrs and Developer ID sign (executable first, then bundle).
find "$APP" -exec xattr -c {} + 2>/dev/null || true
find "$APP" -name '._*' -delete 2>/dev/null || true
codesign --force --timestamp --options runtime --sign "$IDENTITY" "${APP}/Contents/MacOS/${APP_NAME}"
codesign --force --timestamp --options runtime --sign "$IDENTITY" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"

# 4. Notarize the app, staple, validate.
NOTARY_ZIP="${DIST}/${APP_NAME}-notary.zip"
COPYFILE_DISABLE=1 ditto --norsrc -c -k --keepParent "$APP" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$NOTARY_ZIP"

# 5. Build the DMG: stapled .app + drag-to-Applications symlink.
STAGE="${DIST}/stage"
rm -rf "$STAGE"; mkdir -p "$STAGE"
ditto "$APP" "${STAGE}/${APP_NAME}.app"
ln -s /Applications "${STAGE}/Applications"
find "$STAGE" -name '._*' -delete 2>/dev/null || true
rm -f "$DMG"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -format UDZO -ov "$DMG" >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
rm -rf "$STAGE"

# 6. Notarize the DMG, staple, validate.
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# 7. Checksums (BarShelf convention: SHA256SUMS.txt, no version suffix).
( cd "$DIST" && shasum -a 256 "$DMG_NAME" > "SHA256SUMS.txt" )

# 8. Final Gatekeeper verification (as a downloaded file would see it).
echo "=================== VERIFY ==================="
codesign --verify --deep --strict --verbose=4 "$APP"
spctl --assess --type open --context context:primary-signature -v "$DMG"
xcrun stapler validate "$DMG"
echo "---- SHA256SUMS.txt ----"
cat "${DIST}/SHA256SUMS.txt"
echo "=============================================="
echo "DMG ready: $DMG"
