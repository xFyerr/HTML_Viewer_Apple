import SwiftUI

/// Grid-mode folder view with long-press drag-to-reorder.
struct DraggableFolderGrid: View {
    @EnvironmentObject private var filesManager: RecentFilesManager
    var onSelect: (Folder) -> Void

    @State private var draggingID: UUID?
    @State private var dragPosition: CGPoint = .zero
    @State private var cellFrames: [UUID: CGRect] = [:]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    private let coordSpace = "draggableGrid"

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filesManager.folders) { folder in
                folderCell(folder)
                    .opacity(draggingID == folder.id ? 0.4 : 1)
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                cellFrames[folder.id] = geo.frame(in: .named(coordSpace))
                            }
                            .onChange(of: filesManager.folders.map(\.id)) { _ in
                                cellFrames[folder.id] = geo.frame(in: .named(coordSpace))
                            }
                        }
                    )
            }
        }
        .coordinateSpace(name: coordSpace)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .overlay(
            Group {
                if let id = draggingID,
                   let folder = filesManager.folders.first(where: { $0.id == id }) {
                    FolderGridItem(
                        folder: folder,
                        fileCount: filesManager.files(in: folder).count
                    )
                    .frame(width: ghostWidth)
                    .position(dragPosition)
                    .allowsHitTesting(false)
                    .shadow(color: .black.opacity(0.4), radius: 8)
                }
            }
        )
    }

    private var ghostWidth: CGFloat {
        (UIScreen.main.bounds.width - 32 - 24) / 3
    }

    private func folderCell(_ folder: Folder) -> some View {
        FolderGridItem(folder: folder, fileCount: filesManager.files(in: folder).count)
            .contentShape(Rectangle())
            .onTapGesture { onSelect(folder) }
            .gesture(
                LongPressGesture(minimumDuration: 0.4)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(coordSpace)))
                    .onChanged { value in
                        switch value {
                        case .second(true, let drag?):
                            if draggingID == nil { draggingID = folder.id }
                            dragPosition = drag.location
                            updateOrder(at: drag.location)
                        default:
                            break
                        }
                    }
                    .onEnded { _ in draggingID = nil }
            )
            .contextMenu {
                Button(role: .destructive) {
                    filesManager.deleteFolder(folder)
                } label: {
                    Label("Delete Folder", systemImage: "trash")
                }
            }
    }

    private func updateOrder(at point: CGPoint) {
        guard
            let dragging = draggingID,
            let targetID = cellFrames.first(where: { $0.value.contains(point) })?.key,
            targetID != dragging,
            let fromIndex = filesManager.folders.firstIndex(where: { $0.id == dragging }),
            let toIndex   = filesManager.folders.firstIndex(where: { $0.id == targetID })
        else { return }

        filesManager.moveFolders(
            from: IndexSet(integer: fromIndex),
            to: toIndex > fromIndex ? toIndex + 1 : toIndex
        )
        cellFrames = [:]
    }
}
