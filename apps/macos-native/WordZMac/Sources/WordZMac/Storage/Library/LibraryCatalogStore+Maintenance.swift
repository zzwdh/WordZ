import Foundation
import WordZStorage

extension LibraryCatalogStore {
    func backupDatabase(to destinationURL: URL) throws {
        try SQLiteDatabase.backupDatabase(
            from: databaseURL,
            to: destinationURL,
            configuration: configuration,
            fileManager: fileManager
        )
    }

    func storageSummary() throws -> StorageSummary {
        try withDatabase { db in
            StorageSummary(
                schemaVersion: try db.scalarInt("SELECT COALESCE(MAX(version), 0) FROM schema_migrations;"),
                folderCount: try db.scalarInt("SELECT COUNT(*) FROM library_folder;"),
                activeCorpusCount: try db.scalarInt("SELECT COUNT(*) FROM corpus WHERE storage_status != 'quarantined';"),
                quarantinedCorpusCount: try db.scalarInt("SELECT COUNT(*) FROM corpus WHERE storage_status = 'quarantined';"),
                corpusSetCount: try db.scalarInt("SELECT COUNT(*) FROM corpus_set;"),
                recycleEntryCount: try db.scalarInt("SELECT COUNT(*) FROM recycle_entry;"),
                pendingShardMigrationCount: try db.scalarInt(
                    """
                    SELECT COUNT(*)
                    FROM corpus
                    WHERE storage_status != 'quarantined'
                      AND (
                          migration_state != 'current'
                          OR storage_file_name NOT LIKE '%.db'
                          OR schema_version < \(NativeCorpusDatabaseSupport.currentSchemaVersion)
                      );
                    """
                )
            )
        }
    }
}
