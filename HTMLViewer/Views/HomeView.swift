import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var filesManager: RecentFilesManager
    @Binding var pendingURL: URL?

    @AppStorage("viewMode") private var viewMode: String = ViewMode.list.rawValue
    @State private var isShowingFilePicker    = false
    @State private var isShowingCreateFolder  = false
    @State private var selectedFile: HTMLFile?
    @State private var selectedFolderForNav: Folder?

    private var currentMode: ViewMode { ViewMode(rawValue: viewMode) ?? .list }

    var body: some View {
        NavigationView {
            ZStack {
                Color(hex: "1A1A1A").ignoresSafeArea()

                // Hidden nav link for folder detail
                NavigationLink(
                    destination: selectedFolderForNav.map {
                        FolderDetailView(folder: $0)
                            .environmentObject(filesManager)
                    },
                    isActive: Binding(
                        get: { selectedFolderForNav != nil },
                        set: { if !$0 { selectedFolderForNav = nil } }
                    )
                ) { EmptyView() }
                .hidden()

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
        HStack(alignment: .center, spacing: 8) {
            Text("Recents")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            Button(action: openDemo) {
                iconButton(systemName: "doc.text")
            }

            Button { viewMode = ViewMode.grid.rawValue } label: {
                iconButton(
                    systemName: "square.grid.2x2",
                    active: currentMode == .grid
                )
            }

            Button { viewMode = ViewMode.list.rawValue } label: {
                iconButton(
                    systemName: "list.bullet",
                    active: currentMode == .list
                )
            }

            Button { isShowingCreateFolder = true } label: {
                iconButton(systemName: "folder.badge.plus")
            }

            Button { isShowingFilePicker = true } label: {
                iconButton(systemName: "plus")
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func iconButton(systemName: String, active: Bool = false) -> some View {
        ZStack {
            Circle()
                .fill(active ? Color(hex: "C4714B").opacity(0.2) : Color(hex: "2A2A2A"))
                .frame(width: 38, height: 38)
            Image(systemName: systemName)
                .font(.system(size: 16))
                .foregroundColor(active ? Color(hex: "C4714B") : Color(hex: "888888"))
        }
    }

    // MARK: - Main content

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
                        EditableFolderList { folder in
                            selectedFolderForNav = folder
                        }
                    } else {
                        DraggableFolderGrid { folder in
                            selectedFolderForNav = folder
                        }
                    }
                }

                // Loose files (not in any folder), skip the pinned top file
                let loose = filesManager.loosFiles
                let topID = filesManager.recentFiles.first?.id
                let looseRest = loose.filter { $0.id != topID }

                if !looseRest.isEmpty {
                    sectionLabel("Recent Files")
                    ForEach(looseRest) { file in
                        looseFileRow(file)
                    }
                }
            }
            .padding(.top, 4)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Rows

    private func pinnedFileRow(_ file: HTMLFile) -> some View {
        Button { selectedFile = file } label: {
            RecentFileRow(file: file)
        }
        .buttonStyle(.plain)
        .contextMenu { fileContextMenu(file) }
    }

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

    // MARK: - Helpers

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(Color(hex: "888888"))
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 6)
    }

    private func openDemo() {
        guard let url = Bundle.main.url(forResource: "test", withExtension: "html"),
              let bookmark = try? url.bookmarkData() else { return }
        selectedFile = HTMLFile(name: "test.html", bookmarkData: bookmark)
    }
}
