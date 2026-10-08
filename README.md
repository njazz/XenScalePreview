# XenScalePreview

**Unofficial Quick Look preview for Scala microtonal scale files (`.scl`), for macOS and iOS / iPadOS.**

Select an `.scl` file in Finder and press Space, or tap one in Files, Mail or Messages. The preview is split in two
(stacked on a phone):

- **Left:** the file name, description and a summary (note count, period, step sizes, equal-division
  detection). Below that come a pitch wheel and a one-period keyboard. Each degree owns the span halfway to
  its neighbours, so wedge and key widths follow the real pitch spacing. A degree is drawn as a black key
  when its nearest 12-TET pitch is C♯, D♯, F♯, G♯ or A♯. Wheel labels show cents, unrounded as written in
  the file, or to 3 decimals for ratios. Last comes a table of every degree with its value, cents, step
  and nearest 12-TET note.
- **Right:** the file itself as read-only source with line numbers. Comments, the description, the note
  count and pitch values are highlighted, and a line that fails to parse is underlined.

The page uses black and white keys plus the system accent colour, and follows light and dark mode.
Non-octave scales (for example Bohlen-Pierce, period 3/1) wrap the wheel at their own period.

The app **Xen Scale Preview** carries the Quick Look extension. It's a Swift package plus an XcodeGen project,
for macOS 12+ and iOS 16+, with no dependencies. The iOS app can also open a scale directly, which is handy for
testing. The macOS and iOS apps share one bundle ID, so they can ship as a single universal App Store purchase.

> Not affiliated with or endorsed by the authors of Scala. macOS, iOS, Finder and Quick Look are trademarks
> of Apple Inc.

## Build

| Script | What it builds | Needs |
| --- | --- | --- |
| `./build_macos.sh` | `dist/XenScalePreview.zip`, the macOS app (ad-hoc signed) | Command Line Tools |
| `./build_macos.sh --archive` | signed Xcode archive + export in `dist/macos/` | Xcode, XcodeGen, `TEAM_ID` |
| `./build_ios.sh` | `dist/XenScalePreview-iOS-Simulator.zip`, unsigned, for the Simulator | Xcode, XcodeGen |
| `./build_ios.sh --archive` | signed archive + `.ipa` export in `dist/ios/` | Xcode, XcodeGen, `TEAM_ID` |
| `TEAM_ID=… BUNDLE_ID=… ./build_appstore.sh ios\|macos\|all` | App Store archives and exports (`.ipa`, `.pkg`); `--upload` sends them to App Store Connect | Xcode, XcodeGen, `TEAM_ID`, your own `BUNDLE_ID` |
| `./gen_project.sh` | `XenScalePreview.xcodeproj` with all four targets, for working in Xcode (see below) | XcodeGen |

Install XcodeGen with `brew install xcodegen`.

| Option | Default | Purpose |
| --- | --- | --- |
| `BUNDLE_ID=com.you.xen-scale-preview` | `local.xen-scale-preview` | App bundle ID; the extension gets `<id>.quicklook` |
| `VERSION=1.0.0` | `1.0` | Version shown in Finder / App Store |
| `TEAM_ID=ABCDE12345` | none | Apple Developer team, required for `--archive` |
| `EXPORT_METHOD=…` | `developer-id` (macOS), `development` (iOS) | Also `app-store-connect`, `mac-application`, `release-testing` |
| `SIGN_ID="…"` | `-` (ad-hoc) | macOS SwiftPM build only: signing identity |
| `UNIVERSAL=1` | off | macOS SwiftPM build only: arm64 + x86_64, needs full Xcode |

For App Store builds use `--archive` with `EXPORT_METHOD=app-store-connect` and your own `BUNDLE_ID`.

### Install on macOS

```sh
./install_mac.sh                 # build, sign (ad-hoc), install to ~/Applications, register
qlmanage -p Examples/ji-5-limit.scl
./install_mac.sh --uninstall
```

Or download `XenScalePreview.zip` from [Releases](../../releases), move the app to `/Applications` and open it
once. It isn't notarized, so macOS blocks the first launch: click **Open Anyway** under System Settings ›
Privacy & Security, or run `xattr -dr com.apple.quarantine /Applications/XenScalePreview.app`. Keep the app
installed, because the extension lives inside it.

### Install on iOS

- **Simulator:** `./build_ios.sh`, then `xcrun simctl install booted build/dd/Build/Products/Release-iphonesimulator/XenScalePreview.app`.
  Add `Examples/*.scl` by dragging them onto the Simulator, then preview them in Files.
- **Device:** `TEAM_ID=… ./build_ios.sh --archive`, or open `XenScalePreview.xcodeproj` after `./gen_project.sh`,
  pick the **XenScalePreview-iOS** scheme and run it.

### Open in Xcode

```sh
TEAM_ID=ABCDE12345 ./gen_project.sh --open
```

Pick the **XenScalePreview-iOS** or **XenScalePreview-macOS** scheme and run. The project is generated next to `Package.swift` from
`project.yml`, so change that file rather than the project; Xcode-side edits are lost on regeneration. Open
`XenScalePreview.xcodeproj`, not `Package.swift`: the package is only the SwiftPM build used by `build_macos.sh` and `scl2html`, and the app and extension targets need the project. (If you do open the package for an
iOS destination, every target still compiles, because the macOS-only host app has an iOS stub.)

For the App Store see [AppStore/README.md](AppStore/README.md): listing draft, review pitfalls and screenshot sizes.

## Develop without installing

```sh
swift run scl2html Examples/31-EDO.scl > /tmp/s.html && open /tmp/s.html
```

Quick Look runs no JavaScript in HTML previews, so everything (wheel, keyboard, highlighting) is static
HTML and SVG generated in Swift. What you see in Safari is what Quick Look shows.

## Layout

```
Package.swift                                    SwiftPM: SclCore library + macOS executables
project.yml                                      XcodeGen spec: iOS + macOS app and extension targets
Sources/
  SclCore/Scl.swift                              .scl parser + HTML/SVG renderer (all the real logic)
  XenScalePreviewExtension/PreviewProvider.swift Quick Look extension, shared by macOS and iOS
  XenScalePreviewExtension/main.swift            SwiftPM only: calls NSExtensionMain (no .appex product type)
  XenScalePreview/App.swift                      macOS host app: registers the extension, shows status
  scl2html/main.swift                            command-line tool for testing
iOS/App.swift                                    iOS host app: info screen + open-a-file preview
Bundle/                                          Info.plists, entitlements, privacy manifest, macOS AppIcon.iconset
AppStore/  Tools/  PRIVACY.md                    store checklist, screenshot sizing tool, privacy policy
Localization/App/                                host-app strings, one <lang>.lproj each
Icon/                                            icon source (SVG), PNGs, Xcode asset catalog; make_icon.py + render.js
Examples/                                        12-TET, 31-EDO, 5-limit JI, Bohlen-Pierce
build_macos.sh  build_ios.sh  build_appstore.sh  gen_project.sh     build scripts
install_mac.sh                                   build_macos.sh + install + register
.github/workflows/build.yml                      CI: macOS app, iOS Simulator app, release asset on v* tags
```

SwiftPM can't build `.app` or `.appex` bundles, so `build_macos.sh` assembles
`XenScalePreview.app/Contents/{MacOS,Info.plist,PlugIns/XenScalePreviewExtension.appex}` by hand and signs it.
iOS needs an Xcode project, which is what `project.yml` is for. The extension source is the same on both platforms:
`QLPreviewProvider` and `QLPreviewReply` exist on iOS 15+ and macOS 12+.

The app icon is the preview's pitch wheel for 31-EDO reduced to its ring: 31 wedges, white or black by the same rule as the
preview, separated only by gaps. It has no text, outlines or accent colour.

## File format

The [Scala `.scl` format](https://www.huygens-fokker.org/scala/scl_format.html) is plain text:

```
! lines starting with "!" are comments
description line
 12           number of notes
 100.0        cents (contains a ".")
 9/8          ratio
 2            integer ratio (2/1)
 ...          anything after the value is ignored
```

Degree 0 (1/1) is implicit and the last pitch is the period. Files are read as UTF-8, falling back to
Latin-1. A file that's malformed still previews: the parsed part is drawn, a warning names the bad line,
and that line is underlined in the source view.

## Troubleshooting

- **No preview on macOS:** open the app and click **Reset Quick Look**. Then check that **Xen Scale Preview** is
  turned on under Quick Look in System Settings › Extensions (the app's **Extension Settings…** button).
- **Plain-text preview instead of the wheel:** run `mdls -name kMDItemContentType file.scl` (macOS). It should
  print `local.xen-scale-preview.scl`. If another app (a synth, a tuning tool, a code previewer) has claimed `.scl`
  under a different identifier, add that identifier to `QLSupportedContentTypes` in `Bundle/Extension-Info.plist`
  and rebuild.
- **No preview on iOS:** the file type must not conform to `public.plain-text`, or iOS can pick its built-in text
  preview instead of the extension. This project declares it as `public.data`. On iOS 27, third-party previewers for
  system-owned file types are reportedly skipped, so keep the custom type. Reinstalling the app makes iOS
  re-register the extension.
- **Works on one iOS device but not another, or the in-app preview works but Files shows plain text:** open the file with
  **Open…** in the app and read the **File type** line at the bottom. If it isn't `local.xen-scale-preview.scl`, another
  app has claimed `.scl`. Add that identifier to `QLSupportedContentTypes` in `Bundle/Extension-Info.plist`, rebuild, and
  reinstall. Also compare iOS versions: see the iOS 27 note above.
- **Is the extension registered (macOS)?** `pluginkit -mv -p com.apple.quicklook.preview | grep -i xen`
- **Logs (macOS):** `log stream --predicate 'process == "XenScalePreviewExtension"'`

## License

MIT, see [LICENSE](LICENSE).

## Languages

English, French, Italian, German, Spanish, Japanese and Simplified Chinese. Only the app's own wording is translated
(the apps, and the preview's headings, chips, table columns, tooltips and error messages). A scale's description,
comments and values are always shown exactly as written in the file.

- **Preview page:** `Sources/SclCore/L10n.swift` holds one table of strings per language. It follows the system's
  preferred languages (Traditional Chinese falls back to Simplified, anything else to English). Placeholders are `{0}`, `{1}` …;
  plurals are `<key>.one` / `<key>.other`.
- **Host apps (iOS and macOS):** `Localization/App/<lang>.lproj/Localizable.strings` (the key is the English text, so a missing table falls back to English). Xcode picks these up through
  `project.yml`, and `build_macos.sh` copies them into the app. The languages are also listed as `CFBundleLocalizations`
  in the app Info.plists.
- **Adding a language:** add a `<lang>.lproj` folder, add the code to `CFBundleLocalizations`, and add a column to every
  entry in `L10n.swift` (plus the `uiLanguage` check at the top). Please have a native speaker check the music terms.
- **App Store:** name, subtitle, description, keywords and screenshots are localized per language in App Store Connect.
