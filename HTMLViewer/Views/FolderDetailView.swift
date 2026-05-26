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
