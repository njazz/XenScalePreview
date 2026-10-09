// macOS app: the viewer (ViewerUI) in one window, plus the Quick Look extension in Contents/PlugIns. Files handed over
// by Finder or by Quick Look's "Open with" button arrive through the app delegate and show in the existing window.
#if os(macOS)
import AppKit
import SwiftUI
import ViewerUI

@main
struct XenScalePreviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("Xen Scale Preview") {
            ViewerView()
                .frame(minWidth: 760, minHeight: 520)
        }
        .handlesExternalEvents(matching: Set(["*"]))   // reuse the window instead of opening a new one per file
        .commands { CommandGroup(replacing: .newItem) {} }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }

    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        Task { @MainActor in ViewerModel.shared.open(url) }
    }
}
#else
// This target is the macOS app. The iOS app lives in iOS/App.swift. This stub only lets "build all package
// targets" succeed when Xcode builds the Swift package for an iOS destination.
@main
struct XenScalePreviewMacOnly {
    static func main() {}
}
#endif
