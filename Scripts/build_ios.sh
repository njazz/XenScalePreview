#!/usr/bin/env bash
# Build XenScalePreview for iOS / iPadOS (app + Quick Look extension). Needs full Xcode and XcodeGen.
#
#   Scripts/build_ios.sh            simulator build, no signing -> dist/XenScalePreview-iOS-Simulator.zip
#                                   install: unzip, then  xcrun simctl install booted XenScalePreview.app
#   TEAM_ID=ABCDE12345 Scripts/build_ios.sh --archive
#                                   signed archive + export     -> build/archives/XenScalePreview-iOS.xcarchive,
#                                                                  build/export/ios/*.ipa
#
# Version/build: version.env.
# Env overrides: TEAM_ID (required for --archive), BUNDLE_ID, VERSION, BUILD,
#   EXPORT_METHOD  development (default), release-testing, or app-store-connect
#   (for App Store / TestFlight uploads prefer Scripts/build_appstore.sh)
set -euo pipefail
source "$(dirname "$0")/common.sh"

MODE=simulator
case "${1:-}" in
  "") ;;
  --archive) MODE=archive ;;
  *) echo "usage: Scripts/build_ios.sh [--archive]" >&2; exit 2 ;;
esac

require_macos; require_xcode
SCHEME="$APP-iOS"

echo "==> Generating Xcode project ($BUNDLE_ID, $VERSION build $BUILD)"
"$SCRIPTS_DIR/gen_project.sh" >/dev/null

if [[ "$MODE" == simulator ]]; then
  echo "==> Building for the iOS Simulator (unsigned)"
  xcodebuild -project "$PROJ" -scheme "$SCHEME" -configuration Release \
    -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
    -derivedDataPath "$DERIVED" CODE_SIGNING_ALLOWED=NO build -quiet
  APP_PATH="$DERIVED/Build/Products/Release-iphonesimulator/$APP.app"
  [[ -d "$APP_PATH" ]] || die "build finished but $APP_PATH is missing."
  mkdir -p "$DIST_DIR"
  rm -f "$DIST_DIR/$APP-iOS-Simulator.zip"
  ditto -c -k --keepParent "$APP_PATH" "$DIST_DIR/$APP-iOS-Simulator.zip"
  echo "Built $DIST_DIR/$APP-iOS-Simulator.zip"
  echo "Install:  xcrun simctl install booted $APP_PATH"
  exit 0
fi

require_team
METHOD="${EXPORT_METHOD:-development}"
ARCHIVE="$ARCHIVES/$APP-iOS.xcarchive"
echo "==> Archiving (team $TEAM_ID)"
xc_archive "$SCHEME" 'generic/platform=iOS' "$ARCHIVE"
echo "==> Exporting ($METHOD)"
xc_export "$ARCHIVE" "$EXPORTS/ios" "$METHOD"
echo "Archive: $ARCHIVE"
echo "Export:  $EXPORTS/ios/"
