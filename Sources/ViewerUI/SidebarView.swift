// The folder list: header (folder name, refresh) and the files. Watches only FolderStore.
import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: FolderStore
    let onOpenFolder: () -> Void
    let onSelect: () -> Void
    
    // Search bar added
    @State private var searchText = ""

    private var filteredFiles: [ScaleFile] {
        guard !searchText.isEmpty else { return store.files }

        return store.files.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.folder.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        Group {
            if store.name == nil {
                placeholder("Choose a folder to browse its scales.", offersFolder: true)
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)

                        TextField("Search scales…", text: $searchText)
                            .textFieldStyle(.plain)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Clear search")
                        }
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                    if filteredFiles.isEmpty {
                        placeholder(
                            searchText.isEmpty
                                ? "No scale files (.scl) in this folder."
                                : "No matching scales found.",
                            offersFolder: false
                        )
                    } else {
                        List(filteredFiles, selection: $store.selection) { file in
                            VStack(alignment: .leading, spacing: 1) {
                                Text(file.name).lineLimit(1)

                                if !file.folder.isEmpty {
                                    Text(file.folder)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .listStyle(.sidebar)
                    }
                }
                
//                VStack(spacing: 0) {
//                    HStack {
//                        Image(systemName: "folder")
//                        Text(store.name ?? "").font(.subheadline.weight(.semibold)).lineLimit(1)
//                        Spacer()
//                        Button { store.rescan() } label: { Image(systemName: "arrow.clockwise") }
//                            .buttonStyle(.borderless)
//                            .accessibilityLabel("Refresh")
//                    }
//                    .padding(.horizontal, 12)
//                    .padding(.vertical, 8)
//                    if store.files.isEmpty && !store.scanning {
//                        placeholder("No scale files (.scl) in this folder.", offersFolder: false)
//                    } else {
//                        List(store.files, selection: $store.selection) { file in
//                            VStack(alignment: .leading, spacing: 1) {
//                                Text(file.name).lineLimit(1)
//                                if !file.folder.isEmpty {
//                                    Text(file.folder).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
//                                }
//                            }
//                        }
//                        .listStyle(.sidebar)
//                    }
//                }
            }
        }
        .onChange(of: store.selection) { _ in Task { @MainActor in onSelect() } }
    }

    private func placeholder(_ text: LocalizedStringKey, offersFolder: Bool) -> some View {
        VStack(spacing: 12) {
            Text(text).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if offersFolder {
                Button("Open Folder…") { onOpenFolder() }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
