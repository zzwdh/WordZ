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
}
