import SQLite3
import XCTest
@testable import WordZWorkspaceCore

private final class CancellationFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var value = false

    func set() {
        lock.lock()
        value = true
        lock.unlock()
    }

    func isSet() -> Bool {
        lock.lock()
        let snapshot = value
        lock.unlock()
        return snapshot
    }
}

final class NativeCorpusStoreMaintenanceTests: XCTestCase {
    func testBackupLibraryRejectsDestinationInsideRoot() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-backup")
        let destinationURL = rootURL.appendingPathComponent("exports", isDirectory: true)
        try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()

        XCTAssertThrowsError(try store.backupLibrary(destinationPath: destinationURL.path)) { error in
            XCTAssertTrue(error.localizedDescription.contains("备份目录不能位于当前语料库目录内部"))
        }
        let createdBackupDirectories = (try? fileManager.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil)) ?? []
        XCTAssertTrue(createdBackupDirectories.isEmpty)
    }

    func testRepairLibraryMovesUnreadableStorageIntoQuarantineDirectory() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-repair")
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try "alpha beta gamma".write(to: sourceURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)
        let corpus = try XCTUnwrap(imported.importedItems.first)
        let record = try XCTUnwrap(store.loadCorpora().first(where: { $0.id == corpus.id }))
        let storageURL = store.corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        try fileManager.setAttributes([.posixPermissions: 0], ofItemAtPath: storageURL.path)

        let summary = try store.repairLibrary()

        XCTAssertEqual(summary.checkedCorpora, 1)
        XCTAssertEqual(summary.repairedCorpora, 1)
        XCTAssertEqual(summary.quarantinedCorpora, 1)
        XCTAssertTrue(summary.repairedManifest)
        XCTAssertTrue(try store.loadCorpora().isEmpty)
        XCTAssertTrue(try store.listLibrary(folderId: "all").corpora.isEmpty)
        XCTAssertFalse(fileManager.fileExists(atPath: storageURL.path))

        let quarantineURL = URL(fileURLWithPath: summary.quarantineDir, isDirectory: true)
        let quarantinedFileURL = quarantineURL.appendingPathComponent(record.storageFileName)
        XCTAssertTrue(fileManager.fileExists(atPath: quarantinedFileURL.path))
        XCTAssertTrue(quarantineURL.lastPathComponent.hasPrefix("repair-quarantine-"))
        XCTAssertEqual(
            try sqliteScalarInt(
                "SELECT COUNT(*) FROM corpus WHERE storage_status = 'quarantined';",
                databaseURL: rootURL.appendingPathComponent("library.db")
            ),
            1
        )
        XCTAssertEqual(
            try sqliteScalarInt(
                """
                SELECT COUNT(*)
                FROM corpus
                WHERE id = '\(record.id)'
                  AND integrity_note LIKE 'repair-quarantine:%';
                """,
                databaseURL: rootURL.appendingPathComponent("library.db")
            ),
            1
        )
    }

    func testRestoreLibraryRejectsSourceInsideCurrentRootAndPreservesLibraryState() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-restore")
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try "alpha beta gamma".write(to: sourceURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)
        let corpus = try XCTUnwrap(imported.importedItems.first)
        let nestedBackupURL = rootURL.appendingPathComponent("nested-backup", isDirectory: true)
        try fileManager.createDirectory(at: nestedBackupURL, withIntermediateDirectories: true)

        let beforeSnapshot = try store.listLibrary(folderId: "all")
        XCTAssertThrowsError(try store.restoreLibrary(sourcePath: nestedBackupURL.path)) { error in
            XCTAssertTrue(error.localizedDescription.contains("恢复源目录不能位于当前语料库目录内部"))
        }

        let afterSnapshot = try store.listLibrary(folderId: "all")
        XCTAssertEqual(afterSnapshot.corpora.count, beforeSnapshot.corpora.count)
        XCTAssertEqual(afterSnapshot.corpora.first?.id, corpus.id)
        XCTAssertEqual(afterSnapshot.corpora.first?.name, corpus.name)
    }

    func testBackupLibraryWritesCentralDatabasesWithoutSidecars() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-backup-central-db")
        let exportURL = temporaryDirectory(named: "wordz-library-backup-export")
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: exportURL, withIntermediateDirectories: true)
        try "alpha beta gamma".write(to: sourceURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)
        let record = try XCTUnwrap(store.loadCorpora().first(where: { $0.id == imported.importedItems.first?.id }))

        let summary = try store.backupLibrary(destinationPath: exportURL.path)
        let backupURL = URL(fileURLWithPath: summary.backupDir, isDirectory: true)

        XCTAssertEqual(summary.librarySchemaVersion, store.libraryCatalogStore.schemaVersionSummary())
        XCTAssertEqual(summary.workspaceSchemaVersion, store.workspaceDatabaseStore.schemaVersionSummary())
        XCTAssertEqual(summary.pendingShardMigrationCount, 0)
        XCTAssertEqual(summary.quarantinedCorpusCount, 0)
        XCTAssertEqual(summary.corpusSetCount, 0)
        XCTAssertEqual(summary.recycleEntryCount, 0)
        XCTAssertTrue(fileManager.fileExists(atPath: backupURL.appendingPathComponent("library.db").path))
        XCTAssertTrue(fileManager.fileExists(atPath: backupURL.appendingPathComponent("workspace.db").path))
        XCTAssertFalse(fileManager.fileExists(atPath: URL(fileURLWithPath: backupURL.appendingPathComponent("library.db").path + "-wal").path))
        XCTAssertFalse(fileManager.fileExists(atPath: URL(fileURLWithPath: backupURL.appendingPathComponent("library.db").path + "-shm").path))
        XCTAssertFalse(fileManager.fileExists(atPath: URL(fileURLWithPath: backupURL.appendingPathComponent("workspace.db").path + "-wal").path))
        XCTAssertFalse(fileManager.fileExists(atPath: URL(fileURLWithPath: backupURL.appendingPathComponent("workspace.db").path + "-shm").path))
        XCTAssertEqual(
            try sqliteScalarInt(
                "SELECT COUNT(*) FROM corpus;",
                databaseURL: backupURL.appendingPathComponent("library.db")
            ),
            1
        )
        XCTAssertEqual(
            try sqliteScalarInt(
                "SELECT COUNT(*) FROM workspace_snapshot;",
                databaseURL: backupURL.appendingPathComponent("workspace.db")
            ),
            1
        )
        XCTAssertTrue(
            fileManager.fileExists(
                atPath: backupURL
                    .appendingPathComponent("corpora", isDirectory: true)
                    .appendingPathComponent(record.storageFileName)
                    .path
            )
        )
    }

    func testRestoreLibraryRestoresCentralDatabasesAndWorkspaceState() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-restore-central-db")
        let backupRootURL = temporaryDirectory(named: "wordz-library-restore-backup")
        let firstURL = rootURL.appendingPathComponent("first.txt")
        let secondURL = rootURL.appendingPathComponent("second.txt")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: backupRootURL, withIntermediateDirectories: true)
        try "alpha beta gamma".write(to: firstURL, atomically: true, encoding: .utf8)
        try "delta epsilon zeta".write(to: secondURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let firstImported = try store.importCorpusPaths([firstURL.path], folderId: "", preserveHierarchy: false)
        let firstCorpus = try XCTUnwrap(firstImported.importedItems.first)
        try store.saveWorkspaceSnapshot(
            WorkspaceStateDraft(
                currentTab: WorkspaceDetailTab.keyword.snapshotValue,
                currentLibraryFolderId: "all",
                corpusIds: [firstCorpus.id],
                corpusNames: [firstCorpus.name],
                searchQuery: "restore-me",
                searchOptions: .default,
                stopwordFilter: .default,
                ngramSize: "2",
                ngramPageSize: "10",
                kwicLeftWindow: "5",
                kwicRightWindow: "5",
                collocateLeftWindow: "5",
                collocateRightWindow: "5",
                collocateMinFreq: "1",
                topicsMinTopicSize: "2",
                topicsIncludeOutliers: true,
                topicsPageSize: "50",
                topicsActiveTopicID: "",
                chiSquareA: "",
                chiSquareB: "",
                chiSquareC: "",
                chiSquareD: "",
                chiSquareUseYates: false
            )
        )

        let backup = try store.backupLibrary(destinationPath: backupRootURL.path)

        _ = try store.importCorpusPaths([secondURL.path], folderId: "", preserveHierarchy: false)
        try store.saveWorkspaceSnapshot(
            WorkspaceStateDraft(
                currentTab: WorkspaceDetailTab.sentiment.snapshotValue,
                currentLibraryFolderId: "all",
                corpusIds: [],
                corpusNames: [],
                searchQuery: "mutated",
                searchOptions: .default,
                stopwordFilter: .default,
                ngramSize: "2",
                ngramPageSize: "10",
                kwicLeftWindow: "5",
                kwicRightWindow: "5",
                collocateLeftWindow: "5",
                collocateRightWindow: "5",
                collocateMinFreq: "1",
                topicsMinTopicSize: "2",
                topicsIncludeOutliers: true,
                topicsPageSize: "50",
                topicsActiveTopicID: "",
                chiSquareA: "",
                chiSquareB: "",
                chiSquareC: "",
                chiSquareD: "",
                chiSquareUseYates: false
            )
        )

        let summary = try store.restoreLibrary(sourcePath: backup.backupDir)

        XCTAssertEqual(summary.restoredFromDir, backup.backupDir)
        XCTAssertEqual(summary.librarySchemaVersion, store.libraryCatalogStore.schemaVersionSummary())
        XCTAssertEqual(summary.workspaceSchemaVersion, store.workspaceDatabaseStore.schemaVersionSummary())
        XCTAssertEqual(summary.pendingShardMigrationCount, 0)
        XCTAssertEqual(summary.quarantinedCorpusCount, 0)
        XCTAssertEqual(summary.corpusSetCount, 0)
        XCTAssertEqual(summary.recycleEntryCount, 0)
        let restoredSnapshot = try store.listLibrary(folderId: "all")
        XCTAssertEqual(restoredSnapshot.corpora.map(\.id), [firstCorpus.id])
        XCTAssertEqual(try store.loadWorkspaceSnapshot().searchQuery, "restore-me")
    }

    func testRestoreLibraryRollsBackWhenCentralDatabaseFilesAreCorrupted() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-restore-corrupt-central-db")
        let corruptBackupURL = temporaryDirectory(named: "wordz-library-corrupt-backup")
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: corruptBackupURL, withIntermediateDirectories: true)
        try "alpha beta gamma".write(to: sourceURL, atomically: true, encoding: .utf8)
        try "not a sqlite database".write(
            to: corruptBackupURL.appendingPathComponent("library.db"),
            atomically: true,
            encoding: .utf8
        )
        try "also not a sqlite database".write(
            to: corruptBackupURL.appendingPathComponent("workspace.db"),
            atomically: true,
            encoding: .utf8
        )

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)
        let corpus = try XCTUnwrap(imported.importedItems.first)
        try store.saveWorkspaceSnapshot(
            WorkspaceStateDraft(
                currentTab: WorkspaceDetailTab.keyword.snapshotValue,
                currentLibraryFolderId: "all",
                corpusIds: [corpus.id],
                corpusNames: [corpus.name],
                searchQuery: "before-corrupt-restore",
                searchOptions: .default,
                stopwordFilter: .default,
                ngramSize: "2",
                ngramPageSize: "10",
                kwicLeftWindow: "5",
                kwicRightWindow: "5",
                collocateLeftWindow: "5",
                collocateRightWindow: "5",
                collocateMinFreq: "1",
                topicsMinTopicSize: "2",
                topicsIncludeOutliers: true,
                topicsPageSize: "50",
                topicsActiveTopicID: "",
                chiSquareA: "",
                chiSquareB: "",
                chiSquareC: "",
                chiSquareD: "",
                chiSquareUseYates: false
            )
        )

        XCTAssertThrowsError(try store.restoreLibrary(sourcePath: corruptBackupURL.path))

        let restoredSnapshot = try store.listLibrary(folderId: "all")
        XCTAssertEqual(restoredSnapshot.corpora.map(\.id), [corpus.id])
        XCTAssertEqual(restoredSnapshot.corpora.first?.name, corpus.name)
        XCTAssertEqual(try store.loadWorkspaceSnapshot().searchQuery, "before-corrupt-restore")
        XCTAssertEqual(
            try sqliteScalarInt(
                "SELECT COUNT(*) FROM corpus;",
                databaseURL: rootURL.appendingPathComponent("library.db")
            ),
            1
        )
        XCTAssertEqual(
            try sqliteScalarInt(
                "SELECT COUNT(*) FROM workspace_snapshot;",
                databaseURL: rootURL.appendingPathComponent("workspace.db")
            ),
            1
        )
    }

    func testLegacyTextShardMigratesToCanonicalDatabaseFileAndRefreshesCatalog() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-legacy-shard")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()

        let legacyRecord = NativeCorpusRecord(
            id: "legacy-corpus",
            name: "Legacy Corpus",
            folderId: "",
            folderName: "未分类",
            sourceType: "txt",
            representedPath: "/tmp/legacy-corpus.txt",
            storageFileName: "legacy-corpus.txt",
            metadata: .empty
        )
        let legacyStorageURL = store.corporaDirectoryURL.appendingPathComponent(legacyRecord.storageFileName)
        try fileManager.createDirectory(at: store.corporaDirectoryURL, withIntermediateDirectories: true)
        try "legacy alpha beta".write(to: legacyStorageURL, atomically: true, encoding: .utf8)
        try store.saveCorpora([legacyRecord])

        let opened = try store.openSavedCorpus(corpusId: legacyRecord.id)
        let migratedRecord = try XCTUnwrap(store.loadCorpora().first)
        let migratedStorageURL = store.corporaDirectoryURL.appendingPathComponent(migratedRecord.storageFileName)

        XCTAssertEqual(opened.content, "legacy alpha beta")
        XCTAssertEqual(migratedRecord.storageFileName, "legacy-corpus.db")
        XCTAssertFalse(fileManager.fileExists(atPath: legacyStorageURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: migratedStorageURL.path))
        XCTAssertEqual(
            try sqliteScalarInt(
                """
                SELECT COUNT(*)
                FROM corpus
                WHERE id = 'legacy-corpus'
                  AND storage_file_name = 'legacy-corpus.db'
                  AND migration_state = 'current'
                  AND schema_version = \(NativeCorpusDatabaseSupport.currentSchemaVersion);
                """,
                databaseURL: rootURL.appendingPathComponent("library.db")
            ),
            1
        )
    }

    func testProgressImportCancellationRollsBackManifestAndStagingFiles() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-import-cancel")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let firstURL = rootURL.appendingPathComponent("first.txt")
        let secondURL = rootURL.appendingPathComponent("second.txt")
        try "alpha beta gamma".write(to: firstURL, atomically: true, encoding: .utf8)
        try "delta epsilon zeta".write(to: secondURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()

        let shouldCancel = CancellationFlag()
        XCTAssertThrowsError(
            try store.importCorpusPaths(
                [firstURL.path, secondURL.path],
                folderId: "",
                preserveHierarchy: false,
                progress: { snapshot in
                    if snapshot.phase == .importing, snapshot.completedCount >= 1 {
                        shouldCancel.set()
                    }
                },
                isCancelled: { shouldCancel.isSet() }
            )
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }

        XCTAssertTrue(try store.listLibrary(folderId: "all").corpora.isEmpty)
        let remainingRootEntries = try fileManager.contentsOfDirectory(at: rootURL, includingPropertiesForKeys: nil)
        XCTAssertFalse(remainingRootEntries.contains(where: { $0.lastPathComponent.hasPrefix("import-staging-") }))
    }

    func testProgressImportCollectsFailureItemsForSkippedFiles() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-import-failures")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let textURL = rootURL.appendingPathComponent("sample.txt")
        let imageURL = rootURL.appendingPathComponent("sample.png")
        try "alpha beta gamma".write(to: textURL, atomically: true, encoding: .utf8)
        try Data([0x89, 0x50, 0x4E, 0x47, 0x00]).write(to: imageURL, options: .atomic)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let result = try store.importCorpusPaths(
            [textURL.path, imageURL.path],
            folderId: "",
            preserveHierarchy: false,
            progress: nil,
            isCancelled: nil
        )

        XCTAssertEqual(result.importedCount, 1)
        XCTAssertEqual(result.skippedCount, 1)
        XCTAssertEqual(result.failureItems.count, 1)
        XCTAssertEqual(result.failureItems.first?.fileName, "sample.png")
        XCTAssertTrue(result.failureItems.first?.reason.contains("暂不支持") == true)
    }

    func testImportCorpusPathsStoresRawTextAndCleanedContent() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-auto-cleaning-import")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        let rawText = "\u{FEFF}\nAlpha\u{00A0}Beta\t\u{200B}\r\nLine\u{0000} two  \n\n"
        try rawText.write(to: sourceURL, atomically: true, encoding: .utf8)

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let result = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)

        let corpus = try XCTUnwrap(result.importedItems.first)
        XCTAssertEqual(result.cleaningSummary.cleanedCount, 1)
        XCTAssertEqual(result.cleaningSummary.changedCount, 1)
        XCTAssertEqual(corpus.cleaningStatus, .cleanedWithChanges)

        let opened = try store.openSavedCorpus(corpusId: corpus.id)
        XCTAssertEqual(opened.content, "Alpha Beta\nLine two")

        let record = try XCTUnwrap(store.loadCorpora().first(where: { $0.id == corpus.id }))
        let storageURL = store.corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        let storedDocument = try XCTUnwrap(NativeCorpusDatabaseSupport.readDocument(at: storageURL))
        XCTAssertEqual(storedDocument.rawText, rawText)
        XCTAssertEqual(storedDocument.text, "Alpha Beta\nLine two")
    }

    func testCleanCorporaReusesStoredRawTextAndReportsChanges() throws {
        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-library-auto-cleaning-rerun")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let sourceURL = rootURL.appendingPathComponent("sample.txt")
        try "\u{FEFF}\nAlpha\u{00A0}Beta\t\u{200B}\r\nLine\u{0000} two  \n\n".write(
            to: sourceURL,
            atomically: true,
            encoding: .utf8
        )

        let store = NativeCorpusStore(rootURL: rootURL)
        try store.ensureInitialized()
        let imported = try store.importCorpusPaths([sourceURL.path], folderId: "", preserveHierarchy: false)
        let corpus = try XCTUnwrap(imported.importedItems.first)

        let result = try store.cleanCorpora(corpusIds: [corpus.id])

        XCTAssertEqual(result.requestedCount, 1)
        XCTAssertEqual(result.cleanedCount, 1)
        XCTAssertEqual(result.changedCount, 1)
        XCTAssertEqual(result.cleanedItems.first?.id, corpus.id)
        XCTAssertEqual(result.cleanedItems.first?.cleaningStatus, .cleanedWithChanges)
        XCTAssertEqual(try store.openSavedCorpus(corpusId: corpus.id).content, "Alpha Beta\nLine two")
    }

    func testStorageMutationCoordinatorRollsBackDatabaseSnapshotAndMovedFiles() throws {
        enum ExpectedFailure: Error {
            case forced
        }

        let fileManager = FileManager.default
        let rootURL = temporaryDirectory(named: "wordz-storage-mutation-coordinator")
        try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

        let databaseURL = rootURL.appendingPathComponent("library.db")
        let sourceFileURL = rootURL.appendingPathComponent("source.txt")
        let destinationFileURL = rootURL.appendingPathComponent("nested/destination.txt")
        try "rollback me".write(to: sourceFileURL, atomically: true, encoding: .utf8)

        let database = try SQLiteDatabase(url: databaseURL, configuration: .libraryCatalog)
        try database.execute(
            """
            CREATE TABLE IF NOT EXISTS demo_item (
                id INTEGER PRIMARY KEY,
                name TEXT NOT NULL
            );
            """
        )
        try database.execute("DELETE FROM demo_item;")
        try database.execute("INSERT INTO demo_item (id, name) VALUES (1, 'before');")

        let coordinator = StorageMutationCoordinator(fileManager: fileManager, stagingRootURL: rootURL)
        XCTAssertThrowsError(
            try coordinator.perform { transaction in
                try transaction.snapshotDatabase(at: databaseURL, configuration: .libraryCatalog)
                try transaction.moveItem(at: sourceFileURL, to: destinationFileURL)

                let mutatedDatabase = try SQLiteDatabase(url: databaseURL, configuration: .libraryCatalog)
                try mutatedDatabase.execute("INSERT INTO demo_item (id, name) VALUES (2, 'after');")
                throw ExpectedFailure.forced
            }
        ) { error in
            XCTAssertTrue(error is ExpectedFailure)
        }

        XCTAssertTrue(fileManager.fileExists(atPath: sourceFileURL.path))
        XCTAssertFalse(fileManager.fileExists(atPath: destinationFileURL.path))
        XCTAssertEqual(
            try sqliteScalarInt("SELECT COUNT(*) FROM demo_item;", databaseURL: databaseURL),
            1
        )
        XCTAssertEqual(
            try sqliteScalarInt("SELECT COUNT(*) FROM demo_item WHERE name = 'before';", databaseURL: databaseURL),
            1
        )
        XCTAssertEqual(
            try sqliteScalarInt("SELECT COUNT(*) FROM demo_item WHERE name = 'after';", databaseURL: databaseURL),
            0
        )
    }

    private func temporaryDirectory(named prefix: String) -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)", isDirectory: true)
    }

    private func sqliteScalarInt(_ sql: String, databaseURL: URL) throws -> Int {
        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(databaseURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, sql, -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        return Int(sqlite3_column_int64(statement, 0))
    }
}
