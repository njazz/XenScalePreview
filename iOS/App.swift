// iOS host app. It carries the Quick Look extension (Files, Mail, Messages and AirDrop previews of .scl
// files) and lets you open a scale directly, which also makes it easy to test the renderer on a device.
import SwiftUI
import WebKit
import UniformTypeIdentifiers
import SclCore

@main
struct XenScalePreviewApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var html: String?
    @State private var fileName: String?
    @State private var typeID: String?   // the file type iOS assigns, for diagnosing Quick Look matching
    @State private var importing = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Group {
                if let html {
                    VStack(spacing: 0) {
                        ScalePage(html: html)
                        if let typeID {
                            Text(verbatim: String(format: NSLocalizedString("File type: %@", comment: ""), typeID))
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .padding(6)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Quick Look previews for Scala scale files (.scl): a pitch wheel, a one-period keyboard, the degrees and the source.")
                            Text("Open a scale in Files, Mail or Messages and tap it, or press and hold and choose Preview. The extension runs on its own, so you can close this app.")
                                .foregroundStyle(.secondary)
                            Text("If a file still opens as plain text, make sure no other app has claimed .scl, then reinstall this app.")
                                .foregroundStyle(.secondary)
                            if let failure { Text(failure).foregroundStyle(.red) }
                        }
                        .padding(24)
                        .frame(maxWidth: 560, alignment: .leading)
                    }
                }
            }
            .navigationTitle(fileName ?? "Xen Scale Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Open…") { importing = true }
                }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
                load(result)
            }
        }
    }

    private func load(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            html = Scl.html(from: data, fileName: url.lastPathComponent)
            fileName = url.lastPathComponent
            typeID = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.identifier
            failure = nil
        } catch {
            failure = error.localizedDescription
        }
    }
}

/// The preview page in a web view with JavaScript off (the page is static HTML and SVG).
struct ScalePage: UIViewRepresentable {
    let html: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = false
        let view = WKWebView(frame: .zero, configuration: config)
        view.isOpaque = false
        view.backgroundColor = .clear
        return view
    }

    func updateUIView(_ view: WKWebView, context: Context) {
        view.loadHTMLString(html, baseURL: nil)
    }
}
