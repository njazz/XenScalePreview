#!/usr/bin/env bash
# Remove generated build output.
#
#   Scripts/clean.sh           build/ (DerivedData, archives, exports), .build/ (SwiftPM) and the generated .xcodeproj
#   Scripts/clean.sh --dist          ... plus dist/ (release zips)
#   Scripts/clean.sh --xcode-cache   ... plus any XenScalePreview-* folders in Xcode's default DerivedData
#                              (left over from builds made before output moved into build/)
#   Scripts/clean.sh --all           everything above
#
# Never touches sources, version.env, or the installed app (use Scripts/install_mac.sh --uninstall for that).
set -euo pipefail
source "$(dirname "$0")/common.sh"

DIST=0; CACHE=0
for a in "$@"; do
  case "$a" in
    --dist) DIST=1 ;;
    --xcode-cache) CACHE=1 ;;
    --all) DIST=1; CACHE=1 ;;
    *) echo "usage: Scripts/clean.sh [--dist] [--xcode-cache] [--all]" >&2; exit 2 ;;
  esac
done

remove() { if [[ -e "$1" ]]; then rm -rf "$1"; echo "removed $1"; fi; }

remove "$BUILD_DIR"
remove .build
remove "$PROJ"
(( DIST )) && remove "$DIST_DIR"
if (( CACHE )); then
  for d in "$HOME/Library/Developer/Xcode/DerivedData/$APP-"*; do remove "$d"; done
fi
echo "Clean."
