import CryptoKit
import Foundation
import SQLite3

extension LibraryCatalogStore {
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

    func catalogProjection(for corpus: NativeCorpusRecord) -> CatalogProjection {
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

    func sha256Hex(for url: URL) -> String {
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            return ""
        }
        return SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
    }
}
