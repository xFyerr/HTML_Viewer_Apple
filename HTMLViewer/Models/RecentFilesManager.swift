import Foundation
import Combine

class RecentFilesManager: ObservableObject {
    @Published var recentFiles: [HTMLFile] = []

    private let storageKey = "recentHTMLFiles"
    private let maxCount = 20

    init() {
        load()
    }

    /// Creates a bookmark for the URL and prepends it to the recents list.
    /// Must be called while the caller holds security-scoped access (or for inbox URLs that don't need it).
    func addFile(url: URL) {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        guard let bookmark = try? url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }

        let displayName = url.deletingPathExtension().lastPathComponent

        // Remove any existing entry for the same file name so it bubbles to the top
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
        save()
    }

    // MARK: - Persistence

    private func save() {
        if let encoded = try? JSONEncoder().encode(recentFiles) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }

    private func load() {
        guard
            let data = UserDefaults.standard.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([HTMLFile].self, from: data)
        else { return }
        recentFiles = decoded
    }
}
