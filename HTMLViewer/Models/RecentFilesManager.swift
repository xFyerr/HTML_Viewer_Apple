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
        for i in folders.indices {
            folders[i].fileIDs.removeAll { $0 == file.id }
        }
        save()
    }

    // MARK: - Folders

    func createFolder(name: String) {
        folders.append(Folder(name: name))
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

    func files(in folder: Folder) -> [HTMLFile] {
        folder.fileIDs.compactMap { id in recentFiles.first { $0.id == id } }
    }

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
