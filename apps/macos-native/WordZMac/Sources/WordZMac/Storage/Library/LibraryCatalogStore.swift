import CryptoKit
import Foundation
import SQLite3

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

    private struct CatalogProjection {
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

    private let configuration = SQLiteDatabaseConfiguration.libraryCatalog
    private let schemaVersion = 3

    func ensureInitialized() throws {
        try fileManager.createDirectory(
            at: databaseURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: nil
        )
        try withDatabase { db in
            try applySchema(on: db)
        }
    }

    func loadFolders() throws -> [NativeFolderRecord] {
        try withDatabase { db in
            let statement = try db.prepare(
                """
                SELECT id, name
                FROM library_folder
                ORDER BY position ASC, name COLLATE NOCASE ASC;
                """
            )
            var folders: [NativeFolderRecord] = []
            while statement.step() == SQLITE_ROW {
                folders.append(NativeFolderRecord(id: statement.text(at: 0), name: statement.text(at: 1)))
            }
            return folders
        }
    }

    func saveFolders(_ folders: [NativeFolderRecord]) throws {
        try withDatabase { db in
            try replaceFolders(folders, on: db)
        }
    }

    func loadCorpora(
        folderId: String? = nil,
        metadataFilterState: CorpusMetadataFilterState = .empty,
        searchQuery: String = ""
    ) throws -> [NativeCorpusRecord] {
        try withDatabase { db in
            let filter = metadataQueryFilter(
                folderId: folderId,
                metadataFilterState: metadataFilterState,
                searchQuery: searchQuery
            )
            let statement = try db.prepare(
                """
                SELECT id, name, folder_id, folder_name, source_type, represented_path, storage_file_name, metadata_json, cleaning_summary_json
                FROM corpus
                \(filter.sql)
                ORDER BY position ASC, name COLLATE NOCASE ASC;
                """
            )
            for (index, argument) in filter.arguments.enumerated() {
                statement.bind(text: argument, at: Int32(index + 1))
            }
            var corpora: [NativeCorpusRecord] = []
            while statement.step() == SQLITE_ROW {
                let metadata = decodeJSON(CorpusMetadataProfile.self, from: statement.text(at: 7)) ?? .empty
                let cleaningSummary = decodeJSON(LibraryCorpusCleaningReportSummary.self, from: statement.text(at: 8))
                corpora.append(
                    NativeCorpusRecord(
                        id: statement.text(at: 0),
                        name: statement.text(at: 1),
                        folderId: statement.text(at: 2),
                        folderName: statement.text(at: 3),
                        sourceType: statement.text(at: 4),
                        representedPath: statement.text(at: 5),
                        storageFileName: statement.text(at: 6),
                        metadata: metadata,
                        cleaningSummary: cleaningSummary
                    )
                )
            }
            return corpora
        }
    }

    func saveCorpora(_ corpora: [NativeCorpusRecord]) throws {
        try withDatabase { db in
            try replaceCorpora(corpora, on: db)
        }
    }

    func refreshCorpus(_ corpus: NativeCorpusRecord) throws {
            try withDatabase { db in
            try db.transaction {
                let position = try existingCorpusPosition(for: corpus.id, on: db)
                try removeCorpus(id: corpus.id, on: db)
                try insertCorpus(corpus, position: position, on: db)
                try rebuildCorpusSearchIndex(on: db)
            }
        }
    }

    func quarantineCorpora(_ entries: [QuarantinedCorpusEntry]) throws {
        guard !entries.isEmpty else { return }
        try withDatabase { db in
            try db.transaction {
                let statement = try db.prepare(
                    """
                    UPDATE corpus
                    SET storage_status = 'quarantined',
                        migration_state = 'repair-quarantine',
                        checksum_sha256 = ?,
                        integrity_note = ?,
                        updated_at = ?
                    WHERE id = ?;
                    """
                )
                for entry in entries {
                    statement.reset()
                    statement.bind(text: sha256Hex(for: entry.quarantineURL), at: 1)
                    statement.bind(text: entry.integrityNote, at: 2)
                    statement.bind(text: timestamp(), at: 3)
                    statement.bind(text: entry.record.id, at: 4)
                    guard statement.step() == SQLITE_DONE else {
                        throw db.error(message: "无法标记隔离语料")
                    }
                }
                try rebuildCorpusSearchIndex(on: db)
            }
        }
    }

    func reactivateCorpora(_ corpora: [NativeCorpusRecord]) throws {
        guard !corpora.isEmpty else { return }
        try withDatabase { db in
            try db.transaction {
                let statement = try db.prepare(
                    """
                    UPDATE corpus
                    SET metadata_json = ?,
                        cleaning_summary_json = ?,
                        source_label = ?,
                        year_label = ?,
                        genre_label = ?,
                        tags_text = ?,
                        imported_at = ?,
                        token_count = ?,
                        type_count = ?,
                        sentence_count = ?,
                        paragraph_count = ?,
                        character_count = ?,
                        ttr = ?,
                        sttr = ?,
                        cleaned_at = ?,
                        cleaning_profile_version = ?,
                        original_character_count = ?,
                        cleaned_character_count = ?,
                        cleaned_text_digest = ?,
                        storage_status = 'available',
                        migration_state = ?,
                        checksum_sha256 = ?,
                        integrity_note = '',
                        schema_version = ?,
                        updated_at = ?
                    WHERE id = ?;
                    """
                )
                for corpus in corpora {
                    let projection = catalogProjection(for: corpus)
                    statement.reset()
                    statement.bind(text: encodeJSON(corpus.metadata), at: 1)
                    statement.bind(text: encodeJSON(corpus.cleaningSummary), at: 2)
                    statement.bind(text: corpus.metadata.sourceLabel, at: 3)
                    statement.bind(text: corpus.metadata.yearLabel, at: 4)
                    statement.bind(text: corpus.metadata.genreLabel, at: 5)
                    statement.bind(text: corpus.metadata.tagsText, at: 6)
                    statement.bind(text: projection.importedAt, at: 7)
                    statement.bind(int: projection.tokenCount, at: 8)
                    statement.bind(int: projection.typeCount, at: 9)
                    statement.bind(int: projection.sentenceCount, at: 10)
                    statement.bind(int: projection.paragraphCount, at: 11)
                    statement.bind(int: projection.characterCount, at: 12)
                    statement.bind(double: projection.ttr, at: 13)
                    statement.bind(double: projection.sttr, at: 14)
                    statement.bind(text: projection.cleanedAt, at: 15)
                    statement.bind(text: projection.cleaningProfileVersion, at: 16)
                    statement.bind(int: projection.originalCharacterCount, at: 17)
                    statement.bind(int: projection.cleanedCharacterCount, at: 18)
                    statement.bind(text: projection.cleanedTextDigest, at: 19)
                    statement.bind(text: projection.migrationState, at: 20)
                    statement.bind(text: projection.checksumSHA256, at: 21)
                    statement.bind(int: projection.schemaVersion, at: 22)
                    statement.bind(text: timestamp(), at: 23)
                    statement.bind(text: corpus.id, at: 24)
                    guard statement.step() == SQLITE_DONE else {
                        throw db.error(message: "无法恢复语料可用状态")
                    }
                }
                try rebuildCorpusSearchIndex(on: db)
            }
        }
    }

    func loadCorpusSets() throws -> [NativeCorpusSetRecord] {
        try withDatabase { db in
            let memberStatement = try db.prepare(
                """
                SELECT corpus_set_id, corpus_id, corpus_name
                FROM corpus_set_member
                ORDER BY corpus_set_id ASC, position ASC;
                """
            )
            var membersBySetID: [String: [(String, String)]] = [:]
            while memberStatement.step() == SQLITE_ROW {
                membersBySetID[memberStatement.text(at: 0), default: []].append(
                    (memberStatement.text(at: 1), memberStatement.text(at: 2))
                )
            }

            let statement = try db.prepare(
                """
                SELECT id, name, metadata_filter_json, created_at, updated_at
                FROM corpus_set
                ORDER BY position ASC, updated_at DESC;
                """
            )
            var sets: [NativeCorpusSetRecord] = []
            while statement.step() == SQLITE_ROW {
                let id = statement.text(at: 0)
                let members = membersBySetID[id, default: []]
                sets.append(
                    NativeCorpusSetRecord(
                        id: id,
                        name: statement.text(at: 1),
                        corpusIDs: members.map(\.0),
                        corpusNames: members.map(\.1),
                        metadataFilterState: decodeJSON(CorpusMetadataFilterState.self, from: statement.text(at: 2)) ?? .empty,
                        createdAt: statement.text(at: 3),
                        updatedAt: statement.text(at: 4)
                    )
                )
            }
            return sets
        }
    }

    func saveCorpusSets(_ corpusSets: [NativeCorpusSetRecord]) throws {
        try withDatabase { db in
            try replaceCorpusSets(corpusSets, on: db)
        }
    }

    func loadRecycleEntries() throws -> [NativeRecycleRecord] {
        try withDatabase { db in
            let corpusStatement = try db.prepare(
                """
                SELECT recycle_entry_id, payload_json
                FROM recycle_entry_corpus
                ORDER BY recycle_entry_id ASC, position ASC;
                """
            )
            var corporaByEntryID: [String: [NativeCorpusRecord]] = [:]
            while corpusStatement.step() == SQLITE_ROW {
                let entryID = corpusStatement.text(at: 0)
                if let record = decodeJSON(NativeCorpusRecord.self, from: corpusStatement.text(at: 1)) {
                    corporaByEntryID[entryID, default: []].append(record)
                }
            }

            let statement = try db.prepare(
                """
                SELECT id, type, deleted_at, name, original_folder_name, source_type, item_count, folder_json
                FROM recycle_entry
                ORDER BY position ASC, deleted_at DESC;
                """
            )
            var entries: [NativeRecycleRecord] = []
            while statement.step() == SQLITE_ROW {
                let entryID = statement.text(at: 0)
                entries.append(
                    NativeRecycleRecord(
                        recycleEntryId: entryID,
                        type: statement.text(at: 1),
                        deletedAt: statement.text(at: 2),
                        name: statement.text(at: 3),
                        originalFolderName: statement.text(at: 4),
                        sourceType: statement.text(at: 5),
                        itemCount: statement.int(at: 6),
                        folder: decodeJSON(NativeFolderRecord.self, from: statement.text(at: 7)),
                        corpora: corporaByEntryID[entryID, default: []]
                    )
                )
            }
            return entries
        }
    }

    func saveRecycleEntries(_ entries: [NativeRecycleRecord]) throws {
        try withDatabase { db in
            try replaceRecycleEntries(entries, on: db)
        }
    }

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

    func schemaVersionSummary() -> Int {
        schemaVersion
    }

    private func withDatabase<T>(_ body: (SQLiteDatabase) throws -> T) throws -> T {
        let database = try SQLiteDatabase(url: databaseURL, configuration: configuration)
        return try body(database)
    }

    private func applySchema(on db: SQLiteDatabase) throws {
        try db.transaction {
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS schema_migrations (
                    version INTEGER PRIMARY KEY,
                    applied_at TEXT NOT NULL,
                    description TEXT NOT NULL
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS storage_meta (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS library_folder (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS corpus (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    folder_id TEXT NOT NULL,
                    folder_name TEXT NOT NULL,
                    source_type TEXT NOT NULL,
                    represented_path TEXT NOT NULL,
                    storage_file_name TEXT NOT NULL,
                    metadata_json TEXT NOT NULL,
                    cleaning_summary_json TEXT NOT NULL DEFAULT '',
                    source_label TEXT NOT NULL DEFAULT '',
                    year_label TEXT NOT NULL DEFAULT '',
                    genre_label TEXT NOT NULL DEFAULT '',
                    tags_text TEXT NOT NULL DEFAULT '',
                    imported_at TEXT NOT NULL DEFAULT '',
                    token_count INTEGER NOT NULL DEFAULT 0,
                    type_count INTEGER NOT NULL DEFAULT 0,
                    sentence_count INTEGER NOT NULL DEFAULT 0,
                    paragraph_count INTEGER NOT NULL DEFAULT 0,
                    character_count INTEGER NOT NULL DEFAULT 0,
                    ttr REAL NOT NULL DEFAULT 0,
                    sttr REAL NOT NULL DEFAULT 0,
                    cleaned_at TEXT NOT NULL DEFAULT '',
                    cleaning_profile_version TEXT NOT NULL DEFAULT '',
                    original_character_count INTEGER NOT NULL DEFAULT 0,
                    cleaned_character_count INTEGER NOT NULL DEFAULT 0,
                    cleaned_text_digest TEXT NOT NULL DEFAULT '',
                    storage_status TEXT NOT NULL DEFAULT 'available',
                    migration_state TEXT NOT NULL DEFAULT 'current',
                    checksum_sha256 TEXT NOT NULL DEFAULT '',
                    integrity_note TEXT NOT NULL DEFAULT '',
                    schema_version INTEGER NOT NULL DEFAULT 0,
                    updated_at TEXT NOT NULL DEFAULT '',
                    position INTEGER NOT NULL DEFAULT 0
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS corpus_tag (
                    corpus_id TEXT NOT NULL,
                    normalized_tag TEXT NOT NULL,
                    tag TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (corpus_id, normalized_tag)
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS corpus_year (
                    corpus_id TEXT NOT NULL,
                    year_value INTEGER NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (corpus_id, year_value)
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS corpus_set (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    metadata_filter_json TEXT NOT NULL,
                    created_at TEXT NOT NULL,
                    updated_at TEXT NOT NULL,
                    position INTEGER NOT NULL DEFAULT 0
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS corpus_set_member (
                    corpus_set_id TEXT NOT NULL,
                    corpus_id TEXT NOT NULL,
                    corpus_name TEXT NOT NULL DEFAULT '',
                    position INTEGER NOT NULL DEFAULT 0,
                    PRIMARY KEY (corpus_set_id, corpus_id)
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS recycle_entry (
                    id TEXT PRIMARY KEY,
                    type TEXT NOT NULL,
                    deleted_at TEXT NOT NULL,
                    name TEXT NOT NULL,
                    original_folder_name TEXT NOT NULL,
                    source_type TEXT NOT NULL,
                    item_count INTEGER NOT NULL,
                    folder_json TEXT NOT NULL DEFAULT '',
                    position INTEGER NOT NULL DEFAULT 0
                );
                """
            )
            try db.execute(
                """
                CREATE TABLE IF NOT EXISTS recycle_entry_corpus (
                    recycle_entry_id TEXT NOT NULL,
                    position INTEGER NOT NULL,
                    corpus_id TEXT NOT NULL,
                    payload_json TEXT NOT NULL,
                    PRIMARY KEY (recycle_entry_id, position)
                );
                """
            )
            try db.execute(
                """
                CREATE VIRTUAL TABLE IF NOT EXISTS corpus_search_fts USING fts5(
                    corpus_id UNINDEXED,
                    name,
                    folder_name,
                    source_type,
                    source_label,
                    genre_label,
                    year_label,
                    tags,
                    tokenize = 'unicode61 remove_diacritics 2'
                );
                """
            )
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_folder ON corpus(folder_id, position, name COLLATE NOCASE);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_imported_at ON corpus(imported_at DESC);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_source_label ON corpus(source_label COLLATE NOCASE);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_year_label ON corpus(year_label COLLATE NOCASE);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_genre_label ON corpus(genre_label COLLATE NOCASE);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_tags_text ON corpus(tags_text COLLATE NOCASE);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_storage_status ON corpus(storage_status, migration_state);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_tag_lookup ON corpus_tag(normalized_tag, corpus_id);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_year_lookup ON corpus_year(year_value, corpus_id);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_corpus_set_member_position ON corpus_set_member(corpus_set_id, position);")
            try db.execute("CREATE INDEX IF NOT EXISTS idx_recycle_entry_deleted_at ON recycle_entry(position, deleted_at DESC);")
            try db.execute(
                """
                INSERT OR IGNORE INTO schema_migrations(version, applied_at, description)
                VALUES (\(schemaVersion), '\(timestamp())', 'Initialize library catalog database with corpus search FTS');
                """
            )
            try rebuildCorpusSearchIndex(on: db)
        }
    }

    private func replaceFolders(_ folders: [NativeFolderRecord], on db: SQLiteDatabase) throws {
        try db.transaction {
            try db.execute("DELETE FROM library_folder;")
            let statement = try db.prepare(
                """
                INSERT INTO library_folder (id, name, position)
                VALUES (?, ?, ?);
                """
            )
            for (position, folder) in folders.enumerated() {
                statement.reset()
                statement.bind(text: folder.id, at: 1)
                statement.bind(text: folder.name, at: 2)
                statement.bind(int: position, at: 3)
                guard statement.step() == SQLITE_DONE else {
                    throw db.error(message: "无法写入文件夹目录")
                }
            }
        }
    }

    private func replaceCorpora(_ corpora: [NativeCorpusRecord], on db: SQLiteDatabase) throws {
        try db.transaction {
            try db.execute(
                """
                DELETE FROM corpus_tag
                WHERE corpus_id IN (SELECT id FROM corpus WHERE storage_status != 'quarantined');
                """
            )
            try db.execute(
                """
                DELETE FROM corpus_year
                WHERE corpus_id IN (SELECT id FROM corpus WHERE storage_status != 'quarantined');
                """
            )
            try db.execute("DELETE FROM corpus WHERE storage_status != 'quarantined';")

            let statement = try db.prepare(
                """
                INSERT INTO corpus (
                    id, name, folder_id, folder_name, source_type, represented_path, storage_file_name,
                    metadata_json, cleaning_summary_json, source_label, year_label, genre_label, tags_text,
                    imported_at, token_count, type_count, sentence_count, paragraph_count, character_count,
                    ttr, sttr, cleaned_at, cleaning_profile_version, original_character_count,
                    cleaned_character_count, cleaned_text_digest, storage_status, migration_state,
                    checksum_sha256, integrity_note, schema_version, updated_at, position
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
            )
            let tagStatement = try db.prepare(
                """
                INSERT INTO corpus_tag (corpus_id, normalized_tag, tag, position)
                VALUES (?, ?, ?, ?);
                """
            )
            let yearStatement = try db.prepare(
                """
                INSERT INTO corpus_year (corpus_id, year_value, position)
                VALUES (?, ?, ?);
                """
            )

            for (position, corpus) in corpora.enumerated() {
                try bindAndInsertCorpus(
                    corpus,
                    position: position,
                    corpusStatement: statement,
                    tagStatement: tagStatement,
                    yearStatement: yearStatement,
                    on: db
                )
            }
            try rebuildCorpusSearchIndex(on: db)
        }
    }

    private func insertCorpus(_ corpus: NativeCorpusRecord, position: Int, on db: SQLiteDatabase) throws {
        let statement = try db.prepare(
            """
            INSERT INTO corpus (
                id, name, folder_id, folder_name, source_type, represented_path, storage_file_name,
                metadata_json, cleaning_summary_json, source_label, year_label, genre_label, tags_text,
                imported_at, token_count, type_count, sentence_count, paragraph_count, character_count,
                ttr, sttr, cleaned_at, cleaning_profile_version, original_character_count,
                cleaned_character_count, cleaned_text_digest, storage_status, migration_state,
                checksum_sha256, integrity_note, schema_version, updated_at, position
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """
        )
        let tagStatement = try db.prepare(
            """
            INSERT INTO corpus_tag (corpus_id, normalized_tag, tag, position)
            VALUES (?, ?, ?, ?);
            """
        )
        let yearStatement = try db.prepare(
            """
            INSERT INTO corpus_year (corpus_id, year_value, position)
            VALUES (?, ?, ?);
            """
        )
        try bindAndInsertCorpus(
            corpus,
            position: position,
            corpusStatement: statement,
            tagStatement: tagStatement,
            yearStatement: yearStatement,
            on: db
        )
    }

    private func bindAndInsertCorpus(
        _ corpus: NativeCorpusRecord,
        position: Int,
        corpusStatement: SQLiteStatement,
        tagStatement: SQLiteStatement,
        yearStatement: SQLiteStatement,
        on db: SQLiteDatabase
    ) throws {
        let projection = catalogProjection(for: corpus)
        corpusStatement.reset()
        corpusStatement.bind(text: corpus.id, at: 1)
        corpusStatement.bind(text: corpus.name, at: 2)
        corpusStatement.bind(text: corpus.folderId, at: 3)
        corpusStatement.bind(text: corpus.folderName, at: 4)
        corpusStatement.bind(text: corpus.sourceType, at: 5)
        corpusStatement.bind(text: corpus.representedPath, at: 6)
        corpusStatement.bind(text: corpus.storageFileName, at: 7)
        corpusStatement.bind(text: encodeJSON(corpus.metadata), at: 8)
        corpusStatement.bind(text: encodeJSON(corpus.cleaningSummary), at: 9)
        corpusStatement.bind(text: corpus.metadata.sourceLabel, at: 10)
        corpusStatement.bind(text: corpus.metadata.yearLabel, at: 11)
        corpusStatement.bind(text: corpus.metadata.genreLabel, at: 12)
        corpusStatement.bind(text: corpus.metadata.tagsText, at: 13)
        corpusStatement.bind(text: projection.importedAt, at: 14)
        corpusStatement.bind(int: projection.tokenCount, at: 15)
        corpusStatement.bind(int: projection.typeCount, at: 16)
        corpusStatement.bind(int: projection.sentenceCount, at: 17)
        corpusStatement.bind(int: projection.paragraphCount, at: 18)
        corpusStatement.bind(int: projection.characterCount, at: 19)
        corpusStatement.bind(double: projection.ttr, at: 20)
        corpusStatement.bind(double: projection.sttr, at: 21)
        corpusStatement.bind(text: projection.cleanedAt, at: 22)
        corpusStatement.bind(text: projection.cleaningProfileVersion, at: 23)
        corpusStatement.bind(int: projection.originalCharacterCount, at: 24)
        corpusStatement.bind(int: projection.cleanedCharacterCount, at: 25)
        corpusStatement.bind(text: projection.cleanedTextDigest, at: 26)
        corpusStatement.bind(text: projection.storageStatus, at: 27)
        corpusStatement.bind(text: projection.migrationState, at: 28)
        corpusStatement.bind(text: projection.checksumSHA256, at: 29)
        corpusStatement.bind(text: projection.storageStatus == "available" ? "" : projection.storageStatus, at: 30)
        corpusStatement.bind(int: projection.schemaVersion, at: 31)
        corpusStatement.bind(text: timestamp(), at: 32)
        corpusStatement.bind(int: position, at: 33)
        guard corpusStatement.step() == SQLITE_DONE else {
            throw db.error(message: "无法写入语料目录")
        }

        for (tagPosition, tag) in corpus.metadata.tags.enumerated() {
            tagStatement.reset()
            tagStatement.bind(text: corpus.id, at: 1)
            tagStatement.bind(text: normalizedTag(tag), at: 2)
            tagStatement.bind(text: tag, at: 3)
            tagStatement.bind(int: tagPosition, at: 4)
            guard tagStatement.step() == SQLITE_DONE else {
                throw db.error(message: "无法写入语料标签")
            }
        }

        for (yearPosition, yearValue) in extractedYears(from: corpus.metadata.yearLabel).enumerated() {
            yearStatement.reset()
            yearStatement.bind(text: corpus.id, at: 1)
            yearStatement.bind(int: yearValue, at: 2)
            yearStatement.bind(int: yearPosition, at: 3)
            guard yearStatement.step() == SQLITE_DONE else {
                throw db.error(message: "无法写入语料年份索引")
            }
        }
    }

    private func existingCorpusPosition(for corpusID: String, on db: SQLiteDatabase) throws -> Int {
        let statement = try db.prepare(
            """
            SELECT position
            FROM corpus
            WHERE id = ?
            LIMIT 1;
            """
        )
        statement.bind(text: corpusID, at: 1)
        if statement.step() == SQLITE_ROW {
            return statement.int(at: 0)
        }
        return try db.scalarInt("SELECT COALESCE(MAX(position) + 1, 0) FROM corpus;")
    }

    private func removeCorpus(id corpusID: String, on db: SQLiteDatabase) throws {
        let tagStatement = try db.prepare("DELETE FROM corpus_tag WHERE corpus_id = ?;")
        tagStatement.bind(text: corpusID, at: 1)
        guard tagStatement.step() == SQLITE_DONE else {
            throw db.error(message: "无法删除旧语料标签")
        }

        let yearStatement = try db.prepare("DELETE FROM corpus_year WHERE corpus_id = ?;")
        yearStatement.bind(text: corpusID, at: 1)
        guard yearStatement.step() == SQLITE_DONE else {
            throw db.error(message: "无法删除旧语料年份索引")
        }

        let corpusStatement = try db.prepare("DELETE FROM corpus WHERE id = ?;")
        corpusStatement.bind(text: corpusID, at: 1)
        guard corpusStatement.step() == SQLITE_DONE else {
            throw db.error(message: "无法删除旧语料目录")
        }
    }

    private func replaceCorpusSets(_ corpusSets: [NativeCorpusSetRecord], on db: SQLiteDatabase) throws {
        try db.transaction {
            try db.execute("DELETE FROM corpus_set_member;")
            try db.execute("DELETE FROM corpus_set;")

            let statement = try db.prepare(
                """
                INSERT INTO corpus_set (id, name, metadata_filter_json, created_at, updated_at, position)
                VALUES (?, ?, ?, ?, ?, ?);
                """
            )
            let memberStatement = try db.prepare(
                """
                INSERT INTO corpus_set_member (corpus_set_id, corpus_id, corpus_name, position)
                VALUES (?, ?, ?, ?);
                """
            )
            for (position, corpusSet) in corpusSets.enumerated() {
                statement.reset()
                statement.bind(text: corpusSet.id, at: 1)
                statement.bind(text: corpusSet.name, at: 2)
                statement.bind(text: encodeJSON(corpusSet.metadataFilterState), at: 3)
                statement.bind(text: corpusSet.createdAt, at: 4)
                statement.bind(text: corpusSet.updatedAt, at: 5)
                statement.bind(int: position, at: 6)
                guard statement.step() == SQLITE_DONE else {
                    throw db.error(message: "无法写入语料集目录")
                }

                for (memberPosition, corpusID) in corpusSet.corpusIDs.enumerated() {
                    memberStatement.reset()
                    memberStatement.bind(text: corpusSet.id, at: 1)
                    memberStatement.bind(text: corpusID, at: 2)
                    memberStatement.bind(text: corpusSet.corpusNames[safe: memberPosition] ?? "", at: 3)
                    memberStatement.bind(int: memberPosition, at: 4)
                    guard memberStatement.step() == SQLITE_DONE else {
                        throw db.error(message: "无法写入语料集成员")
                    }
                }
            }
        }
    }

    private func replaceRecycleEntries(_ entries: [NativeRecycleRecord], on db: SQLiteDatabase) throws {
        try db.transaction {
            try db.execute("DELETE FROM recycle_entry_corpus;")
            try db.execute("DELETE FROM recycle_entry;")

            let statement = try db.prepare(
                """
                INSERT INTO recycle_entry (
                    id, type, deleted_at, name, original_folder_name, source_type, item_count, folder_json, position
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?);
                """
            )
            let corpusStatement = try db.prepare(
                """
                INSERT INTO recycle_entry_corpus (recycle_entry_id, position, corpus_id, payload_json)
                VALUES (?, ?, ?, ?);
                """
            )

            for (position, entry) in entries.enumerated() {
                statement.reset()
                statement.bind(text: entry.recycleEntryId, at: 1)
                statement.bind(text: entry.type, at: 2)
                statement.bind(text: entry.deletedAt, at: 3)
                statement.bind(text: entry.name, at: 4)
                statement.bind(text: entry.originalFolderName, at: 5)
                statement.bind(text: entry.sourceType, at: 6)
                statement.bind(int: entry.itemCount, at: 7)
                statement.bind(text: encodeJSON(entry.folder), at: 8)
                statement.bind(int: position, at: 9)
                guard statement.step() == SQLITE_DONE else {
                    throw db.error(message: "无法写入回收站条目")
                }

                for (corpusPosition, corpus) in entry.corpora.enumerated() {
                    corpusStatement.reset()
                    corpusStatement.bind(text: entry.recycleEntryId, at: 1)
                    corpusStatement.bind(int: corpusPosition, at: 2)
                    corpusStatement.bind(text: corpus.id, at: 3)
                    corpusStatement.bind(text: encodeJSON(corpus), at: 4)
                    guard corpusStatement.step() == SQLITE_DONE else {
                        throw db.error(message: "无法写入回收站语料快照")
                    }
                }
            }
        }
    }

    private func catalogProjection(for corpus: NativeCorpusRecord) -> CatalogProjection {
        let storageURL = corporaDirectoryURL.appendingPathComponent(corpus.storageFileName)
        guard fileManager.fileExists(atPath: storageURL.path),
              let metadata = try? NativeCorpusDatabaseSupport.readMetadata(at: storageURL) else {
            return CatalogProjection(
                importedAt: "",
                tokenCount: 0,
                typeCount: 0,
                sentenceCount: 0,
                paragraphCount: 0,
                characterCount: 0,
                ttr: 0,
                sttr: 0,
                cleanedAt: corpus.cleaningSummary?.cleanedAt ?? "",
                cleaningProfileVersion: corpus.cleaningSummary?.profileVersion ?? "",
                originalCharacterCount: corpus.cleaningSummary?.originalCharacterCount ?? 0,
                cleanedCharacterCount: corpus.cleaningSummary?.cleanedCharacterCount ?? 0,
                cleanedTextDigest: "",
                storageStatus: "missing",
                migrationState: "unknown",
                schemaVersion: 0,
                checksumSHA256: ""
            )
        }
        return CatalogProjection(
            importedAt: metadata.importedAt,
            tokenCount: metadata.tokenCount,
            typeCount: metadata.typeCount,
            sentenceCount: metadata.sentenceCount,
            paragraphCount: metadata.paragraphCount,
            characterCount: metadata.characterCount,
            ttr: metadata.ttr,
            sttr: metadata.sttr,
            cleanedAt: metadata.cleanedAt,
            cleaningProfileVersion: metadata.cleaningProfileVersion,
            originalCharacterCount: metadata.originalCharacterCount,
            cleanedCharacterCount: metadata.cleanedCharacterCount,
            cleanedTextDigest: metadata.cleanedTextDigest,
            storageStatus: "available",
            migrationState: metadata.schemaVersion < NativeCorpusDatabaseSupport.currentSchemaVersion ? "legacy-shard" : "current",
            schemaVersion: metadata.schemaVersion,
            checksumSHA256: sha256Hex(for: storageURL)
        )
    }

    private func metaValue(forKey key: String, on db: SQLiteDatabase) throws -> String? {
        let statement = try db.prepare("SELECT value FROM storage_meta WHERE key = ? LIMIT 1;")
        statement.bind(text: key, at: 1)
        guard statement.step() == SQLITE_ROW else { return nil }
        return statement.text(at: 0)
    }

    private func setMetaValue(_ value: String, forKey key: String, on db: SQLiteDatabase) throws {
        let statement = try db.prepare(
            """
            INSERT INTO storage_meta(key, value)
            VALUES (?, ?)
            ON CONFLICT(key) DO UPDATE SET value = excluded.value;
            """
        )
        statement.bind(text: key, at: 1)
        statement.bind(text: value, at: 2)
        guard statement.step() == SQLITE_DONE else {
            throw db.error(message: "无法写入目录存储元数据")
        }
    }

    private func encodeJSON<T: Encodable>(_ value: T?) -> String {
        guard let value,
              let data = try? encoder.encode(value),
              let string = String(data: data, encoding: .utf8) else {
            return ""
        }
        return string
    }

    private func decodeJSON<T: Decodable>(_ type: T.Type, from string: String) -> T? {
        guard let data = string.data(using: .utf8), !data.isEmpty else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func normalizedTag(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func extractedYears(from value: String) -> [Int] {
        Array(Set(MetadataYearSuggestionSupport.extractYears(from: value))).sorted()
    }

    private func metadataQueryFilter(
        folderId: String?,
        metadataFilterState: CorpusMetadataFilterState,
        searchQuery: String
    ) -> (sql: String, arguments: [String]) {
        var clauses = ["storage_status != 'quarantined'"]
        var arguments: [String] = []

        if let folderId, !folderId.isEmpty, folderId != "all" {
            clauses.append("folder_id = ?")
            arguments.append(folderId)
        }

        if !metadataFilterState.sourceQuery.isEmpty {
            clauses.append("source_label LIKE ? COLLATE NOCASE")
            arguments.append(likePattern(metadataFilterState.sourceQuery))
        }

        if let yearBounds = normalizedYearBounds(from: metadataFilterState) {
            var yearPredicates: [String] = ["corpus_year.corpus_id = corpus.id"]
            if let lower = yearBounds.lower {
                yearPredicates.append("corpus_year.year_value >= ?")
                arguments.append(String(lower))
            }
            if let upper = yearBounds.upper {
                yearPredicates.append("corpus_year.year_value <= ?")
                arguments.append(String(upper))
            }
            clauses.append(
                """
                EXISTS (
                    SELECT 1
                    FROM corpus_year
                    WHERE \(yearPredicates.joined(separator: " AND "))
                )
                """
            )
        } else if !metadataFilterState.yearQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            clauses.append("year_label LIKE ? COLLATE NOCASE")
            arguments.append(likePattern(metadataFilterState.yearQuery))
        }

        if !metadataFilterState.genreQuery.isEmpty {
            clauses.append("genre_label LIKE ? COLLATE NOCASE")
            arguments.append(likePattern(metadataFilterState.genreQuery))
        }

        for tagQuery in normalizedTagQueries(from: metadataFilterState.tagsQuery) {
            clauses.append(
                """
                EXISTS (
                    SELECT 1
                    FROM corpus_tag
                    WHERE corpus_tag.corpus_id = corpus.id
                      AND corpus_tag.normalized_tag LIKE ?
                )
                """
            )
            arguments.append(likePattern(tagQuery))
        }

        let trimmedSearchQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedSearchQuery.isEmpty {
            if let matchExpression = ftsMatchExpression(for: trimmedSearchQuery) {
                clauses.append(
                    """
                    EXISTS (
                        SELECT 1
                        FROM corpus_search_fts
                        WHERE corpus_search_fts.corpus_id = corpus.id
                          AND corpus_search_fts MATCH ?
                    )
                    """
                )
                arguments.append(matchExpression)
            } else {
                let pattern = likePattern(trimmedSearchQuery)
                clauses.append(
                    """
                    (
                        name LIKE ? COLLATE NOCASE
                        OR folder_name LIKE ? COLLATE NOCASE
                        OR source_type LIKE ? COLLATE NOCASE
                        OR source_label LIKE ? COLLATE NOCASE
                        OR year_label LIKE ? COLLATE NOCASE
                        OR genre_label LIKE ? COLLATE NOCASE
                        OR tags_text LIKE ? COLLATE NOCASE
                    )
                    """
                )
                arguments.append(contentsOf: Array(repeating: pattern, count: 7))
            }
        }

        let sql = clauses.isEmpty ? "" : "WHERE " + clauses.joined(separator: " AND ")
        return (sql, arguments)
    }

    private func likePattern(_ value: String) -> String {
        "%\(value.trimmingCharacters(in: .whitespacesAndNewlines))%"
    }

    private func ftsMatchExpression(for rawValue: String) -> String? {
        let terms = rawValue
            .split(whereSeparator: \.isWhitespace)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !terms.isEmpty else { return nil }

        let safeTerms = terms.compactMap { term -> String? in
            guard term.unicodeScalars.allSatisfy({
                $0.isASCII && (CharacterSet.alphanumerics.contains($0) || String($0) == "_")
            }) else {
                return nil
            }
            return "\(term)*"
        }
        guard safeTerms.count == terms.count else { return nil }
        return safeTerms.joined(separator: " ")
    }

    private func normalizedTagQueries(from rawValue: String) -> [String] {
        rawValue
            .split(whereSeparator: { [",", "，", ";", "；", "\n"].contains($0) })
            .map { normalizedTag(String($0)) }
            .filter { !$0.isEmpty }
    }

    private func normalizedYearBounds(from state: CorpusMetadataFilterState) -> (lower: Int?, upper: Int?)? {
        let lower = parseYear(state.yearFrom)
        let upper = parseYear(state.yearTo)
        guard lower != nil || upper != nil else { return nil }
        switch (lower, upper) {
        case let (.some(lhs), .some(rhs)):
            return (min(lhs, rhs), max(lhs, rhs))
        default:
            return (lower, upper)
        }
    }

    private func parseYear(_ value: String?) -> Int? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 4,
              trimmed.allSatisfy(\.isNumber),
              let parsed = Int(trimmed) else {
            return nil
        }
        return parsed
    }

    private func rebuildCorpusSearchIndex(on db: SQLiteDatabase) throws {
        try db.execute("DELETE FROM corpus_search_fts;")
        let selectStatement = try db.prepare(
            """
            SELECT id, name, folder_name, source_type, source_label, genre_label, year_label, tags_text
            FROM corpus
            WHERE storage_status != 'quarantined'
            ORDER BY position ASC, name COLLATE NOCASE ASC;
            """
        )
        let insertStatement = try db.prepare(
            """
            INSERT INTO corpus_search_fts (
                corpus_id,
                name,
                folder_name,
                source_type,
                source_label,
                genre_label,
                year_label,
                tags
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """
        )

        while selectStatement.step() == SQLITE_ROW {
            insertStatement.reset()
            insertStatement.bind(text: selectStatement.text(at: 0), at: 1)
            insertStatement.bind(text: selectStatement.text(at: 1), at: 2)
            insertStatement.bind(text: selectStatement.text(at: 2), at: 3)
            insertStatement.bind(text: selectStatement.text(at: 3), at: 4)
            insertStatement.bind(text: selectStatement.text(at: 4), at: 5)
            insertStatement.bind(text: selectStatement.text(at: 5), at: 6)
            insertStatement.bind(text: selectStatement.text(at: 6), at: 7)
            insertStatement.bind(text: selectStatement.text(at: 7), at: 8)
            guard insertStatement.step() == SQLITE_DONE else {
                throw db.error(message: "无法重建语料搜索索引")
            }
        }
    }

    private func sha256Hex(for url: URL) -> String {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            return ""
        }
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private func timestamp() -> String {
        NativeDateFormatting.iso8601String(from: Date())
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
