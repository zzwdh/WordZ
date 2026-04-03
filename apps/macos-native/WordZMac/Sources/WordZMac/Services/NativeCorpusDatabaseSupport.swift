import Foundation
import SQLite3

struct NativeStoredCorpusMetadata: Equatable {
    let schemaVersion: Int
    let importedAt: String
    let sourceType: String
    let representedPath: String
    let detectedEncoding: String
    let tokenCount: Int
    let typeCount: Int
    let sentenceCount: Int
    let paragraphCount: Int
    let characterCount: Int
}

struct NativeStoredCorpusDatabaseDocument: Equatable {
    let text: String
    let metadata: NativeStoredCorpusMetadata
}

enum NativeCorpusDatabaseSupport {
    private static let currentSchemaVersion = 1
    private static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    static func writeDocument(
        at url: URL,
        document: DecodedTextDocument,
        sourceType: String,
        representedPath: String,
        importedAt: String
    ) throws {
        let analysis = NativeAnalysisEngine().runStats(text: document.text)
        let metadata = NativeStoredCorpusMetadata(
            schemaVersion: currentSchemaVersion,
            importedAt: importedAt,
            sourceType: sourceType,
            representedPath: representedPath,
            detectedEncoding: document.encodingName,
            tokenCount: analysis.tokenCount,
            typeCount: analysis.typeCount,
            sentenceCount: analysis.sentenceCount,
            paragraphCount: analysis.paragraphCount,
            characterCount: document.text.count
        )

        try? FileManager.default.removeItem(at: url)
        let db = try openDatabase(at: url, flags: SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE)
        defer { sqlite3_close(db) }

        try execute("PRAGMA journal_mode=DELETE;", on: db)
        try execute("PRAGMA synchronous=NORMAL;", on: db)
        try execute(
            """
            CREATE TABLE IF NOT EXISTS corpus_document (
                id INTEGER PRIMARY KEY CHECK (id = 1),
                schema_version INTEGER NOT NULL,
                imported_at TEXT NOT NULL,
                source_type TEXT NOT NULL,
                represented_path TEXT NOT NULL,
                detected_encoding TEXT NOT NULL,
                token_count INTEGER NOT NULL,
                type_count INTEGER NOT NULL,
                sentence_count INTEGER NOT NULL,
                paragraph_count INTEGER NOT NULL,
                character_count INTEGER NOT NULL,
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
        try execute("CREATE INDEX IF NOT EXISTS idx_token_frequency_count ON token_frequency(count DESC, term ASC);", on: db)

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

    static func readDocument(at url: URL) throws -> NativeStoredCorpusDatabaseDocument? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        guard let db = try? openDatabase(at: url, flags: SQLITE_OPEN_READONLY) else {
            return nil
        }
        defer { sqlite3_close(db) }
        guard (try? tableExists("corpus_document", on: db)) == true else { return nil }

        guard let statement = try? prepare(
            """
            SELECT schema_version,
                   imported_at,
                   source_type,
                   represented_path,
                   detected_encoding,
                   token_count,
                   type_count,
                   sentence_count,
                   paragraph_count,
                   character_count,
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

        let metadata = NativeStoredCorpusMetadata(
            schemaVersion: Int(sqlite3_column_int(statement, 0)),
            importedAt: stringColumn(statement, index: 1),
            sourceType: stringColumn(statement, index: 2),
            representedPath: stringColumn(statement, index: 3),
            detectedEncoding: stringColumn(statement, index: 4),
            tokenCount: Int(sqlite3_column_int(statement, 5)),
            typeCount: Int(sqlite3_column_int(statement, 6)),
            sentenceCount: Int(sqlite3_column_int(statement, 7)),
            paragraphCount: Int(sqlite3_column_int(statement, 8)),
            characterCount: Int(sqlite3_column_int(statement, 9))
        )
        return NativeStoredCorpusDatabaseDocument(
            text: stringColumn(statement, index: 10),
            metadata: metadata
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
                token_count,
                type_count,
                sentence_count,
                paragraph_count,
                character_count,
                text
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
        sqlite3_bind_int(statement, 7, Int32(metadata.tokenCount))
        sqlite3_bind_int(statement, 8, Int32(metadata.typeCount))
        sqlite3_bind_int(statement, 9, Int32(metadata.sentenceCount))
        sqlite3_bind_int(statement, 10, Int32(metadata.paragraphCount))
        sqlite3_bind_int(statement, 11, Int32(metadata.characterCount))
        bindText(text, to: statement, index: 12)

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

    private static func tableExists(_ tableName: String, on db: OpaquePointer?) throws -> Bool {
        let statement = try prepare(
            "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ? LIMIT 1;",
            on: db
        )
        defer { sqlite3_finalize(statement) }
        bindText(tableName, to: statement, index: 1)
        return sqlite3_step(statement) == SQLITE_ROW
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

    private static func databaseError(on db: OpaquePointer?, message: String) -> NSError {
        NSError(
            domain: "WordZMac.NativeCorpusDatabaseSupport",
            code: Int(sqlite3_errcode(db)),
            userInfo: [NSLocalizedDescriptionKey: "\(message)：\(String(cString: sqlite3_errmsg(db)))"]
        )
    }
}
