import Foundation

protocol AnalysisPresetManagingStorage: AnyObject {
    func listAnalysisPresets() throws -> [AnalysisPresetItem]
    func saveAnalysisPreset(name: String, draft: WorkspaceStateDraft) throws -> AnalysisPresetItem
    func deleteAnalysisPreset(presetID: String) throws
}

struct NativeAnalysisPresetRecord: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    let createdAt: String
    var updatedAt: String
    var workspaceSnapshot: NativePersistedWorkspaceSnapshot

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt
        case updatedAt
        case workspaceSnapshot
    }

    var item: AnalysisPresetItem {
        AnalysisPresetItem(
            id: id,
            name: name,
            createdAt: createdAt,
            updatedAt: updatedAt,
            snapshot: workspaceSnapshot.workspaceSnapshot
        )
    }
}

struct NativeAnalysisPresetStore {
    let fileManager: FileManager
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    let presetsURL: URL

    func loadPresets() throws -> [NativeAnalysisPresetRecord] {
        guard fileManager.fileExists(atPath: presetsURL.path) else { return [] }
        let data = try Data(contentsOf: presetsURL)
        guard !data.isEmpty else { return [] }
        return try decoder.decode([NativeAnalysisPresetRecord].self, from: data)
    }

    func savePresets(_ records: [NativeAnalysisPresetRecord]) throws {
        let directoryURL = presetsURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let data = try encoder.encode(records)
        try data.write(to: presetsURL, options: .atomic)
    }
}
