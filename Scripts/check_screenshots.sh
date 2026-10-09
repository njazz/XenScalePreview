#!/usr/bin/env bash
# Preflight for `fastlane screenshots`: finds the usual causes of a failing run without running the UI tests.
#
#   Scripts/check_screenshots.sh            static checks (tools, project, scheme, Snapfile devices, UI test files)
#   Scripts/check_screenshots.sh --build    ... plus build-for-testing the UI-test scheme on the first Snapfile device,
#                                           which shows the real compiler / signing error behind a fastlane exit status
#   Scripts/check_screenshots.sh --boot     ... plus boot every Snapfile device once and wait for it to be ready
#
# Exit status 0 = nothing wrong found, 1 = at least one problem. See docs/SCREENSHOTS.md.
set -uo pipefail
source "$(dirname "$0")/common.sh"

BUILD_TEST=0; BOOT=0
for a in "$@"; do
  case "$a" in
    --build) BUILD_TEST=1 ;;
    --boot)  BOOT=1 ;;
    -h|--help) sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "usage: Scripts/check_screenshots.sh [--build] [--boot]" >&2; exit 2 ;;
  esac
done

FAILS=0
ok()   { printf '  \033[32mok\033[0m    %s\n' "$*"; }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; FAILS=$((FAILS+1)); }
note() { printf '  \033[33mwarn\033[0m  %s\n' "$*"; }
hdr()  { printf '\n\033[1m%s\033[0m\n' "$*"; }

SCHEME="${APP}UITests"
SNAPFILE="$ROOT/fastlane/Snapfile"
LOGS="$BUILD_DIR/snapshot-logs"

hdr "Tools"
[[ "$(uname)" == Darwin ]] && ok "macOS" || bad "not macOS: screenshots need Xcode and the iOS Simulator"
if command -v xcodebuild >/dev/null; then ok "$(xcodebuild -version 2>/dev/null | tr '\n' ' ')"; else bad "xcodebuild not found"; fi
xcode-select -p 2>/dev/null | grep -q "Xcode.*\.app" && ok "xcode-select -> $(xcode-select -p)" \
  || bad "xcode-select points at '$(xcode-select -p 2>/dev/null)', not a full Xcode: sudo xcode-select -s /Applications/Xcode.app"
command -v xcodegen >/dev/null && ok "xcodegen $(xcodegen --version 2>/dev/null | tail -1)" || bad "xcodegen missing: brew install xcodegen"
command -v fastlane >/dev/null && ok "fastlane $(fastlane --version 2>/dev/null | tail -1)" || bad "fastlane missing: brew install fastlane"
xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1 && ok "Xcode first-launch tasks done" \
  || note "Xcode first-launch tasks pending (or Xcode too old for this check): sudo xcodebuild -runFirstLaunch; sudo xcodebuild -license accept"

hdr "Project"
if grep -q 'type: bundle.ui-testing' project.yml 2>/dev/null; then ok "project.yml defines the UI-test target"; else bad "project.yml has no 'type: bundle.ui-testing' target (see docs/SCREENSHOTS.md)"; fi
if grep -q "^  $SCHEME:" project.yml 2>/dev/null; then ok "project.yml defines scheme $SCHEME"; else bad "project.yml has no scheme '$SCHEME'"; fi
if [[ -d "$PROJ" ]]; then
  if xcodebuild -list -project "$PROJ" 2>/dev/null | grep -qx "[[:space:]]*$SCHEME"; then ok "$PROJ lists scheme $SCHEME"
  else bad "$PROJ has no scheme '$SCHEME': regenerate with Scripts/gen_project.sh"; fi
else
  bad "$PROJ not found: run Scripts/gen_project.sh (it is generated, and Scripts/clean.sh deletes it)"
fi
ls UITests/*UITests.swift >/dev/null 2>&1 && ok "UI test: $(ls UITests/*UITests.swift | tr '\n' ' ')" || bad "no UITests/*UITests.swift"
if [[ -f UITests/SnapshotHelper.swift ]]; then
  ok "SnapshotHelper.swift $(grep -o 'SnapshotHelperVersion \[[0-9.]*\]' UITests/SnapshotHelper.swift)"
else
  bad "UITests/SnapshotHelper.swift missing: run Scripts/setup_screenshots.sh"
fi
grep -q 'SCREENSHOT_MODE' iOS/App.swift 2>/dev/null && ok "iOS/App.swift handles -SCREENSHOT_MODE" || note "iOS/App.swift ignores -SCREENSHOT_MODE: the app will show its empty start screen"

hdr "Snapfile devices vs installed Simulators"
DEVICES=()
if [[ -f "$SNAPFILE" ]]; then
  # every quoted string between "devices([" and "])" that is not commented out
  while IFS= read -r line; do DEVICES+=("$line"); done < <(
    awk '/^devices\(\[/{on=1;next} on&&/^\]\)/{on=0} on&&!/^[[:space:]]*#/{ if (match($0,/"[^"]+"/)) print substr($0,RSTART+1,RLENGTH-2) }' "$SNAPFILE")
  AVAIL="$(xcrun simctl list devices available 2>/dev/null | sed -E 's/^ +//; s/ \([0-9A-Fa-f-]{36}\).*$//')"
  if [[ ${#DEVICES[@]} -eq 0 ]]; then bad "no devices found in fastlane/Snapfile"; fi
  for d in "${DEVICES[@]+"${DEVICES[@]}"}"; do
    if printf '%s\n' "$AVAIL" | grep -qxF "$d"; then ok "$d"
    else
      bad "'$d' is not an installed Simulator. Installed iPhone/iPad Pro models:"
      printf '%s\n' "$AVAIL" | grep -E '^(iPhone .*Pro Max|iPad Pro 1[13])' | sort -u | sed 's/^/          /'
      echo "          Fix the name in fastlane/Snapfile, or install the runtime: Xcode > Settings > Components."
    fi
  done
else
  bad "fastlane/Snapfile missing"
fi

if [[ $BOOT -eq 1 ]]; then
  hdr "Booting Simulators (--boot)"
  for d in "${DEVICES[@]+"${DEVICES[@]}"}"; do
    udid="$(xcrun simctl list devices available | grep -F "    $d (" | head -1 | grep -oE '[0-9A-Fa-f-]{36}' | head -1)"
    [[ -n "$udid" ]] || { bad "$d: no UDID"; continue; }
    xcrun simctl boot "$udid" 2>/dev/null || true
    if xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1; then ok "$d booted"; else bad "$d did not boot (try: xcrun simctl shutdown all; xcrun simctl erase $udid)"; fi
  done
fi

if [[ $BUILD_TEST -eq 1 ]]; then
  hdr "build-for-testing (--build)"
  if [[ ! -d "$PROJ" || ${#DEVICES[@]} -eq 0 ]]; then bad "needs the project and at least one Snapfile device"
  else
    mkdir -p "$LOGS"
    LOG="$LOGS/check-build.log"
    echo "  building scheme $SCHEME for '${DEVICES[0]}' (log: $LOG) ..."
    if xcodebuild build-for-testing -project "$PROJ" -scheme "$SCHEME" \
         -destination "platform=iOS Simulator,name=${DEVICES[0]}" -derivedDataPath "$DERIVED" \
         CODE_SIGNING_ALLOWED=NO >"$LOG" 2>&1; then
      ok "build-for-testing succeeded"
    else
      bad "build-for-testing failed. The errors:"
      grep -E "error:|Unable to find a destination|requires a development team|No such module" "$LOG" | sort -u | head -15 | sed 's/^/          /'
    fi
  fi
fi

echo
if [[ $FAILS -eq 0 ]]; then echo "No problems found. Run: fastlane screenshots   (logs: $LOGS/)"; exit 0
else echo "$FAILS problem(s) found."; exit 1; fi
