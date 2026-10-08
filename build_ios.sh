#!/usr/bin/env bash
# Build XenScalePreview for iOS / iPadOS (app + Quick Look extension). Needs full Xcode and XcodeGen.
#
#   ./build_ios.sh                  simulator build, no signing -> dist/XenScalePreview-iOS-Simulator.zip
#                                   install: unzip, then  xcrun simctl install booted XenScalePreview.app
#   TEAM_ID=ABCDE12345 ./build_ios.sh --archive
#                                   signed archive + export      -> dist/XenScalePreview-iOS.xcarchive, dist/ios/*.ipa
#
# Env overrides:
#   TEAM_ID=…            Apple Developer team ID (required for --archive)
#   BUNDLE_ID=com.you.xen-scale-preview   app bundle ID (default local.xen-scale-preview); the extension gets ".quicklook"
#   VERSION=1.2.0        marketing + build version (default 1.0)
#   EXPORT_METHOD=…      development (default), release-testing, or app-store-connect (for TestFlight / App Store)
set -euo pipefail
cd "$(dirname "$0")"

MODE=simulator
case "${1:-}" in
  "") ;;
  --archive) MODE=archive ;;
  *) echo "usage: ./build_ios.sh [--archive]" >&2; exit 2 ;;
esac

[[ "$(uname)" == Darwin ]] || { echo "This script runs on macOS only." >&2; exit 1; }
command -v xcodebuild >/dev/null || { echo "xcodebuild not found. Install Xcode." >&2; exit 1; }
export BUNDLE_ID="${BUNDLE_ID:-local.xen-scale-preview}" VERSION="${VERSION:-1.0}" TEAM_ID="${TEAM_ID:-}"
PROJ=XenScalePreview.xcodeproj
SCHEME=XenScalePreview-iOS

echo "==> Generating Xcode project"
./gen_project.sh >/dev/null

if [[ "$MODE" == simulator ]]; then
  echo "==> Building for the iOS Simulator (unsigned)"
  xcodebuild -project "$PROJ" -scheme "$SCHEME" -configuration Release \
    -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath build/dd CODE_SIGNING_ALLOWED=NO build -quiet
  APP=build/dd/Build/Products/Release-iphonesimulator/XenScalePreview.app
  [[ -d "$APP" ]] || { echo "Build finished but $APP is missing." >&2; exit 1; }
  mkdir -p dist
  rm -f dist/XenScalePreview-iOS-Simulator.zip
  ditto -c -k --keepParent "$APP" dist/XenScalePreview-iOS-Simulator.zip
  echo "Built dist/XenScalePreview-iOS-Simulator.zip"
  echo "Install:  xcrun simctl install booted $APP"
  exit 0
fi

[[ -n "$TEAM_ID" ]] || { echo "--archive needs TEAM_ID (your Apple Developer team ID)." >&2; exit 1; }
METHOD="${EXPORT_METHOD:-development}"
ARCHIVE=dist/XenScalePreview-iOS.xcarchive
echo "==> Archiving ($BUNDLE_ID, $VERSION, team $TEAM_ID)"
mkdir -p dist
rm -rf "$ARCHIVE"
xcodebuild -project "$PROJ" -scheme "$SCHEME" -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$ARCHIVE" \
  -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" archive -quiet

echo "==> Exporting ($METHOD)"
cat > build/ExportOptions-iOS.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>$METHOD</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
</dict></plist>
PLIST
rm -rf dist/ios
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath dist/ios \
  -exportOptionsPlist build/ExportOptions-iOS.plist -allowProvisioningUpdates
echo "Archive: $ARCHIVE"
echo "Export:  dist/ios/"
