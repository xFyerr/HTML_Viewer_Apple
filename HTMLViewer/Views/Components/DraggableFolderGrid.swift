import SwiftUI
import UniformTypeIdentifiers

/// Unified grid view: files and folders in one 3-column grid.
/// Drag a file cell onto a folder cell to move the file into that folder.
/// Long-press drag reorders everything.
struct DraggableFolderGrid: View {
    @EnvironmentObject private var filesManager: RecentFilesManager
    var onSelectFolder: (Folder) -> Void
    var onSelectFile:   (HTMLFile) -> Void

    @State private var draggingRef: HomeItemRef?
    @State private var dragPosition: CGPoint = .zero
    @State private var cellFrames: [UUID: CGRect] = [:]
    @State private var targetedFolderID: UUID?

    private let columns   = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    private let coordSpace = "homeGrid"

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filesManager.homeOrder, id: \.id) { ref in
                cell(for: ref)
                    .opacity(draggingRef == ref ? 0.4 : 1)
                    .background(frameCapture(ref))
            }
        }
        .coordinateSpace(name: coordSpace)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        .overlay(ghostOverlay)
    }

    // MARK: - Cell dispatch

    @ViewBuilder
    private func cell(for ref: HomeItemRef) -> some View {
        switch ref {
        case .file(let id):
            if let file = filesManager.recentFiles.first(where: { $0.id == id }) {
                fileCell(file)
            }
        case .folder(let id):
            if let folder = filesManager.folders.first(where: { $0.id == id }) {
                folderCell(folder)
            }
        }
    }

    // MARK: - File cell

    private func fileCell(_ file: HTMLFile) -> some View {
        FileGridItem(file: file)
            .onTapGesture { onSelectFile(file) }
            .gesture(dragGesture(for: .file(file.id)))
            .onDrag { NSItemProvider(object: HomeItemRef.file(file.id).dragString as NSString) }
            .contextMenu { fileContextMenu(file) }
    }

    // MARK: - Folder cell

    private func folderCell(_ folder: Folder) -> some View {
        FolderGridItem(folder: folder, fileCount: filesManager.files(in: folder).count)
            .background(
                targetedFolderID == folder.id
                    ? Color(hex: "C4714B").opacity(0.15)
                    : Color.clear
            )
            .cornerRadius(12)
            .onTapGesture { onSelectFolder(folder) }
            .gesture(dragGesture(for: .folder(folder.id)))
            .onDrop(of: [UTType.plainText], isTargeted: Binding(
                get: { targetedFolderID == folder.id },
                set: { t in targetedFolderID = t ? folder.id : nil }
            )) { providers in
                handleDrop(providers, ontoFolder: folder)
            }
            .contextMenu { folderContextMenu(folder) }
    }

    // MARK: - Long-press drag gesture (for reorder)

    private func dragGesture(for ref: HomeItemRef) -> some Gesture {
        LongPressGesture(minimumDuration: 0.4)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(coordSpace)))
            .onChanged { value in
                switch value {
                case .second(true, let drag?):
                    if draggingRef == nil { draggingRef = ref }
                    dragPosition = drag.location
                    updateReorder(dragging: ref, at: drag.location)
                default: break
                }
            }
            .onEnded { _ in draggingRef = nil }
    }

    private func updateReorder(dragging: HomeItemRef, at point: CGPoint) {
        guard let targetID = cellFrames.first(where: { $0.value.contains(point) })?.key,
              targetID != dragging.id,
              let targetRef = filesManager.homeOrder.first(where: { $0.id == targetID })
        else { return }
        // Don't reorder onto a folder when dragging a file — that's handled by onDrop
        if case .folder = targetRef, case .file = dragging { return }
        filesManager.moveItem(dragging, before: targetRef)
        cellFrames = [:]
    }

    // MARK: - Drop handler (file → folder via system drag)

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
                    filesManager.moveItem(ref, before: .folder(folder.id))
                }
            }
        }
        return true
    }

    // MARK: - Frame capture for reorder hit-testing

    private func frameCapture(_ ref: HomeItemRef) -> some View {
        GeometryReader { geo in
            Color.clear
                .onAppear { cellFrames[ref.id] = geo.frame(in: .named(coordSpace)) }
                .onChange(of: filesManager.homeOrder.map(\.id)) { _ in
                    cellFrames[ref.id] = geo.frame(in: .named(coordSpace))
                }
        }
    }

    // MARK: - Ghost overlay

    private var ghostOverlay: some View {
        Group {
            if let dragging = draggingRef {
                ghostView(for: dragging)
                    .frame(width: ghostWidth)
                    .position(dragPosition)
                    .allowsHitTesting(false)
                    .shadow(color: .black.opacity(0.4), radius: 8)
            }
        }
    }

    @ViewBuilder
    private func ghostView(for ref: HomeItemRef) -> some View {
        switch ref {
        case .file(let id):
            if let file = filesManager.recentFiles.first(where: { $0.id == id }) {
                FileGridItem(file: file)
            }
        case .folder(let id):
            if let folder = filesManager.folders.first(where: { $0.id == id }) {
                FolderGridItem(folder: folder, fileCount: filesManager.files(in: folder).count)
            }
        }
    }

    private var ghostWidth: CGFloat { (UIScreen.main.bounds.width - 32 - 24) / 3 }

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
        Button(role: .destructive) { filesManager.removeFile(file) } label: {
            Label("Remove", systemImage: "trash")
        }
    }

    @ViewBuilder
    private func folderContextMenu(_ folder: Folder) -> some View {
        Button(role: .destructive) { filesManager.deleteFolder(folder) } label: {
            Label("Delete Folder", systemImage: "trash")
        }
    }
}
