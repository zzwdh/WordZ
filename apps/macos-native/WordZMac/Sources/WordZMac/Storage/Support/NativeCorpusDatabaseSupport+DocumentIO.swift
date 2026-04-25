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
            sttr: doubleColumn(statement, index: offset + 15),
            cleanedAt: stringColumn(statement, index: offset + 16),
            cleaningProfileVersion: stringColumn(statement, index: offset + 17),
            cleaningRuleHits: decodeCleaningRuleHits(from: stringColumn(statement, index: offset + 18)),
            originalCharacterCount: Int(sqlite3_column_int(statement, offset + 19)),
            cleanedCharacterCount: Int(sqlite3_column_int(statement, offset + 20)),
            cleanedTextDigest: stringColumn(statement, index: offset + 21)
        )
    }

    static func insertDocument(
        rawText: String,
        cleanedText: String,
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
                cleaned_at,
                cleaning_profile_version,
                cleaning_rule_hits_json,
                original_character_count,
                cleaned_character_count,
                cleaned_text_digest,
                tokenized_sentences_json,
                raw_text,
                cleaned_text,
                text
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
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
        bindText(metadata.cleanedAt, to: statement, index: 18)
        bindText(metadata.cleaningProfileVersion, to: statement, index: 19)
        bindText(encodeCleaningRuleHits(metadata.cleaningRuleHits), to: statement, index: 20)
        sqlite3_bind_int(statement, 21, Int32(metadata.originalCharacterCount))
        sqlite3_bind_int(statement, 22, Int32(metadata.cleanedCharacterCount))
        bindText(metadata.cleanedTextDigest, to: statement, index: 23)
        bindText("", to: statement, index: 24)
        bindText(rawText, to: statement, index: 25)
        bindText(cleanedText, to: statement, index: 26)
        bindText(cleanedText, to: statement, index: 27)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError(on: db, message: "无法写入语料正文")
        }
    }

    static func encodeCleaningRuleHits(_ ruleHits: [LibraryCorpusCleaningRuleHit]) -> String {
        guard !ruleHits.isEmpty else { return "[]" }
        let jsonObject = ruleHits.map(\.jsonObject)
        guard JSONSerialization.isValidJSONObject(jsonObject),
              let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: []),
              let text = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return text
    }

    static func decodeCleaningRuleHits(from rawValue: String) -> [LibraryCorpusCleaningRuleHit] {
        guard let data = rawValue.data(using: .utf8),
              let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []),
              let items = jsonObject as? [JSONObject] else {
            return []
        }
        return items.map(LibraryCorpusCleaningRuleHit.init)
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

    static func insertCleaningRuleHits(_ ruleHits: [LibraryCorpusCleaningRuleHit], into db: OpaquePointer?) throws {
        guard !ruleHits.isEmpty else { return }
        let statement = try prepare(
            """
            INSERT INTO cleaning_rule_hit (
                rule_id,
                hit_count,
                position
            ) VALUES (?, ?, ?);
            """,
            on: db
        )
        defer { sqlite3_finalize(statement) }

        for (position, ruleHit) in ruleHits.enumerated() {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            bindText(ruleHit.id, to: statement, index: 1)
            sqlite3_bind_int(statement, 2, Int32(ruleHit.count))
            sqlite3_bind_int(statement, 3, Int32(position))

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw databaseError(on: db, message: "无法写入清洗命中")
            }
        }
    }

    static func insertSentences(_ sentences: [ParsedSentence], into db: OpaquePointer?) throws {
        guard !sentences.isEmpty else { return }
        let statement = try prepare(
            """
            INSERT INTO sentence (
                sentence_id,
                paragraph_id,
                text,
                token_count
            ) VALUES (?, ?, ?, ?);
            """,
            on: db
        )
        defer { sqlite3_finalize(statement) }

        for sentence in sentences {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            sqlite3_bind_int(statement, 1, Int32(sentence.sentenceId))
            sqlite3_bind_int(statement, 2, Int32(sentence.paragraphId))
            bindText(sentence.text, to: statement, index: 3)
            sqlite3_bind_int(statement, 4, Int32(sentence.tokens.count))

            guard sqlite3_step(statement) == SQLITE_DONE else {
                throw databaseError(on: db, message: "无法写入句子索引")
            }
        }
    }

    static func rebuildSentenceSearchIndex(into db: OpaquePointer?) throws {
        try execute("INSERT INTO sentence_fts(sentence_fts) VALUES('rebuild');", on: db)
    }

    static func insertTokens(from sentences: [ParsedSentence], into db: OpaquePointer?) throws {
        guard !sentences.isEmpty else { return }
        let statement = try prepare(
            """
            INSERT INTO token (
                sentence_id,
                token_index,
                paragraph_id,
                original_term,
                normalized_term,
                lemma,
                lexical_class,
                script
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?);
            """,
            on: db
        )
        defer { sqlite3_finalize(statement) }

        for sentence in sentences {
            for token in sentence.tokens {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                sqlite3_bind_int(statement, 1, Int32(token.sentenceId))
                sqlite3_bind_int(statement, 2, Int32(token.tokenIndex))
                sqlite3_bind_int(statement, 3, Int32(sentence.paragraphId))
                bindText(token.original, to: statement, index: 4)
                bindText(token.normalized, to: statement, index: 5)
                bindText(token.annotations.lemma ?? "", to: statement, index: 6)
                bindText(token.annotations.lexicalClass?.rawValue ?? "", to: statement, index: 7)
                bindText(token.annotations.script.rawValue, to: statement, index: 8)

                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw databaseError(on: db, message: "无法写入 token 索引")
                }
            }
        }
    }

    static func insertTokenPositions(_ sentences: [TokenizedSentence], into db: OpaquePointer?) throws {
        let statement = try prepare(
            """
            INSERT INTO token_position (
                sentence_id,
                token_index,
                exact_term,
                normalized_term
            ) VALUES (?, ?, ?, ?);
            """,
            on: db
        )
        defer { sqlite3_finalize(statement) }

        for sentence in sentences {
            for token in sentence.tokens {
                sqlite3_reset(statement)
                sqlite3_clear_bindings(statement)
                sqlite3_bind_int(statement, 1, Int32(token.sentenceId))
                sqlite3_bind_int(statement, 2, Int32(token.tokenIndex))
                bindText(AnalysisTextNormalizationSupport.normalizeSearchText(token.original, caseSensitive: true), to: statement, index: 3)
                bindText(token.normalized, to: statement, index: 4)

                guard sqlite3_step(statement) == SQLITE_DONE else {
                    throw databaseError(on: db, message: "无法写入位置索引")
                }
            }
        }
    }

    static func recordSchemaMigration(version: Int, description: String, into db: OpaquePointer?) throws {
        let statement = try prepare(
            """
            INSERT OR REPLACE INTO schema_migrations (
                version,
                applied_at,
                description
            ) VALUES (?, ?, ?);
            """,
            on: db
        )
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int(statement, 1, Int32(version))
        bindText(NativeDateFormatting.iso8601String(from: Date()), to: statement, index: 2)
        bindText(description, to: statement, index: 3)

        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw databaseError(on: db, message: "无法记录语料分片迁移")
        }
    }
}
