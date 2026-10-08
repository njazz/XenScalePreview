#!/usr/bin/env bash
# Build the host app XenScalePreview.app (Quick Look extension embedded in Contents/PlugIns)
# and zip it into dist/ for distribution, e.g. as a GitHub release asset.
#
#   ./build_macos.sh                 native architecture, SwiftPM only (Command Line Tools are enough)
#   UNIVERSAL=1 ./build_macos.sh     arm64 + x86_64 (needs full Xcode, not just Command Line Tools)
#   TEAM_ID=ABCDE12345 ./build_macos.sh --archive
#                                    signed Xcode archive + export (needs Xcode and XcodeGen)
#                                    -> dist/XenScalePreview-macOS.xcarchive, dist/macos/
#
# Env overrides:
#   SIGN_ID="Developer ID Application: …"   signing identity (default "-" = ad-hoc)
#   BUNDLE_ID=com.yourdomain.xen-scale-preview   app bundle ID (default com.alexnadzharov.xenscalepreview);
#                                           the extension gets "$BUNDLE_ID.quicklook"
#   VERSION=1.2.0                           CFBundleShortVersionString/CFBundleVersion (default 1.0)
#   TEAM_ID, EXPORT_METHOD                  --archive only; EXPORT_METHOD is developer-id (default),
#                                           app-store-connect or mac-application (development)
#
# Output: dist/XenScalePreview.zip  (unzips to XenScalePreview.app)
set -euo pipefail
cd "$(dirname "$0")"

APP=XenScalePreview
EXT=XenScalePreviewExtension
BUNDLE_ID="${BUNDLE_ID:-com.alexnadzharov.xenscalepreview}"
EXT_ID="$BUNDLE_ID.quicklook"
SIGN_ID="${SIGN_ID:--}"
VERSION="${VERSION:-1.0.0}"
ZIP="dist/$APP.zip"

[[ "$(uname)" == Darwin ]] || { echo "This script runs on macOS only." >&2; exit 1; }

if [[ "${1:-}" == "--archive" ]]; then
  command -v xcodebuild >/dev/null || { echo "xcodebuild not found. Install Xcode." >&2; exit 1; }
  TEAM_ID="${TEAM_ID:-}"
  [[ -n "$TEAM_ID" ]] || { echo "--archive needs TEAM_ID (your Apple Developer team ID)." >&2; exit 1; }
  METHOD="${EXPORT_METHOD:-developer-id}"
  export BUNDLE_ID VERSION TEAM_ID
  ./gen_project.sh >/dev/null
  ARCHIVE=dist/$APP-macOS.xcarchive
  echo "==> Archiving ($BUNDLE_ID, $VERSION, team $TEAM_ID)"
  mkdir -p dist
  rm -rf "$ARCHIVE" dist/macos
  xcodebuild -project $APP.xcodeproj -scheme "$APP-macOS" -configuration Release \
    -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" \
    -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" archive -quiet
  echo "==> Exporting ($METHOD)"
  cat > build/ExportOptions-macOS.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>$METHOD</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
  xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath dist/macos \
    -exportOptionsPlist build/ExportOptions-macOS.plist -allowProvisioningUpdates
  echo "Archive: $ARCHIVE"
  echo "Export:  dist/macos/"
  exit 0
fi
[[ -z "${1:-}" ]] || { echo "usage: ./build_macos.sh [--archive]" >&2; exit 2; }

# Note: ${arr[@]+"${arr[@]}"} keeps empty arrays safe under `set -u` in macOS's bash 3.2.
ARCH=()
if [[ "${UNIVERSAL:-0}" == 1 ]]; then ARCH=(--arch arm64 --arch x86_64); fi

echo "==> Building (release, ${ARCH[*]:-native arch})"
swift build -c release ${ARCH[@]+"${ARCH[@]}"}
BIN="$(swift build -c release ${ARCH[@]+"${ARCH[@]}"} --show-bin-path)"

echo "==> Assembling $APP.app ($BUNDLE_ID, $VERSION)"
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
  plutil -replace CFBundleVersion -string "$VERSION" "$pl"
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
mkdir -p dist
rm -f "$ZIP"
ditto -c -k --sequesterRsrc --keepParent "$OUT" "$ZIP"
echo "Built $ZIP  ($APP.app $VERSION, $(lipo -archs "$OUT/Contents/MacOS/$APP"))"
