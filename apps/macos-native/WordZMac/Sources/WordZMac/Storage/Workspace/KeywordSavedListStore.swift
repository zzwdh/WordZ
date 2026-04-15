import Foundation

protocol KeywordSavedListManagingStorage: AnyObject {
    func listKeywordSavedLists() throws -> [KeywordSavedList]
    func saveKeywordSavedList(_ list: KeywordSavedList) throws -> KeywordSavedList
    func deleteKeywordSavedList(listID: String) throws
}

struct NativeKeywordSavedListStore {
    let fileManager: FileManager
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    let listsURL: URL

    func loadLists() throws -> [KeywordSavedList] {
        guard fileManager.fileExists(atPath: listsURL.path) else { return [] }
        let data = try Data(contentsOf: listsURL)
        guard !data.isEmpty else { return [] }
        return try decoder.decode([KeywordSavedList].self, from: data)
    }

    func saveLists(_ lists: [KeywordSavedList]) throws {
        let directoryURL = listsURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(lists)
        try data.write(to: listsURL, options: .atomic)
    }
}
