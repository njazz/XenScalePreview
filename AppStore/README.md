# App Store checklist

One bundle ID for iOS and macOS gives a **universal purchase**: one listing, one price. Create the app record in
App Store Connect with your own reverse-domain bundle ID (`BUNDLE_ID`), then:

```sh
TEAM_ID=ABCDE12345 BUNDLE_ID=com.example.xenscalepreview VERSION=1.0 BUILD=1 ./build_appstore.sh all
# -> dist/appstore/ios/XenScalePreview.ipa and dist/appstore/macos/XenScalePreview.pkg
# add --upload to send them straight to App Store Connect; raise BUILD for every new upload
```

You also need an Apple Developer Program membership and the Xcode account for that team signed in.

## Listing draft

| Field | Draft |
| --- | --- |
| Name (max 30) | Xen Scale Preview |
| Subtitle (max 30) | Quick Look for .scl tunings |
| Category | Music (secondary: Utilities) |
| Keywords (max 100) | microtonal,tuning,xenharmonic,edo,scl,just intonation,temperament,scale,preview |
| Age rating | 4+ (no objectionable content) |
| Price | One base price, around $0.99; pick it in the Price menu (Apple derives the other storefronts) |
| Support URL | your GitHub repository |
| Privacy policy URL | link to `PRIVACY.md` in the repository (also linked in-app: add a link before submitting, see below) |
| App privacy | Data Not Collected |
| Export compliance | No encryption beyond Apple's (`ITSAppUsesNonExemptEncryption` is already `NO`) |

**Description:** Preview Scala microtonal scale files (.scl) anywhere you can press Space or tap a file. See the
scale as a pitch wheel and a one-period keyboard, read every degree in cents and ratios, and check the source,
in light or dark mode. Works for any equal division (19, 31, 53…), just intonation and non-octave scales like
Bohlen-Pierce. No account, no ads, no tracking.

**Review notes:** No login. Open Files (iOS) or Finder (macOS), select any `.scl` file (samples are in the
repository's `Examples` folder) and preview it. The iOS and macOS apps also have an **Open…** button.

## Things App Review may push on

- **Minimum functionality (4.2).** The iOS app has an in-app **Open…** preview. The macOS app currently only registers
  and explains the extension, which is thin for review. Adding the same open-and-preview window to the macOS app is
  the cheap fix.
- **Privacy policy (5.1.1).** Apple wants the policy linked in App Store Connect *and* reachable inside the app.
  A "Privacy" link in the iOS and macOS apps pointing at `PRIVACY.md` is still to do.
- **Names and keywords (2.3.7).** No trademarked terms or prices in the name, subtitle, keywords or screenshots.
  "Scala" is the file format's name, so describe it factually ("Scala scale files") and keep it out of the app name.
- **Mac sandbox (2.4.5).** The macOS app and extension are sandboxed (`Bundle/macOS-App.entitlements`,
  `Bundle/Extension.entitlements`). The pluginkit buttons in the macOS app may not work from inside the sandbox;
  the system registers the extension itself once the app is installed.

## Screenshots

Source: [Apple's screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications)
and guideline 2.3.3 of the App Review Guidelines.

- 1 to 10 screenshots per device size; `.png`, `.jpg` or `.jpeg`; **no alpha channel or transparency**.
- Screenshots must **show the app in use** (2.3.3). Title art, login screens and splash screens alone are rejected.
  Text and image overlays are allowed. They must not show prices or claims that don't belong in screenshots (2.3.7).
- **iPhone:** at least one at 1260×2736, 1290×2796 or 1320×2868 (portrait), or the landscape equivalents. If you
  supply only that size, App Store Connect scales it down for smaller iPhones.
- **iPad (required, the app supports iPad):** 2064×2752 or 2048×2732 (13", portrait), or 2752×2064 / 2732×2048 landscape.
- **Mac (required):** 1280×800, 1440×900, 2560×1600 or 2880×1800 (16:10).
- App previews (videos) are optional and may only be screen captures of the app itself (2.3.4).

Good shots for this app: the 31-EDO wheel (shows the black/white clusters), 12-TET (familiar baseline), a ratio-based
scale such as 5-limit JI, a non-octave scale (Bohlen-Pierce), and one in dark mode. Capture them from the real app:
Quick Look in Finder on a Mac, Files on an iPhone/iPad or the Simulator (`xcrun simctl io booted screenshot x.png`).

`Tools/appstore_screenshots.py` resizes and pads real screenshots to the exact sizes, flattened to opaque PNG:

```sh
pip install pillow
python3 Tools/appstore_screenshots.py mac    shots/*.png
python3 Tools/appstore_screenshots.py iphone shots/*.png --margin 0.04
python3 Tools/appstore_screenshots.py ipad   shots/*.png
```
