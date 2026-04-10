import Foundation
import SQLite3

extension NativeCorpusDatabaseSupport {
    static func metadata(from statement: OpaquePointer?, offset: Int32) -> NativeStoredCorpusMetadata {
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

    static func insertDocument(
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

    static func insertFrequencyRows(_ rows: [FrequencyRow], into db: OpaquePointer?) throws {
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
}
