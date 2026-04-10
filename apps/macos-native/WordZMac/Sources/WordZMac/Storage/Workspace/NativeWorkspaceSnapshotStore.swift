import Foundation

struct NativeWorkspaceSnapshotStore {
    let fileManager: FileManager
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    let workspaceURL: URL
    let uiSettingsURL: URL

    func loadWorkspaceSnapshot() throws -> NativePersistedWorkspaceSnapshot {
        try readIfPresent(NativePersistedWorkspaceSnapshot.self, from: workspaceURL) ?? .empty
    }

    func saveWorkspaceSnapshot(_ snapshot: NativePersistedWorkspaceSnapshot) throws {
        try write(snapshot, to: workspaceURL)
    }

    func loadUISettings() throws -> NativePersistedUISettings {
        try readIfPresent(NativePersistedUISettings.self, from: uiSettingsURL) ?? .default
    }

    func saveUISettings(_ settings: NativePersistedUISettings) throws {
        try write(settings, to: uiSettingsURL)
    }

    private func readIfPresent<T: Decodable>(_ type: T.Type, from url: URL) throws -> T? {
        guard fileManager.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        return try decoder.decode(type, from: data)
    }

    private func write<T: Encodable>(_ value: T, to url: URL) throws {
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
    }
}
