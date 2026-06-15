import Foundation
import WordZStorage

struct LibraryCatalogStore {
    struct StorageSummary: Equatable {
        let schemaVersion: Int
        let folderCount: Int
        let activeCorpusCount: Int
        let quarantinedCorpusCount: Int
        let corpusSetCount: Int
        let recycleEntryCount: Int
        let pendingShardMigrationCount: Int
    }

    struct CatalogProjection {
        let importedAt: String
        let tokenCount: Int
        let typeCount: Int
        let sentenceCount: Int
        let paragraphCount: Int
        let characterCount: Int
        let ttr: Double
        let sttr: Double
        let cleanedAt: String
        let cleaningProfileVersion: String
        let originalCharacterCount: Int
        let cleanedCharacterCount: Int
        let cleanedTextDigest: String
        let storageStatus: String
        let migrationState: String
        let schemaVersion: Int
        let checksumSHA256: String
    }

    struct QuarantinedCorpusEntry {
        let record: NativeCorpusRecord
        let integrityNote: String
        let quarantineURL: URL
    }

    let fileManager: FileManager
    let encoder: JSONEncoder
    let decoder: JSONDecoder
    let databaseURL: URL
    let corporaDirectoryURL: URL

    let configuration = SQLiteDatabaseConfiguration.libraryCatalog
    let schemaVersion = 3

    func schemaVersionSummary() -> Int {
        schemaVersion
    }

    func withDatabase<T>(_ body: (SQLiteDatabase) throws -> T) throws -> T {
        let database = try SQLiteDatabase(url: databaseURL, configuration: configuration)
        return try body(database)
    }
}
