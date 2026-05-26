# Folder Organisation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add user-created folders to the home screen so recent HTML files can be organised, with list and grid view modes and drag-to-reorder folder support.

**Architecture:** A new `Folder` model holds an ordered list of file IDs. `RecentFilesManager` gains a `folders: [Folder]` array persisted to UserDefaults alongside `recentFiles`. `HomeView` is restructured to pin the most-recently-opened file at the top, show a toggleable list/grid of user folders below, and keep loose (unfoldered) files in a third section. Drag-to-reorder uses `List.onMove` in list mode and a long-press + drag gesture in grid mode.

**Tech Stack:** SwiftUI, Combine, Foundation (UserDefaults + Codable), iOS 16+

---

## File Map

| Action | Path | Responsibility |
|--------|------|----------------|
| Create | `HTMLViewer/Models/Folder.swift` | `Folder` model: id, name, fileIDs |
| Modify | `HTMLViewer/Models/RecentFilesManager.swift` | Add `folders` array + CRUD methods |
| Create | `HTMLViewer/Models/ViewMode.swift` | `ViewMode` enum + UserDefaults-backed `@AppStorage` |
| Modify | `HTMLViewer/Views/HomeView.swift` | Pinned recent + folder sections + view-mode toggle |
| Create | `HTMLViewer/Views/FolderDetailView.swift` | Files inside one folder (list view) |
| Create | `HTMLViewer/Views/Components/FolderRow.swift` | List-style folder row |
| Create | `HTMLViewer/Views/Components/FolderGridItem.swift` | Grid-style folder cell |
| Create | `HTMLViewer/Views/Components/CreateFolderSheet.swift` | Text-field sheet for naming a new folder |

---

### Task 1: Folder model

**Files:**
- Create: `HTMLViewer/Models/Folder.swift`

- [ ] **Step 1: Create the file**

```swift
// HTMLViewer/Models/Folder.swift
import Foundation

struct Folder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var fileIDs: [UUID]   // ordered; determines display order inside the folder

    init(id: UUID = UUID(), name: String, fileIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.fileIDs = fileIDs
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add HTMLViewer/Models/Folder.swift
git commit -m "feat: add Folder model"
```

---

### Task 2: Extend RecentFilesManager with folder CRUD

**Files:**
- Modify: `HTMLViewer/Models/RecentFilesManager.swift`

- [ ] **Step 1: Replace the full file content**

```swift
// HTMLViewer/Models/RecentFilesManager.swift
import Foundation
import Combine

class RecentFilesManager: ObservableObject {
    @Published var recentFiles: [HTMLFile] = []
    @Published var folders: [Folder] = []

    private let filesKey   = "recentHTMLFiles"
    private let foldersKey = "htmlViewerFolders"
    private let maxCount   = 50

    init() {
        load()
    }

    // MARK: - Files

    func addFile(url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        guard let bookmark = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }

        let displayName = url.deletingPathExtension().lastPathComponent
        recentFiles.removeAll { $0.name == displayName }

        let file = HTMLFile(name: displayName, bookmarkData: bookmark)
        recentFiles.insert(file, at: 0)

        if recentFiles.count > maxCount {
            recentFiles = Array(recentFiles.prefix(maxCount))
        }
        save()
    }

    func removeFile(_ file: HTMLFile) {
        recentFiles.removeAll { $0.id == file.id }
        // also remove from any folder
        for i in folders.indices {
            folders[i].fileIDs.removeAll { $0 == file.id }
        }
        save()
    }

    // MARK: - Folders

    func createFolder(name: String) {
        let folder = Folder(name: name)
        folders.append(folder)
        save()
    }

    func deleteFolder(_ folder: Folder) {
        folders.removeAll { $0.id == folder.id }
        save()
    }

    func renameFolder(_ folder: Folder, to name: String) {
        guard let i = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[i].name = name
        save()
    }

    /// Move folders in list/grid (drag-to-reorder).
    func moveFolders(from source: IndexSet, to destination: Int) {
        folders.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func addFile(_ file: HTMLFile, toFolder folder: Folder) {
        guard let fi = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[fi].fileIDs.removeAll { $0 == file.id }
        folders[fi].fileIDs.insert(file.id, at: 0)
        save()
    }

    func removeFile(_ file: HTMLFile, fromFolder folder: Folder) {
        guard let fi = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[fi].fileIDs.removeAll { $0 == file.id }
        save()
    }

    /// Files that belong to a given folder, in folder order.
    func files(in folder: Folder) -> [HTMLFile] {
        folder.fileIDs.compactMap { id in recentFiles.first { $0.id == id } }
    }

    /// Files not assigned to any folder, in recency order.
    var loosFiles: [HTMLFile] {
        let allFolderIDs = Set(folders.flatMap { $0.fileIDs })
        return recentFiles.filter { !allFolderIDs.contains($0.id) }
    }

    // MARK: - Persistence

    private func save() {
        if let encoded = try? JSONEncoder().encode(recentFiles) {
            UserDefaults.standard.set(encoded, forKey: filesKey)
        }
        if let encoded = try? JSONEncoder().encode(folders) {
            UserDefaults.standard.set(encoded, forKey: foldersKey)
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: filesKey),
           let decoded = try? JSONDecoder().decode([HTMLFile].self, from: data) {
            recentFiles = decoded
        }
        if let data = UserDefaults.standard.data(forKey: foldersKey),
           let decoded = try? JSONDecoder().decode([Folder].self, from: data) {
            folders = decoded
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add HTMLViewer/Models/RecentFilesManager.swift
git commit -m "feat: add folder CRUD to RecentFilesManager"
```

---

### Task 3: ViewMode enum

**Files:**
- Create: `HTMLViewer/Models/ViewMode.swift`

- [ ] **Step 1: Create the file**

```swift
// HTMLViewer/Models/ViewMode.swift
import Foundation

enum ViewMode: String {
    case list
    case grid
}
```

- [ ] **Step 2: Commit**

```bash
git add HTMLViewer/Models/ViewMode.swift
git commit -m "feat: add ViewMode enum"
```

---

### Task 4: FolderRow component (list view)

**Files:**
- Create: `HTMLViewer/Views/Components/FolderRow.swift`

- [ ] **Step 1: Create the file**

```swift
// HTMLViewer/Views/Components/FolderRow.swift
import SwiftUI

struct FolderRow: View {
    let folder: Folder
    let fileCount: Int

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(hex: "2A4A6A"))
                    .frame(width: 46, height: 46)
                Image(systemName: "folder.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(hex: "5B9BD5"))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(folder.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text("\(fileCount) \(fileCount == 1 ? "file" : "files")")
                    .font(.system(size: 13))
                    .foregroundColor(Color(hex: "666666"))
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(hex: "3A3A3A"))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
        .contentShape(Rectangle())
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add HTMLViewer/Views/Components/FolderRow.swift
git commit -m "feat: add FolderRow list component"
```

---

### Task 5: FolderGridItem component (grid view)

**Files:**
- Create: `HTMLViewer/Views/Components/FolderGridItem.swift`

- [ ] **Step 1: Create the file**

```swift
// HTMLViewer/Views/Components/FolderGridItem.swift
import SwiftUI

struct FolderGridItem: View {
    let folder: Folder
    let fileCount: Int

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "folder.fill")
                .font(.system(size: 48))
                .foregroundColor(Color(hex: "5B9BD5"))
                .frame(height: 56)

            Text(folder.name)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            Text("\(fileCount) \(fileCount == 1 ? "file" : "files")")
                .font(.system(size: 11))
                .foregroundColor(Color(hex: "666666"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 6)
        .background(Color(hex: "2A2A2A"))
        .cornerRadius(12)
        .contentShape(Rectangle())
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add HTMLViewer/Views/Components/FolderGridItem.swift
git commit -m "feat: add FolderGridItem grid component"
```

---

### Task 6: CreateFolderSheet component

**Files:**
- Create: `HTMLViewer/Views/Components/CreateFolderSheet.swift`

- [ ] **Step 1: Create the file**

```swift
// HTMLViewer/Views/Components/CreateFolderSheet.swift
import SwiftUI

struct CreateFolderSheet: View {
    @Environment(\.dismiss) private var dismiss
    var onCreate: (String) -> Void

    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "1A1A1A").ignoresSafeArea()
                VStack(spacing: 20) {
                    TextField("Folder name", text: $name)
                        .focused($focused)
                        .padding()
                        .background(Color(hex: "2A2A2A"))
                        .cornerRadius(10)
                        .foregroundColor(.white)
                        .tint(Color(hex: "C4714B"))
                        .padding(.horizontal)
                    Spacer()
                }
                .padding(.top, 20)
            }
            .navigationTitle("New Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Color(hex: "C4714B"))
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        let trimmed = name.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        onCreate(trimmed)
                        dismiss()
                    }
                    .foregroundColor(name.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color(hex: "666666") : Color(hex: "C4714B"))
                }
            }
        }
        .onAppear { focused = true }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add HTMLViewer/Views/Components/CreateFolderSheet.swift
git commit -m "feat: add CreateFolderSheet"
```

---

### Task 7: FolderDetailView

**Files:**
- Create: `HTMLViewer/Views/FolderDetailView.swift`

- [ ] **Step 1: Create the file**

```swift
// HTMLViewer/Views/FolderDetailView.swift
import SwiftUI

struct FolderDetailView: View {
    @EnvironmentObject private var filesManager: RecentFilesManager
    let folder: Folder
    @State private var selectedFile: HTMLFile?

    var body: some View {
        ZStack {
            Color(hex: "1A1A1A").ignoresSafeArea()
            let folderFiles = filesManager.files(in: folder)
            if folderFiles.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder")
                        .font(.system(size: 48))
                        .foregroundColor(Color(hex: "3A3A3A"))
                    Text("No files yet")
                        .foregroundColor(Color(hex: "666666"))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(folderFiles) { file in
                            Button {
                                selectedFile = file
                            } label: {
                                RecentFileRow(file: file)
                            }
                            .buttonStyle(.plain)
                            .overlay(
                                Divider()
                                    .background(Color(hex: "2A2A2A"))
                                    .padding(.leading, 80),
                                alignment: .bottom
                            )
                            .contextMenu {
                                Button(role: .destructive) {
                                    filesManager.removeFile(file, fromFolder: folder)
                                } label: {
                                    Label("Remove from Folder", systemImage: "folder.badge.minus")
                                }
                                Button(role: .destructive) {
                                    filesManager.removeFile(file)
                                } label: {
                                    Label("Delete from Recents", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
        .navigationTitle(folder.name)
        .navigationBarTitleDisplayMode(.large)
        .fullScreenCover(item: $selectedFile) { file in
            HTMLViewerView(file: file)
        }
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add HTMLViewer/Views/FolderDetailView.swift
git commit -m "feat: add FolderDetailView"
```

---

### Task 8: Rewrite HomeView

**Files:**
- Modify: `HTMLViewer/Views/HomeView.swift`

This is the main integration step. The new HomeView:
1. Pins the single most-recently-opened file at the top (across all files)
2. Shows user folders in list or grid mode (drag to reorder)
3. Shows loose files (not in any folder) below folders in recents order
4. Header has grid/list toggle buttons and folder-create button

- [ ] **Step 1: Replace HomeView**

```swift
// HTMLViewer/Views/HomeView.swift
import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var filesManager: RecentFilesManager
    @Binding var pendingURL: URL?

    @AppStorage("viewMode") private var viewMode: String = ViewMode.list.rawValue
    @State private var isShowingFilePicker   = false
    @State private var isShowingCreateFolder = false
    @State private var selectedFile: HTMLFile?

    // Drag-to-reorder state for grid mode
    @State private var draggingFolder: Folder?
    @GestureState private var dragOffset: CGSize = .zero

    private var currentMode: ViewMode { ViewMode(rawValue: viewMode) ?? .list }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "1A1A1A").ignoresSafeArea()
                VStack(alignment: .leading, spacing: 0) {
                    header.padding(.top, 8)
                    if filesManager.recentFiles.isEmpty && filesManager.folders.isEmpty {
                        EmptyStateView(onOpenTapped: { isShowingFilePicker = true })
                    } else {
                        mainContent
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .navigationViewStyle(.stack)
        .sheet(isPresented: $isShowingFilePicker) {
            DocumentPickerView { url in
                filesManager.addFile(url: url)
                selectedFile = filesManager.recentFiles.first
            }
        }
        .sheet(isPresented: $isShowingCreateFolder) {
            CreateFolderSheet { name in
                filesManager.createFolder(name: name)
            }
        }
        .fullScreenCover(item: $selectedFile) { file in
            HTMLViewerView(file: file)
        }
        .onChange(of: pendingURL) { url in
            guard let url else { return }
            pendingURL = nil
            filesManager.addFile(url: url)
            selectedFile = filesManager.recentFiles.first
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            Text("Recents")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            // Demo button
            Button(action: openDemo) {
                ZStack {
                    Circle().fill(Color(hex: "2A2A2A")).frame(width: 44, height: 44)
                    Image(systemName: "doc.text")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "C4714B"))
                }
            }

            // Grid / List toggle
            Button { viewMode = ViewMode.grid.rawValue } label: {
                ZStack {
                    Circle()
                        .fill(currentMode == .grid ? Color(hex: "C4714B").opacity(0.2) : Color(hex: "2A2A2A"))
                        .frame(width: 44, height: 44)
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 18))
                        .foregroundColor(currentMode == .grid ? Color(hex: "C4714B") : Color(hex: "888888"))
                }
            }
            Button { viewMode = ViewMode.list.rawValue } label: {
                ZStack {
                    Circle()
                        .fill(currentMode == .list ? Color(hex: "C4714B").opacity(0.2) : Color(hex: "2A2A2A"))
                        .frame(width: 44, height: 44)
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18))
                        .foregroundColor(currentMode == .list ? Color(hex: "C4714B") : Color(hex: "888888"))
                }
            }

            // New folder button
            Button { isShowingCreateFolder = true } label: {
                ZStack {
                    Circle().fill(Color(hex: "2A2A2A")).frame(width: 44, height: 44)
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "C4714B"))
                }
            }

            // Open file button
            Button { isShowingFilePicker = true } label: {
                ZStack {
                    Circle().fill(Color(hex: "2A2A2A")).frame(width: 44, height: 44)
                    Image(systemName: "plus")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "C4714B"))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    // MARK: - Main content

    @ViewBuilder
    private var mainContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Pinned most-recent file
                if let topFile = filesManager.recentFiles.first {
                    pinnedFileRow(topFile)
                }

                // Folders
                if !filesManager.folders.isEmpty {
                    sectionLabel("Folders")
                    if currentMode == .list {
                        folderListSection
                    } else {
                        folderGridSection
                    }
                }

                // Loose files (skip the pinned one)
                let loose = filesManager.loosFiles
                let looseWithoutTop = filesManager.recentFiles.first.map { top in
                    loose.filter { $0.id != top.id }
                } ?? loose

                if !looseWithoutTop.isEmpty {
                    sectionLabel("Recent Files")
                    ForEach(looseWithoutTop) { file in
                        looseFileRow(file)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Pinned file

    private func pinnedFileRow(_ file: HTMLFile) -> some View {
        Button { selectedFile = file } label: {
            RecentFileRow(file: file)
        }
        .buttonStyle(.plain)
        .contextMenu { fileContextMenu(file) }
    }

    // MARK: - Folder sections

    private var folderListSection: some View {
        // Use List embedded in ScrollView is tricky; use LazyVStack + manual move
        LazyVStack(spacing: 0) {
            ForEach(filesManager.folders) { folder in
                NavigationLink(destination: FolderDetailView(folder: folder)) {
                    FolderRow(folder: folder, fileCount: filesManager.files(in: folder).count)
                }
                .buttonStyle(.plain)
                .overlay(
                    Divider().background(Color(hex: "2A2A2A")).padding(.leading, 80),
                    alignment: .bottom
                )
                .contextMenu { folderContextMenu(folder) }
            }
        }
    }

    private var folderGridSection: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filesManager.folders) { folder in
                NavigationLink(destination: FolderDetailView(folder: folder)) {
                    FolderGridItem(
                        folder: folder,
                        fileCount: filesManager.files(in: folder).count
                    )
                }
                .buttonStyle(.plain)
                .contextMenu { folderContextMenu(folder) }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }

    // MARK: - Loose file row

    private func looseFileRow(_ file: HTMLFile) -> some View {
        Button { selectedFile = file } label: {
            RecentFileRow(file: file)
        }
        .buttonStyle(.plain)
        .overlay(
            Divider().background(Color(hex: "2A2A2A")).padding(.leading, 80),
            alignment: .bottom
        )
        .contextMenu { fileContextMenu(file) }
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
            Label("Remove from Recents", systemImage: "trash")
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

    // MARK: - Section label

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(hex: "888888"))
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }

    // MARK: - Demo

    private func openDemo() {
        guard let url = Bundle.main.url(forResource: "test", withExtension: "html"),
              let bookmark = try? url.bookmarkData() else { return }
        selectedFile = HTMLFile(name: "test.html", bookmarkData: bookmark)
    }
}
```

- [ ] **Step 2: Commit**

```bash
git add HTMLViewer/Views/HomeView.swift
git commit -m "feat: rewrite HomeView with folders, list/grid toggle, pinned recent"
```

---

### Task 9: Drag-to-reorder folders in list mode

List mode drag reorder uses a dedicated `EditableFolderList` view backed by SwiftUI's `List` with `.onMove`.

**Files:**
- Create: `HTMLViewer/Views/Components/EditableFolderList.swift`
- Modify: `HTMLViewer/Views/HomeView.swift` — replace `folderListSection`

- [ ] **Step 1: Create EditableFolderList**

```swift
// HTMLViewer/Views/Components/EditableFolderList.swift
import SwiftUI

/// Wraps a List so folders can be reordered via long-press drag.
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
        .environment(\.editMode, .constant(.active))   // enables drag handles always
        .scrollDisabled(true)                           // outer ScrollView handles scroll
        .frame(height: CGFloat(filesManager.folders.count) * 72)
        .background(Color(hex: "1A1A1A"))
    }
}
```

- [ ] **Step 2: Update `folderListSection` in HomeView**

In `HomeView.swift`, replace `folderListSection`:

```swift
private var folderListSection: some View {
    EditableFolderList { folder in
        selectedFolderForNav = folder
    }
}
```

And add the navigation state + NavigationLink at the top of the `body`:

```swift
@State private var selectedFolderForNav: Folder?
```

Add a `NavigationLink` driven by `selectedFolderForNav` inside the `NavigationView`, e.g. as a hidden link:

```swift
// Inside NavigationView's ZStack, alongside the VStack:
NavigationLink(
    destination: selectedFolderForNav.map { FolderDetailView(folder: $0) },
    isActive: Binding(
        get: { selectedFolderForNav != nil },
        set: { if !$0 { selectedFolderForNav = nil } }
    )
) { EmptyView() }
.hidden()
```

- [ ] **Step 3: Commit**

```bash
git add HTMLViewer/Views/Components/EditableFolderList.swift HTMLViewer/Views/HomeView.swift
git commit -m "feat: drag-to-reorder folders in list mode"
```

---

### Task 10: Drag-to-reorder folders in grid mode

Grid drag reorder uses long-press + drag gesture to visually move cells and calls `moveFolders` on drop.

**Files:**
- Create: `HTMLViewer/Views/Components/DraggableFolderGrid.swift`
- Modify: `HTMLViewer/Views/HomeView.swift` — replace `folderGridSection`

- [ ] **Step 1: Create DraggableFolderGrid**

```swift
// HTMLViewer/Views/Components/DraggableFolderGrid.swift
import SwiftUI

struct DraggableFolderGrid: View {
    @EnvironmentObject private var filesManager: RecentFilesManager
    var onSelect: (Folder) -> Void

    @State private var draggingID: UUID?
    @State private var dragPosition: CGPoint = .zero
    @State private var cellFrames: [UUID: CGRect] = [:]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)
    private let cellCoordSpace = "grid"

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(filesManager.folders) { folder in
                folderCell(folder)
                    .opacity(draggingID == folder.id ? 0.4 : 1)
                    .background(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                cellFrames[folder.id] = geo.frame(in: .named(cellCoordSpace))
                            }
                        }
                    )
            }
        }
        .coordinateSpace(name: cellCoordSpace)
        .padding(.horizontal, 16)
        .padding(.top, 4)
        // Ghost cell follows finger
        .overlay(
            Group {
                if let id = draggingID,
                   let folder = filesManager.folders.first(where: { $0.id == id }) {
                    FolderGridItem(folder: folder, fileCount: filesManager.files(in: folder).count)
                        .frame(width: ghostWidth)
                        .position(dragPosition)
                        .allowsHitTesting(false)
                        .shadow(color: .black.opacity(0.4), radius: 8)
                }
            }
        )
    }

    private var ghostWidth: CGFloat {
        // approximate cell width for 3-col grid on a 390pt wide screen
        (UIScreen.main.bounds.width - 32 - 24) / 3
    }

    private func folderCell(_ folder: Folder) -> some View {
        FolderGridItem(folder: folder, fileCount: filesManager.files(in: folder).count)
            .contentShape(Rectangle())
            .onTapGesture { onSelect(folder) }
            .gesture(
                LongPressGesture(minimumDuration: 0.4)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named(cellCoordSpace)))
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
                    .onEnded { _ in
                        draggingID = nil
                    }
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
        guard let dragging = draggingID,
              let targetID = cellFrames.first(where: { $0.value.contains(point) })?.key,
              targetID != dragging,
              let fromIndex = filesManager.folders.firstIndex(where: { $0.id == dragging }),
              let toIndex   = filesManager.folders.firstIndex(where: { $0.id == targetID })
        else { return }

        filesManager.moveFolders(from: IndexSet(integer: fromIndex), to: toIndex > fromIndex ? toIndex + 1 : toIndex)
        // Update frames after move
        cellFrames = [:]
    }
}
```

- [ ] **Step 2: Update `folderGridSection` in HomeView**

Replace `folderGridSection` computed property:

```swift
private var folderGridSection: some View {
    DraggableFolderGrid { folder in
        selectedFolderForNav = folder
    }
}
```

- [ ] **Step 3: Commit**

```bash
git add HTMLViewer/Views/Components/DraggableFolderGrid.swift HTMLViewer/Views/HomeView.swift
git commit -m "feat: drag-to-reorder folders in grid mode"
```

---

### Task 11: Wire Xcode project (add new files)

All new Swift files must be added to the Xcode target `HTMLViewer`.

- [ ] **Step 1: Open Xcode**

Open `HTMLViewer/HTMLViewer.xcodeproj`. In the Project Navigator, right-click each new file group and choose **Add Files to "HTMLViewer"** — or drag the files in. Ensure each file has the `HTMLViewer` target checkbox ticked.

New files to add:
- `Models/Folder.swift`
- `Models/ViewMode.swift`
- `Views/FolderDetailView.swift`
- `Views/Components/FolderRow.swift`
- `Views/Components/FolderGridItem.swift`
- `Views/Components/CreateFolderSheet.swift`
- `Views/Components/EditableFolderList.swift`
- `Views/Components/DraggableFolderGrid.swift`

- [ ] **Step 2: Build (⌘B) and fix any compile errors**

- [ ] **Step 3: Run on iPhone simulator, verify:**
  - Creating a folder via the `+folder` button
  - Opening a file pins it to top
  - Switching between list and grid view persists across relaunches
  - Long-press drag reorders folders in both modes
  - Tapping folder opens `FolderDetailView`
  - Context menu on file lets you add it to a folder
  - Context menu on folder lets you delete it

- [ ] **Step 4: Commit**

```bash
git add HTMLViewer/HTMLViewer.xcodeproj/project.pbxproj
git commit -m "chore: add new folder organisation files to Xcode target"
```
