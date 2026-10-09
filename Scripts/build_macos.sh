#!/usr/bin/env bash
# Build the host app XenScalePreview.app (Quick Look extension embedded in Contents/PlugIns)
# and zip it into dist/ for distribution, e.g. as a GitHub release asset.
#
#   Scripts/build_macos.sh           native architecture, SwiftPM only (Command Line Tools are enough)
#   UNIVERSAL=1 Scripts/build_macos.sh     arm64 + x86_64 (needs full Xcode, not just Command Line Tools)
#   TEAM_ID=ABCDE12345 Scripts/build_macos.sh --archive
#                                    signed Xcode archive + export (needs Xcode and XcodeGen)
#                                    -> build/archives/XenScalePreview-macOS.xcarchive, build/export/macos/
#
# Version/build: version.env.
# Env overrides:
#   SIGN_ID="Developer ID Application: …"   signing identity (default "-" = ad-hoc)
#   BUNDLE_ID, VERSION, BUILD               see common.sh (the extension gets "$BUNDLE_ID.quicklook")
#   TEAM_ID, EXPORT_METHOD                  --archive only; EXPORT_METHOD is developer-id (default),
#                                           app-store-connect or mac-application (development)
#
# Output: dist/XenScalePreview.zip  (unzips to XenScalePreview.app)
set -euo pipefail
source "$(dirname "$0")/common.sh"

SIGN_ID="${SIGN_ID:--}"
ZIP="$DIST_DIR/$APP.zip"

require_macos

if [[ "${1:-}" == "--archive" ]]; then
  require_xcode; require_team
  METHOD="${EXPORT_METHOD:-developer-id}"
  "$SCRIPTS_DIR/gen_project.sh" >/dev/null
  ARCHIVE="$ARCHIVES/$APP-macOS.xcarchive"
  echo "==> Archiving ($BUNDLE_ID, $VERSION build $BUILD, team $TEAM_ID)"
  xc_archive "$APP-macOS" 'generic/platform=macOS' "$ARCHIVE"
  echo "==> Exporting ($METHOD)"
  xc_export "$ARCHIVE" "$EXPORTS/macos" "$METHOD"
  echo "Archive: $ARCHIVE"
  echo "Export:  $EXPORTS/macos/"
  exit 0
fi
[[ -z "${1:-}" ]] || { echo "usage: Scripts/build_macos.sh [--archive]" >&2; exit 2; }

# Note: ${arr[@]+"${arr[@]}"} keeps empty arrays safe under `set -u` in macOS's bash 3.2.
ARCH=()
if [[ "${UNIVERSAL:-0}" == 1 ]]; then ARCH=(--arch arm64 --arch x86_64); fi

echo "==> Building (release, ${ARCH[*]:-native arch})"
swift build -c release ${ARCH[@]+"${ARCH[@]}"}
BIN="$(swift build -c release ${ARCH[@]+"${ARCH[@]}"} --show-bin-path)"

echo "==> Assembling $APP.app ($BUNDLE_ID, $VERSION build $BUILD)"
# Assemble in a temp dir so Spotlight/LaunchServices never register a stray copy in the repo.
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT
OUT="$WORK/$APP.app"
APPEX="$OUT/Contents/PlugIns/$EXT.appex"
mkdir -p "$OUT/Contents/MacOS" "$APPEX/Contents/MacOS"
cp "$BIN/$APP" "$OUT/Contents/MacOS/$APP"
cp "$BIN/$EXT" "$APPEX/Contents/MacOS/$EXT"
cp Bundle/macOS-App-Info.plist "$OUT/Contents/Info.plist"
cp Bundle/Extension-Info.plist "$APPEX/Contents/Info.plist"
for pl in "$OUT/Contents/Info.plist" "$APPEX/Contents/Info.plist"; do
  plutil -replace CFBundleShortVersionString -string "$VERSION" "$pl"
  plutil -replace CFBundleVersion -string "$BUILD" "$pl"
  plutil -replace LSMinimumSystemVersion -string "12.0" "$pl"   # Xcode adds this itself; the shared plist omits it
done
mkdir -p "$OUT/Contents/Resources"
iconutil -c icns Bundle/AppIcon.iconset -o "$OUT/Contents/Resources/AppIcon.icns"
# Host-app wording (Xcode builds pick these up from project.yml): <lang>.lproj/Localizable.strings
cp -R Localization/App/*.lproj "$OUT/Contents/Resources/"
plutil -replace CFBundleIconFile -string AppIcon "$OUT/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$BUNDLE_ID" "$OUT/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "$EXT_ID" "$APPEX/Contents/Info.plist"
plutil -lint -s "$OUT/Contents/Info.plist" "$APPEX/Contents/Info.plist"

echo "==> Signing (identity: $SIGN_ID)"
# With a real certificate, also enable hardened runtime + timestamp (needed for notarization).
SIGN_OPTS=()
if [[ "$SIGN_ID" != "-" ]]; then SIGN_OPTS=(--options runtime --timestamp); fi
# Sign inside-out: the extension first (sandboxed), then the host app.
codesign --force --sign "$SIGN_ID" ${SIGN_OPTS[@]+"${SIGN_OPTS[@]}"} \
  --entitlements Bundle/Extension.entitlements "$APPEX"
codesign --force --sign "$SIGN_ID" ${SIGN_OPTS[@]+"${SIGN_OPTS[@]}"} "$OUT"
codesign --verify --deep --strict "$OUT"

echo "==> Packaging $ZIP"
mkdir -p "$DIST_DIR"
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$OUT" "$ZIP"
echo "Built $ZIP  ($APP.app $VERSION build $BUILD, $(lipo -archs "$OUT/Contents/MacOS/$APP"))"
