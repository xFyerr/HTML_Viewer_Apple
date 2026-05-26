import SwiftUI

/// List-mode folder view with drag-to-reorder via long-press drag handles.
struct EditableFolderList: View {
    @EnvironmentObject private var filesManager: RecentFilesManager
    var onSelect: (Folder) -> Void

    var body: some View {
        List {
            ForEach(filesManager.folders) { folder in
                Button {
                    onSelect(folder)
                } label: {
                    FolderRow(
                        folder: folder,
                        fileCount: filesManager.files(in: folder).count
                    )
                }
                .listRowBackground(Color(hex: "1A1A1A"))
                .listRowInsets(EdgeInsets())
                .listRowSeparatorTint(Color(hex: "2A2A2A"))
                .contextMenu {
                    Button(role: .destructive) {
                        filesManager.deleteFolder(folder)
                    } label: {
                        Label("Delete Folder", systemImage: "trash")
                    }
                }
            }
            .onMove { source, destination in
                filesManager.moveFolders(from: source, to: destination)
            }
        }
        .listStyle(.plain)
        .environment(\.editMode, .constant(.active))
        .scrollDisabled(true)
        .frame(height: CGFloat(filesManager.folders.count) * 72)
        .background(Color(hex: "1A1A1A"))
    }
}
