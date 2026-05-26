import Foundation

struct Folder: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var fileIDs: [UUID]

    init(id: UUID = UUID(), name: String, fileIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.fileIDs = fileIDs
    }
}
