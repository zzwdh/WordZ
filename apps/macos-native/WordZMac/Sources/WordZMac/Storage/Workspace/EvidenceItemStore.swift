import Foundation

protocol EvidenceItemManagingStorage: AnyObject {
    func listEvidenceItems() throws -> [EvidenceItem]
    func saveEvidenceItem(_ item: EvidenceItem) throws -> EvidenceItem
    func deleteEvidenceItem(itemID: String) throws
    func replaceEvidenceItems(_ items: [EvidenceItem]) throws
}

struct NativeEvidenceItemStore {
    let fileManager: FileManager
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    let itemsURL: URL

    func loadItems() throws -> [EvidenceItem] {
        guard fileManager.fileExists(atPath: itemsURL.path) else { return [] }
        let data = try Data(contentsOf: itemsURL)
        guard !data.isEmpty else { return [] }
        return try decoder.decode([EvidenceItem].self, from: data)
    }

    func saveItems(_ items: [EvidenceItem]) throws {
        let directoryURL = itemsURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(items)
        try data.write(to: itemsURL, options: .atomic)
    }
}
