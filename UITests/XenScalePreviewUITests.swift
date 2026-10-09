import XCTest
import UIKit

/// Drives Xen Scale Preview and captures App Store screenshots via fastlane snapshot (`fastlane screenshots`).
///
/// The app is SwiftUI + a WKWebView, so XCUITest can see the buttons and the web view. The system document picker
/// is awkward to automate, so the app loads a generated 31-EDO scale itself when launched with -SCREENSHOT_MODE YES
/// (see ScreenshotMode in iOS/App.swift). Add more snapshot("NN_Name") calls for more screenshots.
final class XenScalePreviewUITests: XCTestCase {

    // SnapshotHelper's setupSnapshot()/snapshot() are @MainActor, while XCTestCase's setUp/test methods are not
    // isolated. XCTest runs them on the main thread, so MainActor.assumeIsolated bridges the two (iOS 17+).
    var app: XCUIApplication!

    /// App Store Connect takes at most 10 screenshots per device size: scenes x orientations x appearances must stay <= 10.
    /// Trim these lists to ship fewer variants (e.g. only [.portrait] and ["light"]).
    let orientations: [(name: String, value: UIDeviceOrientation)] = [("portrait", .portrait), ("landscape", .landscapeLeft)]
    let appearances = ["light", "dark"]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testTakeScreenshots() throws {
        MainActor.assumeIsolated {
            var number = 0
            for appearance in appearances {
                app?.terminate()
                // The appearance is a launch argument (the app applies it in ScreenshotMode), so relaunch for each one.
                app = XCUIApplication()
                setupSnapshot(app)                                  // fastlane hook (language, locale, status bar)
                app.launchArguments += ["-SCREENSHOT_MODE", "YES", "-SCREENSHOT_APPEARANCE", appearance]
                app.launch()

                // The scale is rendered off the main thread and shown in a web view; wait for the view, then for it to settle.
                XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 30), "the preview web view never appeared")

                for orientation in orientations {
                    XCUIDevice.shared.orientation = orientation.value
                    waitForUI(3)
                    number += 1
                    // Names sort in capture order, which is the order App Store Connect shows them in.
                    snapshot(String(format: "%02d_Preview_%@_%@", number, orientation.name, appearance))
                }
                XCUIDevice.shared.orientation = .portrait
            }

            // More scenes: open another scale (see docs/SCREENSHOTS.md), then repeat the inner loop.
            // app.buttons["Open File…"].tap()  // buttons are found by their accessibility label
        }
    }

    // MARK: - Helpers

    /// Tap at a normalized position (0...1), for things XCUITest can't see (the keyboard drawn inside the web view).
    @MainActor func tap(_ x: CGFloat, _ y: CGFloat) {
        app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y)).tap()
        waitForUI(1)
    }

    /// Drag between two normalized positions (sliding across keys, scrolling).
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
