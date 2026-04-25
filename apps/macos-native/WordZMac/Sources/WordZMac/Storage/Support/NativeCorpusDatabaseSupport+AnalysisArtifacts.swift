import Foundation
import SQLite3

extension NativeCorpusDatabaseSupport {
    static func readStoredFrequencyArtifact(at url: URL) throws -> StoredFrequencyArtifact? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let db = try openDatabase(at: url, flags: SQLITE_OPEN_READWRITE)
        defer { sqlite3_close(db) }

        try ensureDocumentSchema(on: db)

        let metadataStatement = try prepare(
            """
            SELECT token_count,
                   type_count,
                   sentence_count,
                   paragraph_count,
                   ttr,
                   sttr,
                   cleaned_text_digest,
                   cleaned_text,
                   text
            FROM corpus_document
            WHERE id = 1;
            """,
            on: db
        )
        defer { sqlite3_finalize(metadataStatement) }

        guard sqlite3_step(metadataStatement) == SQLITE_ROW else {
            return nil
        }

        let tokenCount = Int(sqlite3_column_int(metadataStatement, 0))
        let typeCount = Int(sqlite3_column_int(metadataStatement, 1))
        let sentenceCount = Int(sqlite3_column_int(metadataStatement, 2))
        let paragraphCount = Int(sqlite3_column_int(metadataStatement, 3))
        let ttr = doubleColumn(metadataStatement, index: 4)
        let sttr = doubleColumn(metadataStatement, index: 5)
        let storedDigest = stringColumn(metadataStatement, index: 6)
        let cleanedText = stringColumn(metadataStatement, index: 7)
        let legacyText = stringColumn(metadataStatement, index: 8)
        let resolvedDigest: String
        if storedDigest.isEmpty {
            let storedText = preferredStoredText(cleanedText: cleanedText, legacyText: legacyText)
            resolvedDigest = DocumentCacheKey(text: storedText).textDigest
        } else {
            resolvedDigest = storedDigest
        }

        let rowsStatement = try prepare(
            """
            SELECT term,
                   count,
                   rank_index,
                   norm_frequency,
                   sentence_range,
                   paragraph_range
            FROM token_frequency
            ORDER BY rank_index ASC, term ASC;
            """,
            on: db
        )
        defer { sqlite3_finalize(rowsStatement) }

        var rows: [FrequencyRow] = []
        while sqlite3_step(rowsStatement) == SQLITE_ROW {
            let term = stringColumn(rowsStatement, index: 0)
            let count = Int(sqlite3_column_int(rowsStatement, 1))
            let rank = Int(sqlite3_column_int(rowsStatement, 2))
            let normFrequency = doubleColumn(rowsStatement, index: 3)
            let sentenceRange = Int(sqlite3_column_int(rowsStatement, 4))
            let paragraphRange = Int(sqlite3_column_int(rowsStatement, 5))
            let normRange = sentenceCount > 0
                ? (Double(sentenceRange) / Double(sentenceCount)) * 100
                : 0
            rows.append(
                FrequencyRow(
                    word: term,
                    count: count,
                    rank: rank,
                    normFreq: normFrequency,
                    range: sentenceRange,
                    normRange: normRange,
                    sentenceRange: sentenceRange,
                    paragraphRange: paragraphRange
                )
            )
        }

        return StoredFrequencyArtifact(
            textDigest: resolvedDigest,
            tokenCount: tokenCount,
            typeCount: typeCount,
            sentenceCount: sentenceCount,
            paragraphCount: paragraphCount,
            ttr: ttr > 0 ? ttr : fallbackTTR(typeCount: typeCount, tokenCount: tokenCount),
            sttr: sttr,
            frequencyRows: rows
        )
    }

    static func fallbackTTR(typeCount: Int, tokenCount: Int) -> Double {
        guard tokenCount > 0 else { return 0 }
        return Double(typeCount) / Double(tokenCount)
    }

    static func readStoredTokenizedArtifact(at url: URL) throws -> StoredTokenizedArtifact? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let db = try openDatabase(at: url, flags: SQLITE_OPEN_READWRITE)
        defer { sqlite3_close(db) }

        try ensureDocumentSchema(on: db)

        let statement = try prepare(
            """
            SELECT cleaned_text_digest,
                   cleaned_text,
                   text,
                   tokenized_sentences_json
            FROM corpus_document
            WHERE id = 1;
            """,
            on: db
        )
        defer { sqlite3_finalize(statement) }

        guard sqlite3_step(statement) == SQLITE_ROW else {
            return nil
        }

        let storedDigest = stringColumn(statement, index: 0)
        let cleanedText = stringColumn(statement, index: 1)
        let legacyText = stringColumn(statement, index: 2)
        let resolvedDigest: String
        if storedDigest.isEmpty {
            let storedText = preferredStoredText(cleanedText: cleanedText, legacyText: legacyText)
            resolvedDigest = DocumentCacheKey(text: storedText).textDigest
        } else {
            resolvedDigest = storedDigest
        }

        let relationalSentences = try readTokenizedSentencesFromRelationalTables(on: db)
        if !relationalSentences.isEmpty {
            return StoredTokenizedArtifact(textDigest: resolvedDigest, sentences: relationalSentences)
        }

        let tokenizedSentencesJSON = stringColumn(statement, index: 3)
        guard !tokenizedSentencesJSON.isEmpty else {
            return nil
        }

        let sentences = decodeTokenizedSentences(from: tokenizedSentencesJSON)
        guard !sentences.isEmpty else {
            return nil
        }
        return StoredTokenizedArtifact(textDigest: resolvedDigest, sentences: sentences)
    }

    static func decodeTokenizedSentences(from rawValue: String) -> [TokenizedSentence] {
        guard let data = rawValue.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let items = jsonObject as? [JSONObject] else {
            return []
        }
        return items.map(TokenizedSentence.init)
    }

    private static func readTokenizedSentencesFromRelationalTables(
        on db: OpaquePointer?
    ) throws -> [TokenizedSentence] {
        let sentenceStatement = try prepare(
            """
            SELECT sentence_id,
                   text
            FROM sentence
            ORDER BY sentence_id ASC;
            """,
            on: db
        )
        defer { sqlite3_finalize(sentenceStatement) }

        var sentenceOrder: [Int] = []
        var sentenceTextByID: [Int: String] = [:]
        while sqlite3_step(sentenceStatement) == SQLITE_ROW {
            let sentenceID = Int(sqlite3_column_int(sentenceStatement, 0))
            sentenceOrder.append(sentenceID)
            sentenceTextByID[sentenceID] = stringColumn(sentenceStatement, index: 1)
        }
        guard !sentenceOrder.isEmpty else { return [] }

        let tokenStatement = try prepare(
            """
            SELECT sentence_id,
                   token_index,
                   original_term,
                   normalized_term,
                   lemma,
                   lexical_class,
                   script
            FROM token
            ORDER BY sentence_id ASC, token_index ASC;
            """,
            on: db
        )
        defer { sqlite3_finalize(tokenStatement) }

        var tokensBySentenceID: [Int: [TokenizedToken]] = [:]
        while sqlite3_step(tokenStatement) == SQLITE_ROW {
            let sentenceID = Int(sqlite3_column_int(tokenStatement, 0))
            let tokenIndex = Int(sqlite3_column_int(tokenStatement, 1))
            let lemma = normalizedOptionalString(stringColumn(tokenStatement, index: 4))
            let lexicalClass = TokenLexicalClass(rawValue: stringColumn(tokenStatement, index: 5))
            let script = TokenScript(rawValue: stringColumn(tokenStatement, index: 6)) ?? .other

            tokensBySentenceID[sentenceID, default: []].append(
                TokenizedToken(
                    original: stringColumn(tokenStatement, index: 2),
                    normalized: stringColumn(tokenStatement, index: 3),
                    sentenceId: sentenceID,
                    tokenIndex: tokenIndex,
                    annotations: TokenLinguisticAnnotations(
                        script: script,
                        lemma: lemma,
                        lexicalClass: lexicalClass
                    )
                )
            )
        }

        return sentenceOrder.map { sentenceID in
            TokenizedSentence(
                sentenceId: sentenceID,
                text: sentenceTextByID[sentenceID, default: ""],
                tokens: tokensBySentenceID[sentenceID, default: []]
            )
        }
    }

    private static func normalizedOptionalString(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func readStoredTokenPositionIndexArtifact(at url: URL) throws -> StoredTokenPositionIndexArtifact? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let db = try openDatabase(at: url, flags: SQLITE_OPEN_READWRITE)
        defer { sqlite3_close(db) }

        try ensureDocumentSchema(on: db)

        let metadataStatement = try prepare(
            """
            SELECT cleaned_text_digest,
                   cleaned_text,
                   text
            FROM corpus_document
            WHERE id = 1;
            """,
            on: db
        )
        defer { sqlite3_finalize(metadataStatement) }

        guard sqlite3_step(metadataStatement) == SQLITE_ROW else {
            return nil
        }

        let storedDigest = stringColumn(metadataStatement, index: 0)
        let cleanedText = stringColumn(metadataStatement, index: 1)
        let legacyText = stringColumn(metadataStatement, index: 2)
        let resolvedDigest: String
        if storedDigest.isEmpty {
            let storedText = preferredStoredText(cleanedText: cleanedText, legacyText: legacyText)
            resolvedDigest = DocumentCacheKey(text: storedText).textDigest
        } else {
            resolvedDigest = storedDigest
        }

        let positionsStatement = try prepare(
            """
            SELECT exact_term,
                   normalized_term,
                   sentence_id,
                   token_index
            FROM token_position
            ORDER BY sentence_id ASC, token_index ASC;
            """,
            on: db
        )
        defer { sqlite3_finalize(positionsStatement) }

        var exactPositions: [String: [StoredTokenPosition]] = [:]
        var normalizedPositions: [String: [StoredTokenPosition]] = [:]

        while sqlite3_step(positionsStatement) == SQLITE_ROW {
            let exactTerm = stringColumn(positionsStatement, index: 0)
            let normalizedTerm = stringColumn(positionsStatement, index: 1)
            let position = StoredTokenPosition(
                sentenceId: Int(sqlite3_column_int(positionsStatement, 2)),
                tokenIndex: Int(sqlite3_column_int(positionsStatement, 3))
            )
            exactPositions[exactTerm, default: []].append(position)
            normalizedPositions[normalizedTerm, default: []].append(position)
        }

        guard !exactPositions.isEmpty || !normalizedPositions.isEmpty else {
            return nil
        }

        return StoredTokenPositionIndexArtifact(
            textDigest: resolvedDigest,
            exactPositions: exactPositions,
            normalizedPositions: normalizedPositions
        )
    }
}
