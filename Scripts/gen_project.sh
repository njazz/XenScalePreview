#!/usr/bin/env bash
# Generate XenScalePreview.xcodeproj (iOS + macOS targets) from project.yml with XcodeGen.
#   brew install xcodegen
#   Scripts/gen_project.sh --open    generate and open it in Xcode (works from any directory)
# Version/build: version.env. Env: BUNDLE_ID, TEAM_ID (for signing), VERSION, BUILD override.
# The project is generated, so edit project.yml, not the project: changes made in Xcode are lost on regeneration.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"   # sets ROOT, cd-s into it, loads version.env

command -v xcodegen >/dev/null || die "XcodeGen not found. Install it with: brew install xcodegen"
mkdir -p "$BUILD_DIR"
xcodegen generate --spec "$ROOT/project.yml" --quiet
echo "$PROJ  ($BUNDLE_ID, $VERSION build $BUILD)"
if [[ "${1:-}" == "--open" ]]; then open "$PROJ"; fi
