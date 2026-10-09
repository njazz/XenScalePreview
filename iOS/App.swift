// iOS app: the viewer (ViewerUI) in a window. It also carries the Quick Look extension (Files, Mail, Messages and AirDrop
// previews of .scl files). Files handed over from Files or the share sheet ("Open in…") arrive through onOpenURL.
import SwiftUI
import ViewerUI

@main
struct XenScalePreviewApp: App {
    var body: some Scene {
        WindowGroup {
            ViewerView()
                .onOpenURL { url in Task { @MainActor in ViewerModel.shared.open(url) } }
                .preferredColorScheme(ScreenshotMode.colorScheme)
                .onAppear { ScreenshotMode.loadDemoScaleIfRequested() }
        }
    }
}

/// `fastlane screenshots` launches the app with `-SCREENSHOT_MODE YES` (see UITests/XenScalePreviewUITests.swift).
/// The UI test can't pick a file through the system document picker, so the app opens a generated 31-EDO scale itself.
/// Without the launch argument this does nothing.
enum ScreenshotMode {
    static var isActive: Bool { UserDefaults.standard.bool(forKey: "SCREENSHOT_MODE") }

    /// `-SCREENSHOT_APPEARANCE dark|light` forces the appearance (the preview page follows it); nil = follow the system.
    static var colorScheme: ColorScheme? {
        guard isActive else { return nil }
        switch UserDefaults.standard.string(forKey: "SCREENSHOT_APPEARANCE") {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    static func loadDemoScaleIfRequested() {
        guard isActive else { return }
        var scl = "! 31-EDO.scl\n31 tone equal temperament\n 31\n!\n"
        for step in 1..<31 { scl += String(format: " %.6f\n", 1200.0 * Double(step) / 31.0) }
        scl += " 2/1\n"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("31-EDO.scl")
        do { try scl.write(to: url, atomically: true, encoding: .utf8) } catch { return }
        Task { @MainActor in ViewerModel.shared.open(url) }
    }
}
