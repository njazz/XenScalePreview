#!/usr/bin/env bash
# Generate XenScalePreview.xcodeproj (iOS + macOS targets) from project.yml with XcodeGen.
#   brew install xcodegen
#   ./gen_project.sh --open          generate and open it in Xcode
# Env: BUNDLE_ID (default local.xen-scale-preview), VERSION (1.0), BUILD (1), TEAM_ID (your Apple team, for signing)
# The project is generated, so edit project.yml, not the project: changes made in Xcode are lost on regeneration.
set -euo pipefail
cd "$(dirname "$0")"
export BUNDLE_ID="${BUNDLE_ID:-local.xen-scale-preview}" VERSION="${VERSION:-1.0}" BUILD="${BUILD:-1}" TEAM_ID="${TEAM_ID:-}"
command -v xcodegen >/dev/null || { echo "XcodeGen not found. Install it with: brew install xcodegen" >&2; exit 1; }
mkdir -p build
xcodegen generate --spec project.yml --quiet
echo "XenScalePreview.xcodeproj  ($BUNDLE_ID, $VERSION build $BUILD)"
if [[ "${1:-}" == "--open" ]]; then open XenScalePreview.xcodeproj; fi
