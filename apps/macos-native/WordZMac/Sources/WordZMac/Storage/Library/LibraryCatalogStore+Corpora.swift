import Foundation
import SQLite3
import WordZStorage

extension LibraryCatalogStore {
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

    func replaceCorpora(_ corpora: [NativeCorpusRecord], on db: SQLiteDatabase) throws {
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

    func insertCorpus(_ corpus: NativeCorpusRecord, position: Int, on db: SQLiteDatabase) throws {
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

    func bindAndInsertCorpus(
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

    func existingCorpusPosition(for corpusID: String, on db: SQLiteDatabase) throws -> Int {
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

    func removeCorpus(id corpusID: String, on db: SQLiteDatabase) throws {
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
}
