import Foundation

struct CorpusStorageMigrator {
    let fileManager: FileManager

    func migrateStorageFileNames(
        in corpora: inout [NativeCorpusRecord],
        directoryURL: URL
    ) throws -> Bool {
        var migrated = false
        for index in corpora.indices {
            let normalized = try migrateStorageFileNameIfNeeded(
                corpora[index].storageFileName,
                directoryURL: directoryURL
            )
            if normalized != corpora[index].storageFileName {
                corpora[index].storageFileName = normalized
                migrated = true
            }
        }
        return migrated
    }

    func migrateStorageFileNames(
        in entries: inout [NativeRecycleRecord],
        recycleDirectoryURL: URL
    ) throws -> Bool {
        var migrated = false
        for index in entries.indices {
            if try migrateStorageFileNames(in: &entries[index].corpora, directoryURL: recycleDirectoryURL) {
                migrated = true
            }
        }
        return migrated
    }

    private func migrateStorageFileNameIfNeeded(_ storageFileName: String, directoryURL: URL) throws -> String {
        let normalized = normalizedStorageFileName(for: storageFileName)
        guard normalized != storageFileName else {
            return storageFileName
        }

        let legacyURL = directoryURL.appendingPathComponent(storageFileName)
        let normalizedURL = directoryURL.appendingPathComponent(normalized)
        if fileManager.fileExists(atPath: legacyURL.path),
           !fileManager.fileExists(atPath: normalizedURL.path) {
            try fileManager.moveItem(at: legacyURL, to: normalizedURL)
        }
        return normalized
    }

    private func normalizedStorageFileName(for storageFileName: String) -> String {
        let storageURL = URL(fileURLWithPath: storageFileName)
        let stem = storageURL.deletingPathExtension().lastPathComponent
        return "\(stem).db"
    }
}

struct CorpusManifestStore {
    let fileManager: FileManager
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    let foldersURL: URL
    let corporaURL: URL
    let corpusSetsURL: URL
    let recycleURL: URL
    let corporaDirectoryURL: URL
    let recycleDirectoryURL: URL
    let migrator: CorpusStorageMigrator

    func loadFolders() throws -> [NativeFolderRecord] {
        try readIfPresent([NativeFolderRecord].self, from: foldersURL) ?? []
    }

    func saveFolders(_ folders: [NativeFolderRecord]) throws {
        try write(folders, to: foldersURL)
    }

    func loadCorpora() throws -> [NativeCorpusRecord] {
        var corpora = try readIfPresent([NativeCorpusRecord].self, from: corporaURL) ?? []
        if try migrator.migrateStorageFileNames(in: &corpora, directoryURL: corporaDirectoryURL) {
            try saveCorpora(corpora)
        }
        return corpora
    }

    func saveCorpora(_ corpora: [NativeCorpusRecord]) throws {
        try write(corpora, to: corporaURL)
    }

    func loadCorpusSets() throws -> [NativeCorpusSetRecord] {
        try readIfPresent([NativeCorpusSetRecord].self, from: corpusSetsURL) ?? []
    }

    func saveCorpusSets(_ corpusSets: [NativeCorpusSetRecord]) throws {
        try write(corpusSets, to: corpusSetsURL)
    }

    func loadRecycleEntries() throws -> [NativeRecycleRecord] {
        var entries = try readIfPresent([NativeRecycleRecord].self, from: recycleURL) ?? []
        if try migrator.migrateStorageFileNames(in: &entries, recycleDirectoryURL: recycleDirectoryURL) {
            try saveRecycleEntries(entries)
        }
        return entries
    }

    func saveRecycleEntries(_ entries: [NativeRecycleRecord]) throws {
        try write(entries, to: recycleURL)
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
