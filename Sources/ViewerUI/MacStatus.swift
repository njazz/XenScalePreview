#if os(macOS)
import AppKit
import SwiftUI

/// What the macOS app shows next to the file prompt: whether the Quick Look extension is registered, and the two fixes.
struct MacStatus: View {
    @State private var registered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
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
                Button("Extension Settings…") { QuickLookExtension.openSettings() }
                Button("Reset Quick Look") { refresh(reset: true) }
            }
        }
        .onAppear { refresh(reset: false) }
    }

    /// pluginkit and qlmanage take a moment, so they run off the main thread.
    private func refresh(reset: Bool) {
        DispatchQueue.global(qos: .userInitiated).async {
            QuickLookExtension.register()
            if reset { QuickLookExtension.resetQuickLook() }
            let ok = QuickLookExtension.isRegistered()
            Task { @MainActor in registered = ok }
        }
    }
}

/// The same pluginkit/qlmanage calls install_mac.sh makes, so a drag-installed app works too.
enum QuickLookExtension {
    static let appexURL = Bundle.main.builtInPlugInsURL?.appendingPathComponent("XenScalePreviewExtension.appex")
    static let id = (Bundle.main.bundleIdentifier ?? "com.alexnadzharov") + ".quicklook"

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
#endif
