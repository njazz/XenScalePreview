#!/usr/bin/env bash
# Build, sign (Developer ID), notarize and staple XenScalePreview.app for distribution outside the App Store.
# Uses build_macos.sh for the build, so version/build come from version.env.
#
# One-time setup (stores credentials in your keychain; prompts for an app-specific password):
#   APPLE_ID=you@example.com TEAM_ID=ABCDE12345 ./notarize_macos.sh --setup
#
# Then, for each release:
#   SIGN_ID="Developer ID Application: Your Name (ABCDE12345)" ./notarize_macos.sh
#   UNIVERSAL=1 SIGN_ID="…" ./notarize_macos.sh        arm64 + x86_64 (needs full Xcode)
#
# Env:
#   SIGN_ID          Developer ID Application identity (required; ad-hoc "-" can't be notarized)
#   NOTARY_PROFILE   keychain profile name from --setup (default xenscale-notary)
#   BUNDLE_ID, VERSION, BUILD, UNIVERSAL   passed through to build_macos.sh
#
# Output: dist/XenScalePreview-notarized.zip  (stapled, so it also passes Gatekeeper offline)
set -euo pipefail

SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPTS_DIR/.." && pwd)"

source "$SCRIPTS_DIR/common.sh"

NOTARY_PROFILE="${NOTARY_PROFILE:-xenscale-notary}"
SIGN_ID="${SIGN_ID:-}"
OUT_ZIP="$DIST_DIR/$APP-notarized.zip"

require_macos
xcrun --find notarytool >/dev/null 2>&1 || die "notarytool not found. Install Xcode 13 or newer."

case "${1:-}" in
  "") ;;
  --setup)
    [[ -n "${APPLE_ID:-}" ]] || die "set APPLE_ID to your Apple ID email."
    require_team
    echo "==> Storing notarization credentials as keychain profile '$NOTARY_PROFILE'"
    echo "    Paste an app-specific password from appleid.apple.com when prompted."
    xcrun notarytool store-credentials "$NOTARY_PROFILE" --apple-id "$APPLE_ID" --team-id "$TEAM_ID"
    exit 0 ;;
  *) echo "usage: SIGN_ID=… ./notarize_macos.sh | APPLE_ID=… TEAM_ID=… ./notarize_macos.sh --setup" >&2; exit 2 ;;
esac

[[ "$SIGN_ID" == "Developer ID Application:"* ]] \
  || die "set SIGN_ID to your \"Developer ID Application: …\" identity (list: security find-identity -v -p codesigning)."
# xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  # || die "keychain profile '$NOTARY_PROFILE' not found or invalid. Run --setup first."

export SIGN_ID

$SCRIPTS_DIR/build_macos.sh   # hardened runtime + timestamp are enabled automatically for a real identity

ZIP="$DIST_DIR/$APP.zip"
echo "==> Submitting to Apple notary service (this can take a few minutes)"
LOG="$(mktemp)"; WORK="$(mktemp -d)"
trap 'rm -rf "$LOG" "$WORK"' EXIT
xcrun notarytool submit "$ZIP" --keychain-profile "Alex" --wait 2>&1 | tee "$LOG" || true # --keychain-profile "$NOTARY_PROFILE" 

if ! grep -q "status: Accepted" "$LOG"; then
  ID="$(awk '/^ *id:/ {print $2; exit}' "$LOG")"
  if [[ -n "$ID" ]]; then
    echo "==> Notarization failed; Apple's log:" >&2
    xcrun notarytool log "$ID" --keychain-profile "Alex" >&2 || true # --keychain-profile "$NOTARY_PROFILE"
  fi
  die "notarization was not accepted."
fi

echo "==> Stapling"
ditto -x -k "$ZIP" "$WORK"
xcrun stapler staple "$WORK/$APP.app"
xcrun stapler validate "$WORK/$APP.app"
spctl -a -vv -t exec "$WORK/$APP.app"

mkdir -p "$DIST_DIR"
rm -f "$OUT_ZIP"
ditto -c -k --sequesterRsrc --keepParent "$WORK/$APP.app" "$OUT_ZIP"
echo "Notarized and stapled: $OUT_ZIP  ($APP.app $VERSION build $BUILD)"
