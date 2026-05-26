import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var filesManager: RecentFilesManager
    @Binding var pendingURL: URL?

    @State private var isShowingFilePicker = false
    @State private var selectedFile: HTMLFile?

    var body: some View {
        ZStack {
            Color(hex: "1A1A1A").ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.top, 8)

                if filesManager.recentFiles.isEmpty {
                    EmptyStateView(onOpenTapped: { isShowingFilePicker = true })
                } else {
                    recentsList
                }
            }
        }
        // File picker sheet
        .sheet(isPresented: $isShowingFilePicker) {
            DocumentPickerView { url in
                filesManager.addFile(url: url)
                // Open the file we just added
                selectedFile = filesManager.recentFiles.first
            }
        }
        // Full-screen HTML viewer
        .fullScreenCover(item: $selectedFile) { file in
            HTMLViewerView(file: file)
        }
        // Handle files opened from other apps (onOpenURL in App struct)
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

            Button(action: openDemo) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "2A2A2A"))
                        .frame(width: 44, height: 44)
                    Image(systemName: "doc.text")
                        .font(.system(size: 18))
                        .foregroundColor(Color(hex: "C4714B"))
                }
            }

            Button(action: { isShowingFilePicker = true }) {
                ZStack {
                    Circle()
                        .fill(Color(hex: "2A2A2A"))
                        .frame(width: 44, height: 44)

                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 20))
                        .foregroundColor(Color(hex: "C4714B"))
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private func openDemo() {
        guard let url = Bundle.main.url(forResource: "test", withExtension: "html"),
              let bookmark = try? url.bookmarkData() else { return }
        selectedFile = HTMLFile(name: "test.html", bookmarkData: bookmark)
    }

    // MARK: - Recents list

    private var recentsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filesManager.recentFiles) { file in
                    Button {
                        selectedFile = file
                    } label: {
                        RecentFileRow(file: file)
                    }
                    .buttonStyle(.plain)
                    // Subtle separator
                    .overlay(
                        Divider()
                            .background(Color(hex: "2A2A2A"))
                            .padding(.leading, 80),
                        alignment: .bottom
                    )
                    .contextMenu {
                        Button(role: .destructive) {
                            filesManager.removeFile(file)
                        } label: {
                            Label("Remove from Recents", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}
