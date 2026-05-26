import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var filesManager: RecentFilesManager
    @Binding var pendingURL: URL?

    @AppStorage("viewMode") private var viewMode: String = ViewMode.list.rawValue
    @State private var isShowingFilePicker   = false
    @State private var isShowingCreateFolder = false
    @State private var selectedFile: HTMLFile?
    @State private var selectedFolderForNav: Folder?

    private var currentMode: ViewMode { ViewMode(rawValue: viewMode) ?? .list }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(hex: "1A1A1A").ignoresSafeArea()

                VStack(alignment: .leading, spacing: 0) {
                    header.padding(.top, 8)

                    if filesManager.homeOrder.isEmpty {
                        EmptyStateView(onOpenTapped: { isShowingFilePicker = true })
                    } else {
                        ScrollView {
                            if currentMode == .list {
                                EditableFolderList(
                                    onSelectFolder: { selectedFolderForNav = $0 },
                                    onSelectFile:   { selectedFile = $0 }
                                )
                            } else {
                                DraggableFolderGrid(
                                    onSelectFolder: { selectedFolderForNav = $0 },
                                    onSelectFile:   { selectedFile = $0 }
                                )
                                .padding(.bottom, 20)
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(isPresented: Binding(
                get: { selectedFolderForNav != nil },
                set: { if !$0 { selectedFolderForNav = nil } }
            )) {
                if let folder = selectedFolderForNav {
                    FolderDetailView(folder: folder).environmentObject(filesManager)
                }
            }
        }
        .sheet(isPresented: $isShowingFilePicker) {
            DocumentPickerView { url in
                filesManager.addFile(url: url)
                selectedFile = filesManager.recentFiles.first
            }
        }
        .sheet(isPresented: $isShowingCreateFolder) {
            CreateFolderSheet { name in filesManager.createFolder(name: name) }
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

            // Button(action: openDemo) { iconButton(systemName: "doc.text") }

            Button { viewMode = ViewMode.grid.rawValue } label: {
                iconButton(systemName: "square.grid.2x2", active: currentMode == .grid)
            }
            Button { viewMode = ViewMode.list.rawValue } label: {
                iconButton(systemName: "list.bullet", active: currentMode == .list)
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

    private func openDemo() {
        guard let url = Bundle.main.url(forResource: "test", withExtension: "html"),
              let bookmark = try? url.bookmarkData() else { return }
        selectedFile = HTMLFile(name: "test.html", bookmarkData: bookmark)
    }
}
