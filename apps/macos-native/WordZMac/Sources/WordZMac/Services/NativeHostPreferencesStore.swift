import Foundation

@MainActor
protocol NativeHostPreferencesStoring: AnyObject {
    func load() -> NativeHostPreferencesSnapshot
    func save(_ snapshot: NativeHostPreferencesSnapshot) throws
    func recordRecentDocument(
        corpusID: String,
        title: String,
        subtitle: String,
        representedPath: String
    ) throws -> NativeHostPreferencesSnapshot
    func clearRecentDocuments() throws -> NativeHostPreferencesSnapshot
    func recordUpdateCheck(status: String) throws -> NativeHostPreferencesSnapshot
    func recordDownloadedUpdate(version: String, name: String, path: String) throws -> NativeHostPreferencesSnapshot
    func clearDownloadedUpdate() throws -> NativeHostPreferencesSnapshot
}

@MainActor
final class NativeHostPreferencesStore: NativeHostPreferencesStoring {
    private let fileURL: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? NativeHostPreferencesStore.defaultFileURL()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    }

    func load() -> NativeHostPreferencesSnapshot {
        guard let data = try? Data(contentsOf: fileURL) else {
            return .default
        }
        return (try? decoder.decode(NativeHostPreferencesSnapshot.self, from: data)) ?? .default
    }

    func save(_ snapshot: NativeHostPreferencesSnapshot) throws {
        try ensureParentDirectory()
        let data = try encoder.encode(snapshot)
        try data.write(to: fileURL, options: .atomic)
    }

    @discardableResult
    func recordRecentDocument(
        corpusID: String,
        title: String,
        subtitle: String,
        representedPath: String
    ) throws -> NativeHostPreferencesSnapshot {
        var snapshot = load()
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let item = RecentDocumentItem(
            corpusID: corpusID,
            title: title,
            subtitle: subtitle,
            representedPath: representedPath,
            lastOpenedAt: timestamp
        )
        snapshot.recentDocuments.removeAll { $0.corpusID == corpusID }
        snapshot.recentDocuments.insert(item, at: 0)
        snapshot.recentDocuments = Array(snapshot.recentDocuments.prefix(8))
        try save(snapshot)
        return snapshot
    }

    @discardableResult
    func clearRecentDocuments() throws -> NativeHostPreferencesSnapshot {
        var snapshot = load()
        snapshot.recentDocuments = []
        try save(snapshot)
        return snapshot
    }

    @discardableResult
    func recordUpdateCheck(status: String) throws -> NativeHostPreferencesSnapshot {
        var snapshot = load()
        snapshot.lastUpdateCheckAt = ISO8601DateFormatter().string(from: Date())
        snapshot.lastUpdateStatus = status
        try save(snapshot)
        return snapshot
    }

    @discardableResult
    func recordDownloadedUpdate(version: String, name: String, path: String) throws -> NativeHostPreferencesSnapshot {
        var snapshot = load()
        snapshot.downloadedUpdateVersion = version
        snapshot.downloadedUpdateName = name
        snapshot.downloadedUpdatePath = path
        try save(snapshot)
        return snapshot
    }

    @discardableResult
    func clearDownloadedUpdate() throws -> NativeHostPreferencesSnapshot {
        var snapshot = load()
        snapshot.downloadedUpdateVersion = ""
        snapshot.downloadedUpdateName = ""
        snapshot.downloadedUpdatePath = ""
        try save(snapshot)
        return snapshot
    }

    static func defaultFileURL() -> URL {
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let baseURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                .appendingPathComponent("WordZMacTests", isDirectory: true)
            return baseURL.appendingPathComponent("native-host-preferences-\(UUID().uuidString).json")
        }
        let baseURL = EnginePaths.defaultUserDataURL()
        return baseURL.appendingPathComponent("native-host-preferences.json")
    }

    private func ensureParentDirectory() throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }
}
