import Foundation
import SQLite3

struct NativeStoredCorpusMetadata: Equatable {
    let schemaVersion: Int
    let importedAt: String
    let sourceType: String
    let representedPath: String
    let detectedEncoding: String
    let metadataProfile: CorpusMetadataProfile
    let tokenCount: Int
    let typeCount: Int
    let sentenceCount: Int
    let paragraphCount: Int
    let characterCount: Int
    let ttr: Double
    let sttr: Double
}

struct NativeStoredCorpusDatabaseDocument: Equatable {
    let text: String
    let metadata: NativeStoredCorpusMetadata
}

enum NativeCorpusDatabaseSupport {
    private static let currentSchemaVersion = 3
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    static func writeDocument(
        at url: URL,
        document: DecodedTextDocument,
        sourceType: String,
        representedPath: String,
        importedAt: String,
        metadataProfile: CorpusMetadataProfile = .empty
    ) throws {
        let analysis = NativeAnalysisEngine().runStats(text: document.text)
        let metadata = NativeStoredCorpusMetadata(
            schemaVersion: currentSchemaVersion,
            importedAt: importedAt,
            sourceType: sourceType,
            representedPath: representedPath,
            detectedEncoding: document.encodingName,
            metadataProfile: metadataProfile,
            tokenCount: analysis.tokenCount,
            typeCount: analysis.typeCount,
            sentenceCount: analysis.sentenceCount,
            paragraphCount: analysis.paragraphCount,
            characterCount: document.text.count,
            ttr: analysis.ttr,
            sttr: analysis.sttr
        )

        try? FileManager.default.removeItem(at: url)
        let db = try openDatabase(at: url, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        defer { sqlite3_close(db) }

        try configureDatabase(on: db)
        try ensureDocumentSchema(on: db)

        try execute("BEGIN IMMEDIATE TRANSACTION;", on: db)
        do {
            try execute("DELETE FROM corpus_document;", on: db)
            try execute("DELETE FROM token_frequency;", on: db)
            try insertDocument(document.text, metadata: metadata, into: db)
            try insertFrequencyRows(analysis.frequencyRows, into: db)
            try execute("COMMIT;", on: db)
        } catch {
            try? execute("ROLLBACK;", on: db)
            throw error
        }
    }

    static func updateMetadata(at url: URL, metadataProfile: CorpusMetadataProfile) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        let db = try openDatabase(at: url, flags: SQLITE_OPEN_READWRITE)
        defer { sqlite3_close(db) }

        try ensureDocumentSchema(on: db)
        let statement = try prepare(
            """
            UPDATE corpus_document
            SET source_label = ?,
                year_label = ?,
                genre_label = ?,
                tags_text = ?
            WHERE id = 1;
            """,
            on: db
        )
        defer { sqlite3_finalize(statement) }

        bindText(metadataProfile.sourceLabel, to: statement, index: 1)
        bindText(metadataProfile.yearLabel, to: statement, index: 2)
        bindText(metadataProfile.genreLabel, to: statement, index: 3)
        bindText(metadataProfile.tagsText, to: statement, index: 4)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError(on: db, message: "无法更新语料元数据")
        }
    }

    static func readMetadata(at url: URL) throws -> NativeStoredCorpusMetadata? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let db = try? openDatabase(at: url, flags: SQLITE_OPEN_READWRITE) else {
            return nil
        }
        defer { sqlite3_close(db) }

        do {
            try ensureDocumentSchema(on: db)
            guard let statement = try? prepare(
                """
                SELECT schema_version,
                       imported_at,
                       source_type,
                       represented_path,
                       detected_encoding,
                       source_label,
                       year_label,
                       genre_label,
                       tags_text,
                       token_count,
                       type_count,
                       sentence_count,
                       paragraph_count,
                       character_count,
                       ttr,
                       sttr
                FROM corpus_document
                WHERE id = 1;
                """,
                on: db
            ) else {
                return nil
            }
            defer { sqlite3_finalize(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return nil
            }
            return metadata(from: statement, offset: 0)
        } catch {
            return nil
        }
    }

    static func readDocument(at url: URL) throws -> NativeStoredCorpusDatabaseDocument? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let db = try? openDatabase(at: url, flags: SQLITE_OPEN_READWRITE) else {
            return nil
        }
        defer { sqlite3_close(db) }

        do {
            try ensureDocumentSchema(on: db)
            guard let statement = try? prepare(
                """
                SELECT schema_version,
                       imported_at,
                       source_type,
                       represented_path,
                       detected_encoding,
                       source_label,
                       year_label,
                       genre_label,
                       tags_text,
                       token_count,
                       type_count,
                       sentence_count,
                       paragraph_count,
                       character_count,
                       ttr,
                       sttr,
                       text
                FROM corpus_document
                WHERE id = 1;
                """,
                on: db
            ) else {
                return nil
            }
            defer { sqlite3_finalize(statement) }

            guard sqlite3_step(statement) == SQLITE_ROW else {
                return nil
            }

            return NativeStoredCorpusDatabaseDocument(
                text: stringColumn(statement, index: 16),
                metadata: metadata(from: statement, offset: 0)
            )
        } catch {
            return nil
        }
    }

    private static func configureDatabase(on db: OpaquePointer?) throws {
        try execute("PRAGMA journal_mode=DELETE;", on: db)
        try execute("PRAGMA synchronous=NORMAL;", on: db)
    }

    private static func ensureDocumentSchema(on db: OpaquePointer?) throws {
        try execute(
            """
            CREATE TABLE IF NOT EXISTS corpus_document (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                schema_version INTEGER NOT NULL,
                imported_at TEXT NOT NULL,
                source_type TEXT NOT NULL,
                represented_path TEXT NOT NULL,
                detected_encoding TEXT NOT NULL,
                source_label TEXT NOT NULL DEFAULT '',
                year_label TEXT NOT NULL DEFAULT '',
                genre_label TEXT NOT NULL DEFAULT '',
                tags_text TEXT NOT NULL DEFAULT '',
                token_count INTEGER NOT NULL,
                type_count INTEGER NOT NULL,
                sentence_count INTEGER NOT NULL,
                paragraph_count INTEGER NOT NULL,
                character_count INTEGER NOT NULL,
                ttr REAL NOT NULL DEFAULT 0,
                sttr REAL NOT NULL DEFAULT 0,
                text TEXT NOT NULL
            );
            """,
            on: db
        )
        try execute(
            """
            CREATE TABLE IF NOT EXISTS token_frequency (
                term TEXT PRIMARY KEY,
                count INTEGER NOT NULL,
                rank_index INTEGER NOT NULL,
                norm_frequency REAL NOT NULL,
                sentence_range INTEGER NOT NULL,
                paragraph_range INTEGER NOT NULL
            );
            """,
            on: db
        )
        try ensureColumn("source_label", definition: "TEXT NOT NULL DEFAULT ''", onTable: "corpus_document", db: db)
        try ensureColumn("year_label", definition: "TEXT NOT NULL DEFAULT ''", onTable: "corpus_document", db: db)
        try ensureColumn("genre_label", definition: "TEXT NOT NULL DEFAULT ''", onTable: "corpus_document", db: db)
        try ensureColumn("tags_text", definition: "TEXT NOT NULL DEFAULT ''", onTable: "corpus_document", db: db)
        try ensureColumn("ttr", definition: "REAL NOT NULL DEFAULT 0", onTable: "corpus_document", db: db)
        try ensureColumn("sttr", definition: "REAL NOT NULL DEFAULT 0", onTable: "corpus_document", db: db)
        try execute("CREATE INDEX IF NOT EXISTS idx_token_frequency_count ON token_frequency(count DESC, term ASC);", on: db)
    }

    private static func ensureColumn(
        _ column: String,
        definition: String,
        onTable tableName: String,
        db: OpaquePointer?
    ) throws {
        guard try !columnExists(column, onTable: tableName, db: db) else { return }
        try execute("ALTER TABLE \(tableName) ADD COLUMN \(column) \(definition);", on: db)
    }

    private static func columnExists(_ column: String, onTable tableName: String, db: OpaquePointer?) throws -> Bool {
        let statement = try prepare("PRAGMA table_info(\(tableName));", on: db)
        defer { sqlite3_finalize(statement) }

        while sqlite3_step(statement) == SQLITE_ROW {
            if stringColumn(statement, index: 1) == column {
                return true
            }
        }
        return false
    }

    private static func metadata(from statement: OpaquePointer?, offset: Int32) -> NativeStoredCorpusMetadata {
        NativeStoredCorpusMetadata(
            schemaVersion: Int(sqlite3_column_int(statement, offset + 0)),
            importedAt: stringColumn(statement, index: offset + 1),
            sourceType: stringColumn(statement, index: offset + 2),
            representedPath: stringColumn(statement, index: offset + 3),
            detectedEncoding: stringColumn(statement, index: offset + 4),
            metadataProfile: CorpusMetadataProfile(
                sourceLabel: stringColumn(statement, index: offset + 5),
                yearLabel: stringColumn(statement, index: offset + 6),
                genreLabel: stringColumn(statement, index: offset + 7),
                tags: stringColumn(statement, index: offset + 8)
                    .split(separator: ",")
                    .map(String.init)
            ),
            tokenCount: Int(sqlite3_column_int(statement, offset + 9)),
            typeCount: Int(sqlite3_column_int(statement, offset + 10)),
            sentenceCount: Int(sqlite3_column_int(statement, offset + 11)),
            paragraphCount: Int(sqlite3_column_int(statement, offset + 12)),
            characterCount: Int(sqlite3_column_int(statement, offset + 13)),
            ttr: doubleColumn(statement, index: offset + 14),
            sttr: doubleColumn(statement, index: offset + 15)
        )
    }

    private static func insertDocument(
        _ text: String,
        metadata: NativeStoredCorpusMetadata,
        into db: OpaquePointer?
    ) throws {
        let statement = try prepare(
            """
            INSERT INTO corpus_document (
                id,
                schema_version,
                imported_at,
                source_type,
                represented_path,
                detected_encoding,
                source_label,
                year_label,
                genre_label,
                tags_text,
                token_count,
                type_count,
                sentence_count,
                paragraph_count,
                character_count,
                ttr,
                sttr,
                text
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
            """,
            on: db
        )
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, 1)
        sqlite3_bind_int(statement, 2, Int32(metadata.schemaVersion))
        bindText(metadata.importedAt, to: statement, index: 3)
        bindText(metadata.sourceType, to: statement, index: 4)
        bindText(metadata.representedPath, to: statement, index: 5)
        bindText(metadata.detectedEncoding, to: statement, index: 6)
        bindText(metadata.metadataProfile.sourceLabel, to: statement, index: 7)
        bindText(metadata.metadataProfile.yearLabel, to: statement, index: 8)
        bindText(metadata.metadataProfile.genreLabel, to: statement, index: 9)
        bindText(metadata.metadataProfile.tagsText, to: statement, index: 10)
        sqlite3_bind_int(statement, 11, Int32(metadata.tokenCount))
        sqlite3_bind_int(statement, 12, Int32(metadata.typeCount))
        sqlite3_bind_int(statement, 13, Int32(metadata.sentenceCount))
        sqlite3_bind_int(statement, 14, Int32(metadata.paragraphCount))
        sqlite3_bind_int(statement, 15, Int32(metadata.characterCount))
        sqlite3_bind_double(statement, 16, metadata.ttr)
        sqlite3_bind_double(statement, 17, metadata.sttr)
        bindText(text, to: statement, index: 18)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError(on: db, message: "无法写入语料正文")
        }
    }

    private static func insertFrequencyRows(_ rows: [FrequencyRow], into db: OpaquePointer?) throws {
        let statement = try prepare(
            """
            INSERT INTO token_frequency (
                term,
                count,
                rank_index,
                norm_frequency,
                sentence_range,
                paragraph_range
            ) VALUES (?, ?, ?, ?, ?, ?);
            """,
            on: db
        )
        defer { sqlite3_finalize(statement) }

        for row in rows {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            bindText(row.word, to: statement, index: 1)
            sqlite3_bind_int(statement, 2, Int32(row.count))
            sqlite3_bind_int(statement, 3, Int32(row.rank))
            sqlite3_bind_double(statement, 4, row.normFreq)
            sqlite3_bind_int(statement, 5, Int32(row.sentenceRange))
            sqlite3_bind_int(statement, 6, Int32(row.paragraphRange))

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw databaseError(on: db, message: "无法写入词频索引")
            }
        }
    }

    private static func openDatabase(at url: URL, flags: Int32) throws -> OpaquePointer? {
        var db: OpaquePointer?
        let result = sqlite3_open_v2(url.path, &db, flags, nil)
        guard result == SQLITE_OK, let db else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            sqlite3_close(db)
            throw NSError(
                domain: "WordZMac.NativeCorpusDatabaseSupport",
                code: Int(result),
                userInfo: [NSLocalizedDescriptionKey: "无法打开语料数据库：\(message)"]
            )
        }
        return db
    }

    private static func prepare(_ sql: String, on db: OpaquePointer?) throws -> OpaquePointer? {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(db, sql, -1, &statement, nil)
        guard result == SQLITE_OK else {
            throw databaseError(on: db, message: "数据库语句准备失败")
        }
        return statement
    }

    private static func execute(_ sql: String, on db: OpaquePointer?) throws {
        let result = sqlite3_exec(db, sql, nil, nil, nil)
        guard result == SQLITE_OK else {
            throw databaseError(on: db, message: "数据库执行失败")
        }
    }

    private static func bindText(_ value: String, to statement: OpaquePointer?, index: Int32) {
        sqlite3_bind_text(statement, index, value, -1, sqliteTransient)
    }

    private static func stringColumn(_ statement: OpaquePointer?, index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: pointer)
    }

    private static func doubleColumn(_ statement: OpaquePointer?, index: Int32) -> Double {
        sqlite3_column_double(statement, index)
    }

    private static func databaseError(on db: OpaquePointer?, message: String) -> NSError {
        NSError(
            domain: "WordZMac.NativeCorpusDatabaseSupport",
            code: Int(sqlite3_errcode(db)),
            userInfo: [NSLocalizedDescriptionKey: "\(message)：\(String(cString: sqlite3_errmsg(db)))"]
        )
    }
}
