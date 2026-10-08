// Host ("dummy") app. Its only real job is to carry the Quick Look extension in
// Contents/PlugIns and declare the .scl file type. Opening it once registers the extension;
// the window shows the status and what to do next. It doesn't need to keep running.
#if os(macOS)
import AppKit
import SwiftUI

@main
struct XenScalePreviewApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup("Xen Scale Preview") { ContentView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}

struct ContentView: View {
    @State private var registered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Xen Scale Preview").font(.title2.bold())
            Text("Quick Look previews for Scala scale files (.scl). Select one in Finder and press Space.")

            Label(LocalizedStringKey(registered ? "Quick Look extension is registered" : "Quick Look extension is not registered yet"),
                  systemImage: registered ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(registered ? Color.green : Color.orange)

            Text("""
            You can quit this app now. Keep it installed, though: the extension lives inside it. \
            If previews don't appear, turn on “Xen Scale Preview” under Quick Look in \
            System Settings › Extensions, then click Reset Quick Look.
            """)
            .font(.callout)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)

            HStack {
                Button("Extension Settings…") { Extension.openSettings() }
                Button("Reset Quick Look") {
                    Extension.register()
                    Extension.resetQuickLook()
                    registered = Extension.isRegistered()
                }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }.keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 500)
        .onAppear {
            Extension.register()
            registered = Extension.isRegistered()
        }
    }
}

/// The same pluginkit/qlmanage calls install_mac.sh makes, so a drag-installed app works too.
enum Extension {
    static let appexURL = Bundle.main.builtInPlugInsURL?.appendingPathComponent("XenScalePreviewExtension.appex")
    static let id = (Bundle.main.bundleIdentifier ?? "local.xen-scale-preview") + ".quicklook"

    static func register() {
        if let path = appexURL?.path { run("/usr/bin/pluginkit", "-a", path) }
        run("/usr/bin/pluginkit", "-e", "use", "-i", id)
    }

    static func isRegistered() -> Bool {
        run("/usr/bin/pluginkit", "-m", "-i", id).contains(id)
    }

    static func resetQuickLook() {
        run("/usr/bin/qlmanage", "-r")
        run("/usr/bin/qlmanage", "-r", "cache")
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.ExtensionsPreferences") {
            NSWorkspace.shared.open(url)
        }
    }

    @discardableResult
    static func run(_ tool: String, _ args: String...) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: tool)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        guard (try? p.run()) != nil else { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
#else
// This target is the macOS host app. The iOS app lives in iOS/App.swift. This stub only lets "build all package
// targets" succeed when Xcode builds the Swift package for an iOS destination.
@main
struct XenScalePreviewMacOnly {
    static func main() {}
}
#endif
