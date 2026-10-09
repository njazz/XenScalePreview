#!/usr/bin/env bash
# Build signed App Store archives for iOS / iPadOS and macOS, and export them for App Store Connect.
# One bundle ID for both platforms gives a universal purchase: one listing, one price, one purchase.
#
#   TEAM_ID=ABCDE12345 BUNDLE_ID=com.example.xenscalepreview Scripts/build_appstore.sh ios
#   TEAM_ID=… BUNDLE_ID=… Scripts/build_appstore.sh macos
#   TEAM_ID=… BUNDLE_ID=… Scripts/build_appstore.sh all --upload
#
# Version/build: version.env (BUILD must increase with every upload of the same VERSION).
#
# Output (without --upload):
#   build/archives/XenScalePreview-iOS.xcarchive    build/export/appstore-ios/XenScalePreview.ipa
#   build/archives/XenScalePreview-macOS.xcarchive  build/export/appstore-macos/XenScalePreview.pkg
# Upload the .ipa / .pkg with Transporter or Xcode's Organizer, or pass --upload to send them to App Store
# Connect straight from xcodebuild (needs to be signed in to Xcode with that team).
#
# Env:
#   TEAM_ID     Apple Developer team ID (required)
#   BUNDLE_ID   your own reverse-domain ID, e.g. com.example.xenscalepreview (required; "local.*" is refused).
#               It must match the App ID you create in App Store Connect; the extension becomes "<id>.quicklook".
#   VERSION, BUILD   override version.env for one run
set -euo pipefail
source "$(dirname "$0")/common.sh"

usage() { echo "usage: TEAM_ID=… BUNDLE_ID=… Scripts/build_appstore.sh ios|macos|all [--upload]" >&2; exit 2; }

WHAT="${1:-}"; shift || true
UPLOAD=0
for a in "$@"; do [[ "$a" == --upload ]] && UPLOAD=1 || usage; done
case "$WHAT" in ios|macos|all) ;; *) usage ;; esac

require_macos; require_xcode; require_team
[[ "$BUNDLE_ID" != local.* ]] || die "set BUNDLE_ID to your own reverse-domain ID, e.g. com.example.xenscalepreview."
[[ "$BUILD" =~ ^[0-9]+(\.[0-9]+)*$ ]] || die "BUILD must be a number like 3 or 3.1."

echo "==> Generating Xcode project ($BUNDLE_ID, $VERSION build $BUILD)"
"$SCRIPTS_DIR/gen_project.sh" >/dev/null

DEST=export; [[ "$UPLOAD" == 1 ]] && DEST=upload

archive_and_export() {  # $1 = ios|macos, $2 = scheme, $3 = xcodebuild destination, $4 = label
  local archive="$ARCHIVES/$APP-$4.xcarchive" out="$EXPORTS/appstore-$1"
  echo "==> Archiving $4"
  xc_archive "$2" "$3" "$archive"
  local verb="Exporting"; [[ "$DEST" == upload ]] && verb="Uploading"
  echo "==> $verb $4 for App Store Connect"
  xc_export "$archive" "$out" app-store-connect "$DEST"
  echo "    archive: $archive"
  [[ "$DEST" == export ]] && echo "    export:  $out/"
  return 0
}

if [[ "$WHAT" == ios   || "$WHAT" == all ]]; then archive_and_export ios   "$APP-iOS"   'generic/platform=iOS'   iOS;   fi
if [[ "$WHAT" == macos || "$WHAT" == all ]]; then archive_and_export macos "$APP-macOS" 'generic/platform=macOS' macOS; fi
echo "Done."
