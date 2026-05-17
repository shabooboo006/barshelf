#!/usr/bin/env bash
# Notarized DMG packaging for BarShelf.
# Pipeline mirrors the proven LidRun / spike flow:
#   build_app.sh (assemble + sign) -> notarize app -> staple
#   -> DMG -> sign DMG -> notarize DMG -> staple -> checksums -> verify.
#
#   VERSION=0.1.0 NOTARYTOOL_PROFILE=CodeRelayNotary bash scripts/package_release.sh
#
# Requires a one-time, machine-local notarytool keychain profile:
#   xcrun notarytool store-credentials <PROFILE>   (default: CodeRelayNotary)
# No secrets live in this repo.
#
# NOTE: Do NOT run this script until the controller step that performs notarization.
# Syntax-check only via: bash -n scripts/package_release.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${VERSION:-0.1.0}"
NOTARYTOOL_PROFILE="${NOTARYTOOL_PROFILE:-CodeRelayNotary}"
APP_NAME="BarShelf"
VOL_NAME="BarShelf"
DMG_NAME="BarShelf-${VERSION}-macOS26-Tahoe-arm64.dmg"
DIST="dist"
APP="${DIST}/${APP_NAME}.app"
DMG="${DIST}/${DMG_NAME}"

# Auto-detect Developer ID Application identity (Team ID never committed).
IDENTITY="$(security find-identity -p codesigning -v 2>/dev/null \
  | sed -n 's/.*"\(Developer ID Application: [^"]*\)".*/\1/p' | head -n1)"
[ -n "$IDENTITY" ] || { echo "ERROR: no 'Developer ID Application' identity in keychain" >&2; exit 1; }
echo "==> Identity:  $IDENTITY"
echo "==> Version:   $VERSION"
echo "==> Notary:    $NOTARYTOOL_PROFILE"

# 1. Build + assemble + sign via the existing script.
#    build_app.sh produces a signed dist/BarShelf.app (includes the T1 resource-bundle fix).
#    Do NOT re-sign here — we notarize what build_app.sh produced.
bash scripts/build_app.sh

# 2. Notarize the app, staple, validate.
NOTARY_ZIP="${DIST}/BarShelf-notary.zip"
COPYFILE_DISABLE=1 ditto --norsrc -c -k --keepParent "$APP" "$NOTARY_ZIP"
xcrun notarytool submit "$NOTARY_ZIP" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$APP"
xcrun stapler validate "$APP"
rm -f "$NOTARY_ZIP"

# 3. Build the DMG: stapled .app + drag-to-Applications symlink.
STAGE="${DIST}/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE"
ditto "$APP" "${STAGE}/${APP_NAME}.app"
ln -s /Applications "${STAGE}/Applications"
find "$STAGE" -name '._*' -delete 2>/dev/null || true
rm -f "$DMG"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -format UDZO -ov "$DMG" >/dev/null
codesign --force --timestamp --sign "$IDENTITY" "$DMG"
rm -rf "$STAGE"

# 4. Notarize the DMG, staple, validate.
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARYTOOL_PROFILE" --wait
xcrun stapler staple "$DMG"
xcrun stapler validate "$DMG"

# 5. Checksums (CLAUDE.md convention: SHA256SUMS.txt, no version suffix).
( cd "$DIST" && shasum -a 256 "$DMG_NAME" > "SHA256SUMS.txt" )

# 6. Final Gatekeeper verification (as a downloaded file would see it).
echo "=================== VERIFY ==================="
codesign --verify --deep --strict --verbose=2 "$APP"
spctl --assess --type open --context context:primary-signature -v "$DMG"
xcrun stapler validate "$DMG"
echo "---- SHA256SUMS.txt ----"
cat "${DIST}/SHA256SUMS.txt"
echo "=============================================="
echo "DMG ready: $DMG"
