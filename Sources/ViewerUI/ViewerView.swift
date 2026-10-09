// The app window for iOS and macOS: a top bar (folder list, open file, open folder, close), an optional sidebar
// listing the .scl files of a folder, and the preview with the playable keyboard. On a compact width (iPhone)
// the folder list opens as a sheet instead of a sidebar.
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public struct ViewerView: View {
    @ObservedObject private var model = ViewerModel.shared
    @State private var showSidebar = true
    @State private var showSheet = false
    @State private var importing = false
    @State private var importsFolder = false
    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    private var compact: Bool { sizeClass == .compact }
    #else
    private var compact: Bool { false }
    #endif

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            HStack(spacing: 0) {
                if showSidebar && !compact {
                    sidebar.frame(width: 260)
                    Divider()
                }
                detail
            }
        }
        .sheet(isPresented: $showSheet) {
            VStack(spacing: 0) {
                HStack {
                    Spacer()
                    Button("Close") { showSheet = false }.padding(12)
                }
                sidebar
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: importsFolder ? [.folder] : [.data]) { result in
            guard case .success(let url) = result else { return }
            if importsFolder {
                model.openFolder(url)
                revealSidebar()
            } else {
                model.open(url)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: URL.self) { url, _ in
                guard let url else { return }
                Task { @MainActor in model.open(url) }
            }
            return true
        }
        .onAppear { Task { @MainActor in model.restoreFolder() } }   // not inside the update pass
    }

    private func pick(folder: Bool) {
        importsFolder = folder
        importing = true
    }

    private func revealSidebar() {
        if compact { showSheet = true } else { showSidebar = true }
    }

    // MARK: Top bar

    private var topBar: some View {
        HStack(spacing: 14) {
            Button {
                if compact { showSheet.toggle() } else { showSidebar.toggle() }
            } label: {
                Image(systemName: "sidebar.left")
            }
            .help("Folder")
            .accessibilityLabel("Folder")

            Text(model.fileName ?? "Xen Scale Preview")
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()

            Button { pick(folder: false) } label: { Image(systemName: "doc") }
                .help("Open File…")
                .accessibilityLabel("Open File…")
                .keyboardShortcut("o")
            Button { pick(folder: true) } label: { Image(systemName: "folder") }
                .help("Open Folder…")
                .accessibilityLabel("Open Folder…")
                .keyboardShortcut("o", modifiers: [.command, .shift])
            Button { model.close() } label: { Image(systemName: "xmark.circle") }
                .help("Close")
                .accessibilityLabel("Close")
                .disabled(model.html == nil && !model.loading)
        }
        .buttonStyle(.borderless)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }

    // MARK: Sidebar

    private var sidebar: some View {
        SidebarView(store: model.folder,
                    onOpenFolder: { pick(folder: true) },
                    onSelect: { showSheet = false })
    }

    // MARK: Detail

    private var detail: some View {
        ZStack {
            content
            if model.loading {
                Rectangle().fill(.ultraThinMaterial)
                ProgressView().controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// The web view is always present (empty and hidden until a scale is open), so WebKit's process is already up
    /// when the first file is chosen instead of starting then.
    private var content: some View {
        ZStack {
            VStack(spacing: 0) {
                ScaleWebView(html: model.html ?? "",
                             onFinish: { model.finishedLoading() },
                             onSynth: { model.synthChanged(reference: $0, octave: $1) },
                             onAudio: { model.audioReady(milliseconds: $0) })
//                if model.html != nil, !model.timings.isEmpty {
//                    Text(model.timings)
//                        .font(.caption2.monospaced())
//                        .foregroundStyle(.secondary)
//                        .padding(.vertical, 3)
//                }
                #if os(iOS)
                if model.html != nil, let typeID = model.typeID {   // the file type iOS assigns, for diagnosing Quick Look matching
                    Text(verbatim: String(format: NSLocalizedString("File type: %@", comment: ""), typeID))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(6)
                }
                #endif
            }
            .opacity(model.html == nil ? 0 : 1)
            if model.html == nil { welcome }
        }
    }

    private var welcome: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Open a scale file or a folder, or drop one here.").font(.headline)
                #if os(macOS)
                MacStatus()
                #else
                Text("Quick Look previews for Scala scale files (.scl): a pitch wheel, a one-period keyboard, the degrees and the source.")
                Text("Open a scale in Files, Mail or Messages and tap it, or press and hold and choose Preview. The extension runs on its own, so you can close this app.")
                    .foregroundStyle(.secondary)
                Text("If a file still opens as plain text, make sure no other app has claimed .scl, then reinstall this app.")
                    .foregroundStyle(.secondary)
                #endif
                if let failure = model.failure { Text(failure).foregroundStyle(.red) }
            }
            .padding(24)
            .frame(maxWidth: 560, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
    }
}
