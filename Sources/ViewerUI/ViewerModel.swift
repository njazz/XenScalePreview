// State of the viewer: the open scale. The folder list lives in FolderStore.
// One shared instance, so files handed to the app from outside (Finder, Quick Look's "Open with", Files) reach the window.
import Foundation
import SwiftUI
import UniformTypeIdentifiers
import SclCore

@MainActor
public final class ViewerModel: ObservableObject {
    public static let shared = ViewerModel()

    @Published public private(set) var html: String?
    @Published public private(set) var fileName: String?
    @Published public private(set) var typeID: String?
    @Published public private(set) var failure: String?
    /// True from choosing a file until the page has finished showing it (drives the spinner).
    @Published public private(set) var loading = false
    /// Where the time went for the last file, e.g. "read + render 9 ms · page 412 ms · audio 35 ms" (shown under the page).
    @Published public private(set) var timings = ""
    /// The folder shown in the sidebar (its own object, so folder changes don't redraw the page and vice versa).
    let folder = FolderStore()

    private var loadToken = 0
    private var loadStart = Date()
    private var renderMs = 0
    private var pageMs: Int?
    private var audioMs: Int?
    /// Synth settings, kept across scales: the A4 frequency and the octave shift.
    public private(set) var reference = 440.0
    public private(set) var octave = 0

    private init() {
        let d = UserDefaults.standard
        let r = d.double(forKey: "synthReference")
        if r >= 100 && r <= 2000 { reference = r }
        octave = max(-4, min(4, d.integer(forKey: "synthOctave")))
    }

    public func synthChanged(reference: Double, octave: Int) {
        self.reference = reference
        self.octave = octave
        UserDefaults.standard.set(reference, forKey: "synthReference")
        UserDefaults.standard.set(octave, forKey: "synthOctave")
    }

    public func finishedLoading() {
        loading = false
        guard html != nil, pageMs == nil else { return }
        pageMs = max(0, Int(Date().timeIntervalSince(loadStart) * 1000) - renderMs)
        refreshTimings()
    }

    public func audioReady(milliseconds: Int) {
        audioMs = milliseconds
        refreshTimings()
    }

    private func refreshTimings() {
        var parts = ["read + render \(renderMs) ms"]
        if let p = pageMs { parts.append("page \(p) ms") }
        if let a = audioMs { parts.append("audio \(a) ms") }
        timings = parts.joined(separator: " · ")
    }

    // MARK: Files

    /// Opens whatever the system hands over: a scale file, or a folder.
    public func open(_ url: URL) {
        let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
        if isDir { openFolder(url) } else { load(url) }
    }

    /// Reads and renders off the main thread, then shows the page; `loading` stays on until the web view has finished.
    func load(_ url: URL) {
        loadToken += 1
        let token = loadToken
        loading = true
        loadStart = Date()
        pageMs = nil
        audioMs = nil
        timings = ""
        let reference = self.reference, octave = self.octave
        Task.detached(priority: .userInitiated) {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let name = url.lastPathComponent
            #if os(iOS)
            let type = (try? url.resourceValues(forKeys: [.contentTypeKey]))?.contentType?.identifier   // only the iOS caption uses it
            #else
            let type: String? = nil
            #endif
            let result: Result<String, Error> = Result {
                let data = try Data(contentsOf: url)
                return Scl.html(from: data, fileName: name, interactive: true, reference: reference, octave: octave)
            }
            await MainActor.run { self.finishLoad(token: token, name: name, type: type, result: result) }
        }
    }

    private func finishLoad(token: Int, name: String, type: String?, result: Result<String, Error>) {
        guard token == loadToken else { return }        // a newer file was chosen meanwhile
        switch result {
        case .success(let page):
            let unchanged = page == html
            renderMs = Int(Date().timeIntervalSince(loadStart) * 1000)
            refreshTimings()
            html = page
            fileName = name
            typeID = type
            failure = nil
            if unchanged { loading = false; pageMs = 0; refreshTimings() }            // the web view won't navigate, so nothing else would end the spinner
        case .failure(let error):
            html = nil
            fileName = nil
            typeID = nil
            failure = error.localizedDescription
            loading = false
        }
    }

    /// Closes the open scale (the folder list stays).
    public func close() {
        loadToken += 1
        loading = false
        html = nil
        fileName = nil
        typeID = nil
        failure = nil
        folder.selection = nil
    }

    // MARK: Folder

    public func openFolder(_ url: URL) { folder.open(url) }
    public func rescan() { folder.rescan() }
    /// Reopens the folder from the last session, if the system still grants access to it.
    public func restoreFolder() { folder.restore() }
}
