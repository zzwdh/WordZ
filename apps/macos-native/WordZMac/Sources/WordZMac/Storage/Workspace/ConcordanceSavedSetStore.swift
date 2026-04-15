import Foundation

protocol ConcordanceSavedSetManagingStorage: AnyObject {
    func listConcordanceSavedSets() throws -> [ConcordanceSavedSet]
    func saveConcordanceSavedSet(_ set: ConcordanceSavedSet) throws -> ConcordanceSavedSet
    func deleteConcordanceSavedSet(setID: String) throws
}

struct NativeConcordanceSavedSetStore {
    let fileManager: FileManager
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    let setsURL: URL

    func loadSets() throws -> [ConcordanceSavedSet] {
        guard fileManager.fileExists(atPath: setsURL.path) else { return [] }
        let data = try Data(contentsOf: setsURL)
        guard !data.isEmpty else { return [] }
        return try decoder.decode([ConcordanceSavedSet].self, from: data)
    }

    func saveSets(_ sets: [ConcordanceSavedSet]) throws {
        let directoryURL = setsURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(sets)
        try data.write(to: setsURL, options: .atomic)
    }
}
