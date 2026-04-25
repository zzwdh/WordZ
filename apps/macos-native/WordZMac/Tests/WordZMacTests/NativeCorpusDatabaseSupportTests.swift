import SQLite3
import XCTest
@testable import WordZWorkspaceCore

final class NativeCorpusDatabaseSupportTests: XCTestCase {
    func testWriteDocumentCreatesPerformanceIndexesForTokenFrequencyTable() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-frequency-indexes-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        try NativeCorpusDatabaseSupport.writeDocument(
            at: databaseURL,
            document: DecodedTextDocument(text: "rose rose rose bloom bloom field", encodingName: "utf-8"),
            sourceType: "txt",
            representedPath: "/tmp/demo.txt",
            importedAt: "2026-04-08T00:00:00Z"
        )

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(databaseURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let names = try indexNames(in: db)
        XCTAssertTrue(names.contains("idx_token_frequency_count"))
        XCTAssertTrue(names.contains("idx_token_frequency_rank"))
        XCTAssertTrue(names.contains("idx_token_frequency_norm_frequency"))
        XCTAssertTrue(names.contains("idx_token_frequency_sentence_range"))
        XCTAssertTrue(names.contains("idx_token_frequency_paragraph_range"))
        XCTAssertTrue(names.contains("idx_token_position_exact_term"))
        XCTAssertTrue(names.contains("idx_token_position_normalized_term"))
    }

    func testWriteDocumentCreatesMetadataIndexesForCorpusDocumentTable() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-document-indexes-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        try NativeCorpusDatabaseSupport.writeDocument(
            at: databaseURL,
            document: DecodedTextDocument(text: "rose rose rose bloom bloom field", encodingName: "utf-8"),
            sourceType: "txt",
            representedPath: "/tmp/demo.txt",
            importedAt: "2026-04-08T00:00:00Z"
        )

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(databaseURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let names = try indexNames(in: db)
        XCTAssertTrue(names.contains("idx_corpus_document_imported_at"))
        XCTAssertTrue(names.contains("idx_corpus_document_represented_path"))
        XCTAssertTrue(names.contains("idx_corpus_document_source_label"))
        XCTAssertTrue(names.contains("idx_corpus_document_year_label"))
        XCTAssertTrue(names.contains("idx_corpus_document_genre_label"))
        XCTAssertTrue(names.contains("idx_corpus_document_tags_text"))
    }

    func testWriteDocumentStoresRawAndCleanedTextWithCleaningMetadata() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-document-cleaning-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        let rawText = "\u{FEFF}\nAlpha\u{00A0}Beta\t\u{200B}\r\nLine\u{0000} two  \n\n"
        let cleaned = CorpusAutoCleaningSupport.clean(rawText)
        let summary = CorpusAutoCleaningSupport.makeReportSummary(
            from: cleaned,
            cleanedAt: "2026-04-11T00:00:00Z"
        )

        try NativeCorpusDatabaseSupport.writeDocument(
            at: databaseURL,
            document: DecodedTextDocument(text: cleaned.cleanedText, encodingName: "utf-8"),
            sourceType: "txt",
            representedPath: "/tmp/demo.txt",
            importedAt: "2026-04-11T00:00:00Z",
            rawText: cleaned.rawText,
            cleaningSummary: summary
        )

        let storedDocument = try XCTUnwrap(NativeCorpusDatabaseSupport.readDocument(at: databaseURL))
        XCTAssertEqual(storedDocument.rawText, rawText)
        XCTAssertEqual(storedDocument.text, "Alpha Beta\nLine two")
        XCTAssertEqual(storedDocument.metadata.cleaningProfileVersion, CorpusAutoCleaningSupport.profileVersion)
        XCTAssertEqual(storedDocument.metadata.originalCharacterCount, rawText.count)
        XCTAssertEqual(storedDocument.metadata.cleanedCharacterCount, "Alpha Beta\nLine two".count)
        XCTAssertEqual(storedDocument.metadata.cleaningRuleHits, cleaned.ruleHits)
    }

    func testWriteDocumentPopulatesRelationalShardTablesAndSchemaMigration() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-relational-shard-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        let rawText = "\u{FEFF}\nAlpha\u{00A0}beta.\nGamma delta\t\u{200B}\n"
        let cleaned = CorpusAutoCleaningSupport.clean(rawText)
        let summary = CorpusAutoCleaningSupport.makeReportSummary(
            from: cleaned,
            cleanedAt: "2026-04-21T00:00:00Z"
        )

        try NativeCorpusDatabaseSupport.writeDocument(
            at: databaseURL,
            document: DecodedTextDocument(text: cleaned.cleanedText, encodingName: "utf-8"),
            sourceType: "txt",
            representedPath: "/tmp/demo.txt",
            importedAt: "2026-04-21T00:00:00Z",
            rawText: cleaned.rawText,
            cleaningSummary: summary
        )

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(databaseURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let names = try tableNames(in: db)
        XCTAssertTrue(names.contains("schema_migrations"))
        XCTAssertTrue(names.contains("cleaning_rule_hit"))
        XCTAssertTrue(names.contains("sentence"))
        XCTAssertTrue(names.contains("token"))

        XCTAssertEqual(try scalarInt("SELECT COUNT(*) FROM schema_migrations;", in: db), 1)
        XCTAssertEqual(try scalarInt("SELECT COUNT(*) FROM sentence;", in: db), 2)
        XCTAssertEqual(try scalarInt("SELECT COUNT(*) FROM token;", in: db), 4)
        XCTAssertEqual(try scalarInt("SELECT COUNT(*) FROM cleaning_rule_hit;", in: db), cleaned.ruleHits.count)
        XCTAssertEqual(try scalarText("SELECT tokenized_sentences_json FROM corpus_document WHERE id = 1;", in: db), "")
        XCTAssertEqual(
            try scalarInt("SELECT schema_version FROM corpus_document WHERE id = 1;", in: db),
            NativeCorpusDatabaseSupport.currentSchemaVersion
        )
    }

    func testWriteDocumentPopulatesSentenceFTSAndSupportsPrefixMatch() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-sentence-fts-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        try NativeCorpusDatabaseSupport.writeDocument(
            at: databaseURL,
            document: DecodedTextDocument(text: "Alpha beta.\nGamma delta alpha.", encodingName: "utf-8"),
            sourceType: "txt",
            representedPath: "/tmp/demo.txt",
            importedAt: "2026-04-24T00:00:00Z"
        )

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(databaseURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }

        let names = try tableNames(in: db)
        XCTAssertTrue(names.contains("sentence_fts"))
        XCTAssertEqual(try scalarInt("SELECT COUNT(*) FROM sentence_fts;", in: db), 2)
        XCTAssertEqual(try scalarInt("SELECT COUNT(*) FROM sentence_fts WHERE sentence_fts MATCH 'alph*';", in: db), 2)
        XCTAssertEqual(try scalarInt("SELECT COUNT(*) FROM sentence_fts WHERE sentence_fts MATCH 'gamm*';", in: db), 1)
    }

    func testLoadCandidateSentenceIDsFindsPhraseCandidatesFromStoredShard() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-sentence-candidates-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        try NativeCorpusDatabaseSupport.writeDocument(
            at: databaseURL,
            document: DecodedTextDocument(
                text: "Alpha beta gamma.\nAlpha delta theta.\nAlpha beta again.",
                encodingName: "utf-8"
            ),
            sourceType: "txt",
            representedPath: "/tmp/demo.txt",
            importedAt: "2026-04-24T00:00:00Z"
        )

        let sentenceIDs = try NativeCorpusDatabaseSupport.loadCandidateSentenceIDs(
            at: databaseURL,
            phraseTokens: ["alpha", "beta"]
        )

        XCTAssertEqual(sentenceIDs, [0, 2])
    }

    func testReadStoredFrequencyArtifactReusesPersistedStatsAndRows() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-frequency-artifact-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        try NativeCorpusDatabaseSupport.writeDocument(
            at: databaseURL,
            document: DecodedTextDocument(text: "alpha beta.\nalpha alpha gamma", encodingName: "utf-8"),
            sourceType: "txt",
            representedPath: "/tmp/demo.txt",
            importedAt: "2026-04-12T00:00:00Z"
        )

        let artifact = try XCTUnwrap(NativeCorpusDatabaseSupport.readStoredFrequencyArtifact(at: databaseURL))

        XCTAssertEqual(artifact.tokenCount, 5)
        XCTAssertEqual(artifact.typeCount, 3)
        XCTAssertEqual(artifact.sentenceCount, 2)
        XCTAssertEqual(artifact.paragraphCount, 1)
        XCTAssertEqual(artifact.topWord, "alpha")
        XCTAssertEqual(artifact.topWordCount, 3)
        XCTAssertEqual(artifact.frequencyMap["gamma"], 1)
        XCTAssertEqual(artifact.textDigest, DocumentCacheKey(text: "alpha beta.\nalpha alpha gamma").textDigest)
    }

    func testReadStoredTokenizedArtifactReusesPersistedSentencesAndAnnotations() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-tokenized-artifact-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        try NativeCorpusDatabaseSupport.writeDocument(
            at: databaseURL,
            document: DecodedTextDocument(text: "Running beta.\nGAMMA delta!", encodingName: "utf-8"),
            sourceType: "txt",
            representedPath: "/tmp/demo.txt",
            importedAt: "2026-04-12T00:00:00Z"
        )

        let artifact = try XCTUnwrap(NativeCorpusDatabaseSupport.readStoredTokenizedArtifact(at: databaseURL))

        XCTAssertEqual(artifact.textDigest, DocumentCacheKey(text: "Running beta.\nGAMMA delta!").textDigest)
        XCTAssertEqual(artifact.sentenceCount, 2)
        XCTAssertEqual(artifact.tokenCount, 4)
        XCTAssertEqual(artifact.sentences.first?.tokens.map(\.original), ["Running", "beta"])
        XCTAssertEqual(artifact.sentences.last?.tokens.map(\.normalized), ["gamma", "delta"])
        XCTAssertEqual(artifact.sentences.first?.tokens.first?.annotations.script, .latin)
    }

    func testReadStoredTokenizedArtifactFallsBackToRelationalTablesWhenJSONBlobMissing() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-tokenized-relational-fallback-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        try NativeCorpusDatabaseSupport.writeDocument(
            at: databaseURL,
            document: DecodedTextDocument(text: "Running beta.\nGAMMA delta!", encodingName: "utf-8"),
            sourceType: "txt",
            representedPath: "/tmp/demo.txt",
            importedAt: "2026-04-12T00:00:00Z"
        )

        var db: OpaquePointer?
        XCTAssertEqual(sqlite3_open(databaseURL.path, &db), SQLITE_OK)
        defer { sqlite3_close(db) }
        XCTAssertEqual(
            sqlite3_exec(db, "UPDATE corpus_document SET tokenized_sentences_json = '' WHERE id = 1;", nil, nil, nil),
            SQLITE_OK
        )

        let artifact = try XCTUnwrap(NativeCorpusDatabaseSupport.readStoredTokenizedArtifact(at: databaseURL))

        XCTAssertEqual(artifact.sentenceCount, 2)
        XCTAssertEqual(artifact.tokenCount, 4)
        XCTAssertEqual(artifact.sentences.first?.text, "Running beta.")
        XCTAssertEqual(artifact.sentences.last?.tokens.map(\.normalized), ["gamma", "delta"])
        XCTAssertEqual(artifact.sentences.last?.tokens.last?.annotations.script, .latin)
    }

    func testReadStoredTokenPositionIndexArtifactReusesPersistedPositions() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-position-artifact-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        try NativeCorpusDatabaseSupport.writeDocument(
            at: databaseURL,
            document: DecodedTextDocument(text: "Alpha beta alpha.\nALPHA gamma", encodingName: "utf-8"),
            sourceType: "txt",
            representedPath: "/tmp/demo.txt",
            importedAt: "2026-04-12T00:00:00Z"
        )

        let artifact = try XCTUnwrap(NativeCorpusDatabaseSupport.readStoredTokenPositionIndexArtifact(at: databaseURL))
        let normalizedAlpha = artifact.positions(
            for: .init(mode: .normalized, key: AnalysisTextNormalizationSupport.normalizeSearchText("alpha", caseSensitive: false))
        )
        let exactAlpha = artifact.positions(
            for: .init(mode: .exact, key: AnalysisTextNormalizationSupport.normalizeSearchText("Alpha", caseSensitive: true))
        )

        XCTAssertEqual(artifact.textDigest, DocumentCacheKey(text: "Alpha beta alpha.\nALPHA gamma").textDigest)
        XCTAssertEqual(normalizedAlpha.count, 3)
        XCTAssertEqual(exactAlpha.count, 1)
        XCTAssertEqual(exactAlpha.first, StoredTokenPosition(sentenceId: 0, tokenIndex: 0))
    }

    func testReadStoredLocatorResultLoadsSentenceWindowFromShardTables() throws {
        let databaseURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("wordz-locator-artifact-\(UUID().uuidString).db")
        defer { try? FileManager.default.removeItem(at: databaseURL) }

        try NativeCorpusDatabaseSupport.writeDocument(
            at: databaseURL,
            document: DecodedTextDocument(
                text: "Alpha beta gamma.\nDelta alpha.\nOmega zeta.",
                encodingName: "utf-8"
            ),
            sourceType: "txt",
            representedPath: "/tmp/demo.txt",
            importedAt: "2026-04-12T00:00:00Z"
        )

        let result = try XCTUnwrap(
            NativeCorpusDatabaseSupport.readStoredLocatorResult(
                at: databaseURL,
                sentenceId: 1,
                nodeIndex: 1,
                leftWindow: 1,
                rightWindow: 1
            )
        )

        XCTAssertEqual(result.sentenceCount, 3)
        XCTAssertEqual(result.rows.map(\.sentenceId), [0, 1, 2])
        XCTAssertEqual(result.rows[0].status, "前文")
        XCTAssertEqual(result.rows[1].leftWords, "Delta")
        XCTAssertEqual(result.rows[1].nodeWord, "alpha")
        XCTAssertEqual(result.rows[1].rightWords, "")
        XCTAssertEqual(result.rows[2].status, "后文")
    }

    private func indexNames(in db: OpaquePointer?) throws -> Set<String> {
        var statement: OpaquePointer?
        let sql = "SELECT name FROM sqlite_master WHERE type = 'index';"
        XCTAssertEqual(sqlite3_prepare_v2(db, sql, -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }

        var names: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let rawName = sqlite3_column_text(statement, 0) {
                names.insert(String(cString: rawName))
            }
        }
        return names
    }

    private func tableNames(in db: OpaquePointer?) throws -> Set<String> {
        var statement: OpaquePointer?
        let sql = "SELECT name FROM sqlite_master WHERE type = 'table';"
        XCTAssertEqual(sqlite3_prepare_v2(db, sql, -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }

        var names: Set<String> = []
        while sqlite3_step(statement) == SQLITE_ROW {
            if let rawName = sqlite3_column_text(statement, 0) {
                names.insert(String(cString: rawName))
            }
        }
        return names
    }

    private func scalarInt(_ sql: String, in db: OpaquePointer?) throws -> Int {
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, sql, -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func scalarText(_ sql: String, in db: OpaquePointer?) throws -> String {
        var statement: OpaquePointer?
        XCTAssertEqual(sqlite3_prepare_v2(db, sql, -1, &statement, nil), SQLITE_OK)
        defer { sqlite3_finalize(statement) }
        XCTAssertEqual(sqlite3_step(statement), SQLITE_ROW)
        guard let rawValue = sqlite3_column_text(statement, 0) else {
            return ""
        }
        return String(cString: rawValue)
    }
}
