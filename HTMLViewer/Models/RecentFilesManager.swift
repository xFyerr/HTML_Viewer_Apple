import Foundation
import Combine

// Represents one slot on the home screen: either a loose file or a folder.
enum HomeItemRef: Codable, Hashable {
    case file(UUID)
    case folder(UUID)

    var id: UUID {
        switch self { case .file(let id), .folder(let id): return id }
    }

    // Serialised as "file:<uuid>" or "folder:<uuid>" for drag-and-drop
    var dragString: String {
        switch self {
        case .file(let id):   return "file:\(id.uuidString)"
        case .folder(let id): return "folder:\(id.uuidString)"
        }
    }

    static func from(_ dragString: String) -> HomeItemRef? {
        let parts = dragString.split(separator: ":", maxSplits: 1)
        guard parts.count == 2, let id = UUID(uuidString: String(parts[1])) else { return nil }
        return parts[0] == "folder" ? .folder(id) : .file(id)
    }

    // MARK: Codable
    private enum CodingKeys: String, CodingKey { case type, id }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let id = try c.decode(UUID.self, forKey: .id)
        self = (try c.decode(String.self, forKey: .type)) == "folder" ? .folder(id) : .file(id)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .file(let id):   try c.encode("file",   forKey: .type); try c.encode(id, forKey: .id)
        case .folder(let id): try c.encode("folder", forKey: .type); try c.encode(id, forKey: .id)
        }
    }
}

class RecentFilesManager: ObservableObject {
    @Published var recentFiles: [HTMLFile] = []
    @Published var folders: [Folder] = []
    /// Ordered items on the home screen (loose files + folders, no duplicates).
    @Published var homeOrder: [HomeItemRef] = []

    private let filesKey     = "recentHTMLFiles"
    private let foldersKey   = "htmlViewerFolders"
    private let homeOrderKey = "htmlViewerHomeOrder"
    private let maxCount     = 50

    init() { load() }

    // MARK: - Files

    func addFile(url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        guard let bookmark = try? url.bookmarkData(
            options: [], includingResourceValuesForKeys: nil, relativeTo: nil
        ) else { return }

        let displayName = url.deletingPathExtension().lastPathComponent

        // Reuse existing UUID so folder membership and homeOrder refs survive reopens
        let existingID = recentFiles.first(where: { $0.name == displayName })?.id ?? UUID()
        recentFiles.removeAll { $0.name == displayName }

        let file = HTMLFile(id: existingID, name: displayName, bookmarkData: bookmark)
        recentFiles.insert(file, at: 0)
        if recentFiles.count > maxCount { recentFiles = Array(recentFiles.prefix(maxCount)) }

        // If file is loose (not in any folder), pin it to top of home screen
        let inFolder = folders.contains { $0.fileIDs.contains(file.id) }
        if !inFolder {
            homeOrder.removeAll { $0 == .file(file.id) }
            homeOrder.insert(.file(file.id), at: 0)
        }
        save()
    }

    func removeFile(_ file: HTMLFile) {
        recentFiles.removeAll { $0.id == file.id }
        homeOrder.removeAll  { $0 == .file(file.id) }
        for i in folders.indices { folders[i].fileIDs.removeAll { $0 == file.id } }
        save()
    }

    // MARK: - Folders

    func createFolder(name: String) {
        let folder = Folder(name: name)
        folders.append(folder)
        homeOrder.append(.folder(folder.id))
        save()
    }

    func deleteFolder(_ folder: Folder) {
        // Return folder's files to homeOrder as loose files
        let orphans = folder.fileIDs.compactMap { id in recentFiles.first { $0.id == id } }
        folders.removeAll { $0.id == folder.id }
        homeOrder.removeAll { $0 == .folder(folder.id) }
        for file in orphans.reversed() {
            homeOrder.removeAll { $0 == .file(file.id) }
            homeOrder.insert(.file(file.id), at: 0)
        }
        save()
    }

    func renameFolder(_ folder: Folder, to name: String) {
        guard let i = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[i].name = name
        save()
    }

    func addFile(_ file: HTMLFile, toFolder folder: Folder) {
        guard let fi = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        // Remove from all other folders first
        for i in folders.indices { folders[i].fileIDs.removeAll { $0 == file.id } }
        folders[fi].fileIDs.removeAll { $0 == file.id }
        folders[fi].fileIDs.insert(file.id, at: 0)
        // Remove from home screen
        homeOrder.removeAll { $0 == .file(file.id) }
        save()
    }

    func removeFile(_ file: HTMLFile, fromFolder folder: Folder) {
        guard let fi = folders.firstIndex(where: { $0.id == folder.id }) else { return }
        folders[fi].fileIDs.removeAll { $0 == file.id }
        // Return to home screen at top
        homeOrder.removeAll { $0 == .file(file.id) }
        homeOrder.insert(.file(file.id), at: 0)
        save()
    }

    func files(in folder: Folder) -> [HTMLFile] {
        folder.fileIDs.compactMap { id in recentFiles.first { $0.id == id } }
    }

    // MARK: - Home ordering

    /// Move `item` to just before `target` in homeOrder. Used by drag-to-reorder.
    func moveItem(_ item: HomeItemRef, before target: HomeItemRef) {
        guard item != target,
              homeOrder.contains(item),
              let targetIndex = homeOrder.firstIndex(of: target) else { return }
        homeOrder.removeAll { $0 == item }
        let adjusted = homeOrder.firstIndex(of: target) ?? homeOrder.endIndex
        homeOrder.insert(item, at: adjusted)
        save()
    }

    /// Move `item` to end of homeOrder.
    func moveItemToEnd(_ item: HomeItemRef) {
        homeOrder.removeAll { $0 == item }
        homeOrder.append(item)
        save()
    }

    // MARK: - Persistence

    private func save() {
        if let d = try? JSONEncoder().encode(recentFiles)  { UserDefaults.standard.set(d, forKey: filesKey) }
        if let d = try? JSONEncoder().encode(folders)      { UserDefaults.standard.set(d, forKey: foldersKey) }
        if let d = try? JSONEncoder().encode(homeOrder)    { UserDefaults.standard.set(d, forKey: homeOrderKey) }
    }

    private func load() {
        if let d = UserDefaults.standard.data(forKey: filesKey),
           let v = try? JSONDecoder().decode([HTMLFile].self, from: d)       { recentFiles = v }
        if let d = UserDefaults.standard.data(forKey: foldersKey),
           let v = try? JSONDecoder().decode([Folder].self, from: d)         { folders = v }
        if let d = UserDefaults.standard.data(forKey: homeOrderKey),
           let v = try? JSONDecoder().decode([HomeItemRef].self, from: d)    { homeOrder = v }
        else { rebuildHomeOrder() }  // first launch: build from existing data
    }

    /// Builds homeOrder from scratch (migration / first run).
    private func rebuildHomeOrder() {
        let folderFileIDs = Set(folders.flatMap { $0.fileIDs })
        let looseFiles = recentFiles.filter { !folderFileIDs.contains($0.id) }.map { HomeItemRef.file($0.id) }
        let folderRefs = folders.map { HomeItemRef.folder($0.id) }
        homeOrder = looseFiles + folderRefs
    }
}
