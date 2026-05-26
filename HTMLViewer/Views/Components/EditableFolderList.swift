import SwiftUI
import UniformTypeIdentifiers

/// Unified list view: files and folders in one ordered list.
/// Drag a file row on top of a folder row to move the file into that folder.
/// Long-press drag handles reorder everything.
struct EditableFolderList: View {
    @EnvironmentObject private var filesManager: RecentFilesManager
    var onSelectFolder: (Folder) -> Void
    var onSelectFile:   (HTMLFile) -> Void

    var body: some View {
        List {
            ForEach(filesManager.homeOrder, id: \.id) { ref in
                rowView(for: ref)
                    .listRowBackground(Color(hex: "1A1A1A"))
                    .listRowInsets(EdgeInsets())
                    .listRowSeparatorTint(Color(hex: "2A2A2A"))
            }
            .onMove { source, destination in
                moveItems(from: source, to: destination)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .scrollDisabled(true)
        .frame(height: CGFloat(filesManager.homeOrder.count) * 72)
        .background(Color(hex: "1A1A1A"))
    }

    @ViewBuilder
    private func rowView(for ref: HomeItemRef) -> some View {
        switch ref {
        case .file(let id):
            if let file = filesManager.recentFiles.first(where: { $0.id == id }) {
                fileRow(file)
            }
        case .folder(let id):
            if let folder = filesManager.folders.first(where: { $0.id == id }) {
                folderRow(folder)
            }
        }
    }

    // MARK: - File row

    private func fileRow(_ file: HTMLFile) -> some View {
        Button { onSelectFile(file) } label: {
            RecentFileRow(file: file)
        }
        .buttonStyle(.plain)
        .onDrag { NSItemProvider(object: HomeItemRef.file(file.id).dragString as NSString) }
        .contextMenu { fileContextMenu(file) }
    }

    // MARK: - Folder row

    @State private var targetedFolderID: UUID?

    private func folderRow(_ folder: Folder) -> some View {
        Button { onSelectFolder(folder) } label: {
            FolderRow(
                folder: folder,
                fileCount: filesManager.files(in: folder).count
            )
            .background(
                targetedFolderID == folder.id
                    ? Color(hex: "C4714B").opacity(0.15)
                    : Color.clear
            )
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .onDrag { NSItemProvider(object: HomeItemRef.folder(folder.id).dragString as NSString) }
        .onDrop(of: [UTType.plainText], isTargeted: Binding(
            get: { targetedFolderID == folder.id },
            set: { targeted in targetedFolderID = targeted ? folder.id : nil }
        )) { providers in
            handleDrop(providers, ontoFolder: folder)
        }
        .contextMenu { folderContextMenu(folder) }
    }

    // MARK: - Drop handler

    private func handleDrop(_ providers: [NSItemProvider], ontoFolder folder: Folder) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: NSString.self) { item, _ in
            guard let str = item as? String, let ref = HomeItemRef.from(str) else { return }
            DispatchQueue.main.async {
                switch ref {
                case .file(let fileID):
                    if let file = filesManager.recentFiles.first(where: { $0.id == fileID }) {
                        filesManager.addFile(file, toFolder: folder)
                    }
                case .folder:
                    // Folder dropped on folder: reorder before target
                    filesManager.moveItem(ref, before: .folder(folder.id))
                }
            }
        }
        return true
    }

    // MARK: - Reorder (List onMove)

    private func moveItems(from source: IndexSet, to destination: Int) {
        let order = filesManager.homeOrder
        let items = source.map { order[$0] }
        var result = order.enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let adj = destination - source.filter { $0 < destination }.count
        result.insert(contentsOf: items, at: min(adj, result.count))
        filesManager.homeOrder = result
    }

    // MARK: - Context menus

    @ViewBuilder
    private func fileContextMenu(_ file: HTMLFile) -> some View {
        if !filesManager.folders.isEmpty {
            Menu("Add to Folder") {
                ForEach(filesManager.folders) { folder in
                    Button {
                        filesManager.addFile(file, toFolder: folder)
                    } label: {
                        Label(folder.name, systemImage: "folder")
                    }
                }
            }
        }
        Button(role: .destructive) {
            filesManager.removeFile(file)
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func folderContextMenu(_ folder: Folder) -> some View {
        Button(role: .destructive) {
            filesManager.deleteFolder(folder)
        } label: {
            Label("Delete Folder", systemImage: "trash")
        }
    }
}
