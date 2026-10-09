fastlane documentation
----

# Installation

Make sure you have the latest version of the Xcode command line tools installed:

```sh
xcode-select --install
```

For _fastlane_ installation instructions, see [Installing _fastlane_](https://docs.fastlane.tools/#installing-fastlane)

# Available Actions

## iOS

### ios doctor

```sh
[bundle exec] fastlane ios doctor
```

Check the machine and project for screenshot problems, without running any tests

### ios screenshots

```sh
[bundle exec] fastlane ios screenshots
```

Capture App Store screenshots on all simulators/languages in Snapfile

### ios framed

```sh
[bundle exec] fastlane ios framed
```

Capture screenshots and add device frames + captions (needs Framefile.json)

### ios upload_screenshots

```sh
[bundle exec] fastlane ios upload_screenshots
```

Upload screenshots (only) to App Store Connect

----

This README.md is auto-generated and will be re-generated every time [_fastlane_](https://fastlane.tools) is run.

More information about _fastlane_ can be found on [fastlane.tools](https://fastlane.tools).

The documentation of _fastlane_ can be found on [docs.fastlane.tools](https://docs.fastlane.tools).
