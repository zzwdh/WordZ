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
    static let currentSchemaVersion = 3
    static let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

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
}
