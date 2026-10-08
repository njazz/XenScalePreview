#!/usr/bin/env bash
# Build XenScalePreview.app (via build_macos.sh), install it and register its Quick Look extension.
#
#   ./install_mac.sh               build + install to ~/Applications
#   ./install_mac.sh --uninstall   remove it
#
# Env overrides:
#   DEST=/Applications             install location (default ~/Applications)
#   SIGN_ID, BUNDLE_ID, VERSION, UNIVERSAL are passed through to build_macos.sh
set -euo pipefail
cd "$(dirname "$0")"

APP=XenScalePreview
EXT=XenScalePreviewExtension
BUNDLE_ID="${BUNDLE_ID:-local.xen-scale-preview}"
EXT_ID="$BUNDLE_ID.quicklook"
DEST="${DEST:-$HOME/Applications}"
INSTALLED="$DEST/$APP.app"
LSREGISTER=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister

[[ "$(uname)" == Darwin ]] || { echo "This script runs on macOS only." >&2; exit 1; }

refresh_quicklook() {
  qlmanage -r >/dev/null 2>&1 || true
  qlmanage -r cache >/dev/null 2>&1 || true
  pkill -x "$EXT" 2>/dev/null || true
}

if [[ "${1:-}" == "--uninstall" ]]; then
  pluginkit -r "$INSTALLED/Contents/PlugIns/$EXT.appex" 2>/dev/null || true
  "$LSREGISTER" -u "$INSTALLED" 2>/dev/null || true
  rm -rf "$INSTALLED"
  refresh_quicklook
  echo "Removed $INSTALLED"
  exit 0
fi

./build_macos.sh

echo "==> Installing to $INSTALLED"
mkdir -p "$DEST"
if [[ -d "$INSTALLED" ]]; then
  pluginkit -r "$INSTALLED/Contents/PlugIns/$EXT.appex" 2>/dev/null || true
fi
rm -rf "$INSTALLED"
ditto -x -k "dist/$APP.zip" "$DEST"

echo "==> Registering"
"$LSREGISTER" -f -R -trusted "$INSTALLED"
pluginkit -a "$INSTALLED/Contents/PlugIns/$EXT.appex"
pluginkit -e use -i "$EXT_ID"
refresh_quicklook

if pluginkit -m -i "$EXT_ID" | grep -q "$EXT_ID"; then
  echo "Done. Try:  qlmanage -p Examples/ji-5-limit.scl   (or press Space in Finder)"
else
  echo "Installed, but pluginkit doesn't list $EXT_ID yet." >&2
  echo "Open $INSTALLED once, or re-run with SIGN_ID set to your Apple Development identity." >&2
  exit 1
fi
