import Foundation

struct HTMLFile: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let bookmarkData: Data
    var lastOpened: Date

    init(id: UUID = UUID(), name: String, bookmarkData: Data, lastOpened: Date = Date()) {
        self.id = id
        self.name = name
        self.bookmarkData = bookmarkData
        self.lastOpened = lastOpened
    }

    /// Resolves the stored bookmark back to a live URL.
    /// Returns nil if the file has been deleted or moved.
    func resolveURL() -> URL? {
        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        return url
    }
}
