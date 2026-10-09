#!/usr/bin/env bash
#
# setup_screenshots.sh — bootstrap automated App Store screenshots (fastlane snapshot)
# for a JUCE iOS app.
#
# Copy this file to  FooApp/Scripts/  and run it from anywhere:
#     bash FooApp/Scripts/setup_screenshots.sh
#
# What it does (idempotent, safe to re-run):
#   1. Installs fastlane if missing (Homebrew, else gem)
#   2. Scans the .xcodeproj files (Projucer / CMake) and picks the one with an iOS app target
#   3. Creates  UITests/  with SnapshotHelper.swift + a UI test stub
#   4. Adds a UI-test target + shared scheme to the Xcode project (via fastlane's bundled xcodeproj)
#   5. Creates fastlane/Fastfile + fastlane/Snapfile (only if they don't exist)
#
# NOTE: Projucer / CMake REGENERATE the Xcode project and wipe the UI-test target.
#       Just re-run this script after regenerating.
#
# XcodeGen projects (a project.yml that declares a "type: bundle.ui-testing" target, like this repo): the UI-test
# target and its scheme live in project.yml, so nothing is patched into the .xcodeproj. The script then only
# (re)generates the project via Scripts/gen_project.sh, installs fastlane and writes SnapshotHelper / Fastfile / Snapfile.
#
# Options:
#   --name NAME        App name (default: folder name of the app root)
#   --project PATH     Path to the iOS .xcodeproj (default: auto-detect)
#   --app-target NAME  App target inside the project (default: first iOS app target)
#   --force            Overwrite existing Fastfile/Snapfile/stub/SnapshotHelper
#   --no-wire          Skip modifying the Xcode project
#   --list             Show every .xcodeproj found and its targets, then exit
#   -h, --help         Show this help

set -euo pipefail

# ---------------------------------------------------------------- helpers
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33mwarn:\033[0m %s\n' "$*" >&2; }
die()  { printf '\033[1;31merror:\033[0m %s\n' "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

NAME="$(basename "$ROOT")"
PROJECT=""
APP_TARGET=""
FORCE=0
WIRE=1
LIST_ONLY=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --name)       NAME="$2"; shift 2 ;;
    --project)    PROJECT="$2"; shift 2 ;;
    --app-target) APP_TARGET="$2"; shift 2 ;;
    --force)      FORCE=1; shift ;;
    --no-wire)    WIRE=0; shift ;;
    --list)       LIST_ONLY=1; shift ;;
    -h|--help)    sed -n '2,/^$/p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) die "Unknown option: $1" ;;
  esac
done

SAFE_NAME="$(printf '%s' "$NAME" | tr -c 'A-Za-z0-9' '_')"
TEST_NAME="${SAFE_NAME}UITests"
TESTS_DIR="$ROOT/UITests"
FASTLANE_DIR="$ROOT/fastlane"

# XcodeGen mode: project.yml already declares the UI-test target, so use its name and don't patch the .xcodeproj.
XCODEGEN=0
if [[ -f "$ROOT/project.yml" ]]; then
  _xg_target="$(awk '/^  [A-Za-z0-9_.-]+:[[:space:]]*$/ { n=$1; sub(/:$/, "", n) } /type:[[:space:]]*bundle\.ui-testing/ { print n; exit }' "$ROOT/project.yml")"
  if [[ -n "$_xg_target" ]]; then XCODEGEN=1; TEST_NAME="$_xg_target"; WIRE=0; fi
  unset _xg_target
fi

# write_file DEST  (content on stdin) — skips existing files unless --force
write_file() {
  local dest="$1"
  if [[ -e "$dest" && $FORCE -eq 0 ]]; then
    log "keep   ${dest#$ROOT/} (exists; use --force to overwrite)"
    cat >/dev/null
    return 0
  fi
  mkdir -p "$(dirname "$dest")"
  cat > "$dest"
  log "wrote  ${dest#$ROOT/}"
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

# Run a Ruby file inside fastlane's own runtime. fastlane bundles xcodeproj, so we never
# have to build native gems against the old macOS system Ruby.
fl_ruby() {
  local rb="$1" d rc=0
  d="$(mktemp -d)"
  mkdir -p "$d/fastlane"
  printf 'lane :scriptrun do\n  load %s\nend\n' "\"$rb\"" > "$d/fastlane/Fastfile"
  ( cd "$d" && FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_OPT_OUT_USAGE=1 fastlane scriptrun ) || rc=$?
  rm -rf "$d"
  return $rc
}

# inspect_projects "<newline-separated .xcodeproj paths>"  ->  $WORK/targets.tsv
# columns: project, target, product type, SDKROOT, SUPPORTED_PLATFORMS
inspect_projects() {
  cat > "$WORK/inspect.rb" <<'RUBY'
require 'xcodeproj'
out = File.open(ENV.fetch('INSPECT_OUT'), 'w')
ENV.fetch('INSPECT_PROJECTS').split("\n").reject { |l| l.strip.empty? }.each do |path|
  begin
    proj = Xcodeproj::Project.open(path)
    proj_sdk = proj.build_configurations.first.build_settings['SDKROOT'].to_s
    proj.native_targets.each do |t|
      bs = t.build_configurations.first.build_settings
      out.puts [path, t.name, t.product_type.to_s, (bs['SDKROOT'] || proj_sdk).to_s, bs['SUPPORTED_PLATFORMS'].to_s].join("\t")
    end
  rescue => e
    out.puts [path, '(unreadable)', e.message.to_s.gsub(/\s+/, ' '), '', ''].join("\t")
  end
end
out.close
RUBY
  : > "$WORK/targets.tsv"
  if ! ( export INSPECT_PROJECTS="$1" INSPECT_OUT="$WORK/targets.tsv"; fl_ruby "$WORK/inspect.rb" ) >"$WORK/inspect.log" 2>&1; then
    cat "$WORK/inspect.log" >&2
    die "Could not inspect the Xcode projects with fastlane's Ruby."
  fi
}

print_targets() {
  awk -F'\t' '{ t=$3; sub(/^com\.apple\.product-type\./, "", t); printf "  %-28s %-30s %s\n", $2, t, $1 }' "$WORK/targets.tsv" \
    | sed "s#$ROOT/##"
}

# ---------------------------------------------------------------- 0. prerequisites
[[ "$(uname)" == "Darwin" ]] || die "This script must run on macOS (needs Xcode + iOS Simulator)."
command -v xcodebuild >/dev/null || die "Xcode not found. Install Xcode and run: sudo xcode-select -s /Applications/Xcode.app"
xcode-select -p >/dev/null 2>&1 || die "Xcode command line tools not selected: xcode-select --install"

# ---------------------------------------------------------------- 1. fastlane
if command -v fastlane >/dev/null 2>&1; then
  log "fastlane already installed ($(fastlane --version 2>/dev/null | tail -1))"
else
  if command -v brew >/dev/null 2>&1; then
    log "Installing fastlane via Homebrew…"
    brew install fastlane
  else
    log "Homebrew not found — installing fastlane via gem (user install)…"
    gem install fastlane --no-document --user-install
    USER_GEM_BIN="$(ruby -r rubygems -e 'puts Gem.user_dir')/bin"
    export PATH="$USER_GEM_BIN:$PATH"
    warn "Add this to your shell profile: export PATH=\"$USER_GEM_BIN:\$PATH\""
  fi
  command -v fastlane >/dev/null 2>&1 || die "fastlane install failed."
fi

# ---------------------------------------------------------------- 1b. XcodeGen: (re)generate the project
if [[ $XCODEGEN -eq 1 && $LIST_ONLY -eq 0 ]]; then
  command -v xcodegen >/dev/null 2>&1 || die "XcodeGen not found. Install it with: brew install xcodegen"
  log "XcodeGen project: generating with Scripts/gen_project.sh (UI-test target '$TEST_NAME' comes from project.yml)"
  "$SCRIPT_DIR/gen_project.sh" >/dev/null || die "Scripts/gen_project.sh failed; run it directly to see why."
fi

# ---------------------------------------------------------------- 2. locate Xcode project
list_candidates() {
  local all
  all="$(find "$ROOT" -maxdepth 6 -name '*.xcodeproj' \
    -not -path '*/JUCE/*' -not -path '*/Pods/*' -not -path '*/node_modules/*' \
    -not -path '*/.git/*' 2>/dev/null || true)"
  { printf '%s\n' "$all" | grep -i '/iOS/' || true
    printf '%s\n' "$all" | grep -vi '/iOS/' | grep -v '^$' || true; }
}

if [[ $LIST_ONLY -eq 1 ]]; then
  CANDS="${PROJECT:-$(list_candidates)}"
  [[ -n "$CANDS" ]] || die "No .xcodeproj found under $ROOT."
  inspect_projects "$CANDS"
  printf '\n  %-28s %-30s %s\n' TARGET TYPE PROJECT
  print_targets
  exit 0
fi

if [[ $WIRE -eq 1 || -z "$PROJECT" ]]; then
  if [[ -z "$PROJECT" ]]; then
    CANDIDATES="$(list_candidates)"
    [[ -n "$CANDIDATES" ]] || die "No .xcodeproj found under $ROOT. Generate it with Projucer (iOS exporter) or CMake (-G Xcode) first, or pass --project PATH."
    log "Scanning $(printf '%s\n' "$CANDIDATES" | grep -c .) Xcode project(s) for an iOS app target…"
    inspect_projects "$CANDIDATES"
    PROJECT="$(awk -F'\t' '$3=="com.apple.product-type.application" && ($4 ~ /iphoneos/ || $5 ~ /iphoneos/) { print $1; exit }' "$WORK/targets.tsv")"
    [[ -n "$PROJECT" ]] || PROJECT="$(awk -F'\t' '$3=="com.apple.product-type.application" && tolower($1) ~ /\/ios\// { print $1; exit }' "$WORK/targets.tsv")"
    if [[ -z "$PROJECT" ]]; then
      warn "No Xcode project contains an iOS application target. Found:"
      printf '  %-28s %-30s %s\n' TARGET TYPE PROJECT >&2
      print_targets >&2
      die "Nothing to attach UI tests to. Make sure the project has an iOS exporter with an app target (Projucer: add an iOS exporter; CMake: -G Xcode -DCMAKE_SYSTEM_NAME=iOS), regenerate, and re-run. Use --list to inspect, or --project / --app-target to choose manually."
    fi
  fi
  PROJECT="$(cd "$(dirname "$PROJECT")" && pwd)/$(basename "$PROJECT")"
  [[ -d "$PROJECT" ]] || die "Project not found: $PROJECT"
  log "Xcode project: ${PROJECT#$ROOT/}"
fi

# ---------------------------------------------------------------- 3. SnapshotHelper.swift
mkdir -p "$TESTS_DIR"
HELPER="$TESTS_DIR/SnapshotHelper.swift"
if [[ -e "$HELPER" && $FORCE -eq 0 ]]; then
  log "keep   UITests/SnapshotHelper.swift"
else
  TMP="$WORK/snapinit"
  mkdir -p "$TMP"
  FOUND=""
  # Preferred: let the installed fastlane generate the matching helper version
  ( cd "$TMP" && fastlane snapshot init </dev/null >/dev/null 2>&1 ) || true
  FOUND="$(find "$TMP" -name SnapshotHelper.swift 2>/dev/null | sed -n '1p' || true)"
  if [[ -n "$FOUND" ]]; then
    cp "$FOUND" "$HELPER"
  else
    log "fastlane snapshot init gave no helper — downloading from GitHub…"
    curl -fsSL "https://raw.githubusercontent.com/fastlane/fastlane/master/snapshot/lib/assets/SnapshotHelper.swift" -o "$HELPER" \
      || die "Could not obtain SnapshotHelper.swift"
  fi
  log "wrote  UITests/SnapshotHelper.swift"
fi

# ---------------------------------------------------------------- 4. UI test stub
write_file "$TESTS_DIR/${TEST_NAME}.swift" <<SWIFT
import XCTest

/// UI test that drives ${NAME} and captures App Store screenshots via fastlane snapshot.
///
/// JUCE draws its own UI, so XCUITest usually can't "see" individual widgets unless the
/// components expose accessibility info (JUCE 6.1+: setTitle / setDescription / setHelpText
/// / setAccessible on Components). Until then, navigate by normalized screen coordinates.
final class ${TEST_NAME}: XCTestCase {

    // setupSnapshot()/snapshot() are @MainActor; XCTestCase methods are not isolated. XCTest runs them on the
    // main thread, so MainActor.assumeIsolated bridges the two (iOS 17+; on older targets mark the class @MainActor).
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false

        MainActor.assumeIsolated {
            app = XCUIApplication()
            setupSnapshot(app)                                  // fastlane hook (language, locale, status bar)
            app.launchArguments += ["-SCREENSHOT_MODE", "YES"]  // read it in your app to load demo data
            app.launch()
            waitForUI(3)                                        // let JUCE finish first paint
        }
    }

    func testTakeScreenshots() throws {
        MainActor.assumeIsolated {
            snapshot("01_Main")

            // Example: tap at 50% width / 85% height, wait, capture.
            // tap(0.5, 0.85)
            // snapshot("02_Settings")

            // Example: if you've set accessibility titles on JUCE components:
            // app.buttons["Presets"].tap()
            // snapshot("03_Presets")
        }
    }

    // MARK: - Helpers

    /// Tap at a normalized position (0...1) — works with fully custom-drawn UIs.
    @MainActor func tap(_ x: CGFloat, _ y: CGFloat) {
        app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
        waitForUI(1)
    }

    /// Drag between two normalized positions (knobs, sliders, scrolling).
    @MainActor func drag(from a: CGPoint, to b: CGPoint, hold: TimeInterval = 0.1) {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: a.x, dy: a.y))
        let end   = app.coordinate(withNormalizedOffset: CGVector(dx: b.x, dy: b.y))
        start.press(forDuration: hold, thenDragTo: end)
        waitForUI(1)
    }

    func waitForUI(_ seconds: TimeInterval = 1) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
SWIFT

# ---------------------------------------------------------------- 5. wire into Xcode project
if [[ $WIRE -eq 1 ]]; then
  log "Adding UI test target '$TEST_NAME' to ${PROJECT#$ROOT/}…"
  # The Ruby runs inside fastlane's own runtime, which already bundles the xcodeproj gem.
  # This avoids building native gems against the (old) macOS system Ruby.
  WIRE_TMP="$(mktemp -d)"
  mkdir -p "$WIRE_TMP/fastlane"

  cat > "$WIRE_TMP/wire.rb" <<'RUBY'
require 'xcodeproj'
require 'pathname'

ui = FastlaneCore::UI
proj_path = ENV.fetch('WIRE_PROJECT')
test_name = ENV.fetch('WIRE_TEST_NAME')
app_name  = ENV['WIRE_APP_TARGET'].to_s
tests_dir = ENV.fetch('WIRE_TESTS_DIR')

project = Xcodeproj::Project.open(proj_path)

apps = project.native_targets.select { |t| t.product_type == 'com.apple.product-type.application' }
proj_sdk = project.build_configurations.first.build_settings['SDKROOT'].to_s
sdk_of = lambda { |t| (t.build_configurations.first.build_settings['SDKROOT'] || proj_sdk).to_s }
app = if !app_name.empty?
        apps.find { |t| t.name == app_name } ||
          ui.user_error!("App target '#{app_name}' not found. Apps: #{apps.map(&:name).join(', ')}")
      else
        apps.find { |t| sdk_of.call(t).include?('iphoneos') } || apps.first
      end
unless app
  found = project.native_targets.map { |t| "#{t.name} (#{t.product_type.to_s.sub('com.apple.product-type.', '')})" }.join(', ')
  ui.user_error!("No application target in #{File.basename(proj_path)}. Targets found: #{found}. Run the script with --list to inspect every project, or pass --project.")
end
ui.important("Host app '#{app.name}' does not look like an iOS target (SDKROOT=#{sdk_of.call(app)})") unless sdk_of.call(app).include?('iphoneos')
puts "    host app target: #{app.name}"

if project.targets.any? { |t| t.name == test_name }
  puts "    target '#{test_name}' already exists - leaving it as is"
else
  base = app.build_configurations.first.build_settings
  bundle_id = base['PRODUCT_BUNDLE_IDENTIFIER'].to_s
  bundle_id = 'com.example.app' if bundle_id.empty?
  deploy = base['IPHONEOS_DEPLOYMENT_TARGET'].to_s
  deploy = '15.0' if deploy.empty? || deploy.include?('$')

  test = project.new_target(:ui_test_bundle, test_name, :ios, deploy, nil, :swift)

  rel = Pathname.new(File.realpath(tests_dir)).relative_path_from(Pathname.new(File.realpath(File.dirname(proj_path))))
  group = project.main_group.new_group(test_name, rel.to_s)
  refs = Dir[File.join(tests_dir, '*.swift')].sort.map { |f| group.new_file(File.basename(f)) }
  test.add_file_references(refs)

  test.build_configurations.each do |c|
    s = c.build_settings
    s['TEST_TARGET_NAME']           = app.name
    s['PRODUCT_BUNDLE_IDENTIFIER']  = "#{bundle_id}.UITests"
    s['PRODUCT_NAME']               = '$(TARGET_NAME)'
    s['SWIFT_VERSION']              = '5.0'
    s['GENERATE_INFOPLIST_FILE']    = 'YES'
    s['TARGETED_DEVICE_FAMILY']     = '1,2'
    s['IPHONEOS_DEPLOYMENT_TARGET'] = deploy
    s['CODE_SIGN_STYLE']            = 'Automatic'
    s['SDKROOT']                    = 'iphoneos'
  end
  test.add_dependency(app)
  puts "    created target '#{test_name}'"
end

test = project.targets.find { |t| t.name == test_name }

scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(app)
scheme.add_test_target(test)
scheme.set_launch_target(app)
scheme.save_as(proj_path, test_name, true)   # shared scheme
puts "    shared scheme '#{test_name}' written"

project.save
RUBY

  cat > "$WIRE_TMP/fastlane/Fastfile" <<'WIRE_FASTFILE'
lane :wire do
  load File.join(ENV.fetch('WIRE_DIR'), 'wire.rb')
end
WIRE_FASTFILE

  if ! ( cd "$WIRE_TMP" && \
         WIRE_DIR="$WIRE_TMP" WIRE_PROJECT="$PROJECT" WIRE_TEST_NAME="$TEST_NAME" \
         WIRE_APP_TARGET="$APP_TARGET" WIRE_TESTS_DIR="$TESTS_DIR" \
         FASTLANE_SKIP_UPDATE_CHECK=1 FASTLANE_OPT_OUT_USAGE=1 \
         fastlane wire ); then
    rm -rf "$WIRE_TMP"
    die "Could not modify the Xcode project. Re-run with --no-wire and add the UITests/ folder as a UI Testing Bundle in Xcode manually."
  fi
  rm -rf "$WIRE_TMP"
fi

# ---------------------------------------------------------------- 6. fastlane config
pick_device() {
  xcrun simctl list devices available 2>/dev/null \
    | sed -E 's/^ +//; s/ \([0-9A-Fa-f-]{36}\).*$//' \
    | grep -E "$1" | sort -uV | tail -1 || true
}
IPHONE="$(pick_device '^iPhone [0-9]+ Pro Max$')"
IPAD="$(pick_device '^iPad Pro 13-inch')"
[[ -n "$IPHONE" ]] || { IPHONE="iPhone 17 Pro Max"; warn "No Pro Max simulator found; defaulting to '$IPHONE'. Install one in Xcode > Settings > Platforms."; }
[[ -n "$IPAD"   ]] || { IPAD="iPad Pro 13-inch (M5)"; warn "No iPad Pro 13\" simulator found; defaulting to '$IPAD'. Remove it from fastlane/Snapfile if your app is iPhone-only."; }

PROJECT_REL=""
[[ -n "$PROJECT" ]] && PROJECT_REL="${PROJECT#$ROOT/}"

write_file "$FASTLANE_DIR/Snapfile" <<SNAP
# fastlane snapshot configuration — docs: https://docs.fastlane.tools/actions/snapshot/
project("${PROJECT_REL}")
scheme("${TEST_NAME}")

# App Store Connect only needs the largest iPhone + iPad sizes; smaller ones are scaled.
devices([
  "${IPHONE}",
  "${IPAD}"
])

languages([
  "en-US"
  # "de-DE", "fr-FR", "ja"
])

output_directory("./fastlane/screenshots")
clear_previous_screenshots(true)
override_status_bar(true)       # 9:41, full battery, full signal
skip_open_summary(true)
erase_simulator(false)
number_of_retries(1)
concurrent_simulators(false)    # one device at a time: parallel boots are a common source of random failures
buildlog_path("./build/snapshot-logs")   # full xcodebuild log, read it when a run fails
xcargs("CODE_SIGNING_ALLOWED=NO")        # no signing needed for UI tests on a Simulator
SNAP

write_file "$FASTLANE_DIR/Fastfile" <<'FASTFILE'
default_platform(:ios)

platform :ios do
  desc "Capture App Store screenshots on all simulators/languages in Snapfile"
  lane :screenshots do
    capture_screenshots
  end

  desc "Capture screenshots and add device frames + captions (needs Framefile.json)"
  lane :framed do
    capture_screenshots
    frame_screenshots(white: true)
  end

  desc "Upload screenshots (only) to App Store Connect"
  lane :upload_screenshots do
    deliver(
      skip_binary_upload: true,
      skip_metadata: true,
      overwrite_screenshots: true,
      screenshots_path: "./fastlane/screenshots",
      force: true
    )
  end
end
FASTFILE

# ---------------------------------------------------------------- done
cat <<EOF

$(printf '\033[1;32mDone.\033[0m')

Next steps:
  1. In your JUCE app, detect launch arg  -SCREENSHOT_MODE  (NSUserDefaults key
     "SCREENSHOT_MODE") and load demo data / skip splash & permission dialogs.
  2. Edit  UITests/${TEST_NAME}.swift  — add taps/drags + snapshot("NN_Name") calls.
  3. Run from the app root:
         cd "$ROOT" && fastlane screenshots

Re-run this script after every Projucer / CMake project regeneration.
EOF