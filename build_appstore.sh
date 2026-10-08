#!/usr/bin/env bash
# Build signed App Store archives for iOS / iPadOS and macOS, and export them for App Store Connect.
# One bundle ID for both platforms gives a universal purchase: one listing, one price, one purchase.
#
#   TEAM_ID=ABCDE12345 BUNDLE_ID=com.example.xenscalepreview ./build_appstore.sh ios
#   TEAM_ID=… BUNDLE_ID=… ./build_appstore.sh macos
#   TEAM_ID=… BUNDLE_ID=… VERSION=1.0 BUILD=3 ./build_appstore.sh all --upload
#
# Output (without --upload):
#   dist/appstore/XenScalePreview-iOS.xcarchive    dist/appstore/ios/XenScalePreview.ipa
#   dist/appstore/XenScalePreview-macOS.xcarchive  dist/appstore/macos/XenScalePreview.pkg
# Upload the .ipa / .pkg with Transporter or Xcode's Organizer, or pass --upload to send them to App Store
# Connect straight from xcodebuild (needs to be signed in to Xcode with that team).
#
# Env:
#   TEAM_ID     Apple Developer team ID (required)
#   BUNDLE_ID   your own reverse-domain ID, e.g. com.example.xenscalepreview (required; "local.*" is refused).
#               It must match the App ID you create in App Store Connect; the extension becomes "<id>.quicklook".
#   VERSION     marketing version (default 1.0)
#   BUILD       build number; must increase with every upload of the same VERSION (default 1)
set -euo pipefail
cd "$(dirname "$0")"

usage() { echo "usage: TEAM_ID=… BUNDLE_ID=… ./build_appstore.sh ios|macos|all [--upload]" >&2; exit 2; }
die() { echo "error: $*" >&2; exit 1; }

WHAT="${1:-}"; shift || true
UPLOAD=0
for a in "$@"; do [[ "$a" == --upload ]] && UPLOAD=1 || usage; done
case "$WHAT" in ios|macos|all) ;; *) usage ;; esac

[[ "$(uname)" == Darwin ]] || die "this script runs on macOS only."
command -v xcodebuild >/dev/null || die "xcodebuild not found. Install Xcode."
TEAM_ID="${TEAM_ID:-}"; BUNDLE_ID="${BUNDLE_ID:-}"; VERSION="${VERSION:-1.0}"; BUILD="${BUILD:-1}"
[[ -n "$TEAM_ID" ]] || die "set TEAM_ID to your Apple Developer team ID."
[[ -n "$BUNDLE_ID" && "$BUNDLE_ID" != local.* ]] || die "set BUNDLE_ID to your own reverse-domain ID, e.g. com.example.xenscalepreview."
[[ "$BUILD" =~ ^[0-9]+(\.[0-9]+)*$ ]] || die "BUILD must be a number like 3 or 3.1."
export TEAM_ID BUNDLE_ID VERSION BUILD

echo "==> Generating Xcode project ($BUNDLE_ID, $VERSION build $BUILD)"
./gen_project.sh >/dev/null
mkdir -p dist/appstore

DEST=export; [[ "$UPLOAD" == 1 ]] && DEST=upload

archive_and_export() {  # $1 = ios|macos, $2 = scheme, $3 = xcodebuild destination, $4 = label
  local archive="dist/appstore/XenScalePreview-$4.xcarchive" out="dist/appstore/$1" opts="build/ExportOptions-appstore-$1.plist"
  echo "==> Archiving $4"
  rm -rf "$archive" "$out"
  xcodebuild -project XenScalePreview.xcodeproj -scheme "$2" -configuration Release \
    -destination "$3" -archivePath "$archive" \
    -allowProvisioningUpdates DEVELOPMENT_TEAM="$TEAM_ID" archive -quiet
  cat > "$opts" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>destination</key><string>$DEST</string>
  <key>teamID</key><string>$TEAM_ID</string>
  <key>signingStyle</key><string>automatic</string>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST
  local verb="Exporting"; [[ "$DEST" == upload ]] && verb="Uploading"
  echo "==> $verb $4 for App Store Connect"
  xcodebuild -exportArchive -archivePath "$archive" -exportPath "$out" \
    -exportOptionsPlist "$opts" -allowProvisioningUpdates
  echo "    archive: $archive"
  [[ "$DEST" == export ]] && echo "    export:  $out/"
  return 0
}

if [[ "$WHAT" == ios   || "$WHAT" == all ]]; then archive_and_export ios   XenScalePreview-iOS   'generic/platform=iOS'   iOS;   fi
if [[ "$WHAT" == macos || "$WHAT" == all ]]; then archive_and_export macos XenScalePreview-macOS 'generic/platform=macOS' macOS; fi
echo "Done."
