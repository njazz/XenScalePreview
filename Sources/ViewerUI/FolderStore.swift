// The folder shown in the sidebar: its .scl files as one flat, lazily drawn list. It is its own object, apart from
// ViewerModel, so that opening a scale (loading, html, timings …) never re-evaluates a list of thousands of rows;
// a tree (List with children) was measurably slow to rebuild on macOS.
import Foundation
import SwiftUI

public struct ScaleFile: Identifiable, Hashable, Sendable {
    public let url: URL
    public let folder: String               // path of the containing folder relative to the chosen one ("" at the top)
    public var id: URL { url }
    public var name: String { url.lastPathComponent }
}

enum FolderScanner {
    /// All .scl files under `root`, up to `depth` folder levels and `budget` files, sorted by folder then name.
    static func scan(_ root: URL, depth: Int, budget: Int) -> [ScaleFile] {
        var out: [ScaleFile] = []
        var budget = budget
        func walk(_ dir: URL, _ relative: String, _ level: Int) {
            guard let items = try? FileManager.default.contentsOfDirectory(
                at: dir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) else { return }
            for u in items {
                let isDir = (try? u.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if isDir {
                    if level < depth { walk(u, relative.isEmpty ? u.lastPathComponent : relative + "/" + u.lastPathComponent, level + 1) }
                } else if u.pathExtension.lowercased() == "scl", budget > 0 {
                    budget -= 1
                    out.append(ScaleFile(url: u, folder: relative))
                }
            }
        }
        walk(root, "", 0)
        return out.sorted {
            $0.folder != $1.folder
                ? $0.folder.localizedStandardCompare($1.folder) == .orderedAscending
                : $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

@MainActor
public final class FolderStore: ObservableObject {
    @Published public private(set) var name: String?
    @Published public private(set) var files: [ScaleFile] = []
    @Published public private(set) var scanning = false
    /// The selected row. Choosing a file opens it.
    @Published public var selection: URL? {
        didSet {
            // Opened one turn later: the List may write this binding while SwiftUI is updating views, and publishing
            // from inside an update is not allowed. The check drops it if the selection changed or was cleared meanwhile.
            if let u = selection, u != oldValue {
                Task { @MainActor in
                    if self.selection == u { ViewerModel.shared.load(u) }
                }
            }
        }
    }

    private var folderURL: URL?
    private var scopedFolder: URL?           // held open while the folder is browsed (sandbox access)
    private let bookmarkKey = "lastFolder"

    init() {}

    func open(_ url: URL, remember: Bool = true) {
        scopedFolder?.stopAccessingSecurityScopedResource()
        scopedFolder = url.startAccessingSecurityScopedResource() ? url : nil
        folderURL = url
        name = url.lastPathComponent
        if remember { saveBookmark(url) }
        rescan()
    }

    func rescan() {
        guard let url = folderURL else { return }
        scanning = true
        Task.detached(priority: .userInitiated) {
            let found = FolderScanner.scan(url, depth: 4, budget: 3000)
            await MainActor.run {
                guard self.folderURL == url else { return }
                self.files = found
                self.scanning = false
            }
        }
    }

    /// Reopens the folder from the last session, if the system still grants access to it.
    func restore() {
        guard folderURL == nil, let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        var stale = false
        #if os(macOS)
        let options: URL.BookmarkResolutionOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkResolutionOptions = []
        #endif
        guard let url = try? URL(resolvingBookmarkData: data, options: options, relativeTo: nil, bookmarkDataIsStale: &stale) else {
            UserDefaults.standard.removeObject(forKey: bookmarkKey)
            return
        }
        open(url, remember: stale)
    }

    private func saveBookmark(_ url: URL) {
        #if os(macOS)
        let options: URL.BookmarkCreationOptions = [.withSecurityScope]
        #else
        let options: URL.BookmarkCreationOptions = []
        #endif
        if let data = try? url.bookmarkData(options: options, includingResourceValuesForKeys: nil, relativeTo: nil) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }
    }
}
