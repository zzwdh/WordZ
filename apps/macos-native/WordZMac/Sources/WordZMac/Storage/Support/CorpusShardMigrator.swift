import Foundation

struct CorpusShardMigrator {
    struct MigrationResult {
        let didMigrate: Bool
        let record: NativeCorpusRecord
    }

    private struct MigrationPayload {
        let document: DecodedTextDocument
        let sourceType: String
        let representedPath: String
        let importedAt: String
        let metadataProfile: CorpusMetadataProfile
        let rawText: String
        let cleaningSummary: LibraryCorpusCleaningReportSummary?
    }

    let fileManager: FileManager

    func migrateIfNeeded(
        at url: URL,
        record: NativeCorpusRecord,
        destinationDirectoryURL: URL
    ) throws -> MigrationResult {
        guard fileManager.fileExists(atPath: url.path) else {
            return MigrationResult(didMigrate: false, record: record)
        }

        let targetFileName = canonicalStorageFileName(for: record)
        let targetURL = destinationDirectoryURL.appendingPathComponent(targetFileName)
        let requiresRelocation = standardizedURL(url) != standardizedURL(targetURL)
        let metadata = try NativeCorpusDatabaseSupport.readMetadata(at: url)
        let requiresSchemaMigration = (metadata?.schemaVersion ?? 0) > 0
            && metadata?.schemaVersion != NativeCorpusDatabaseSupport.currentSchemaVersion
        let requiresLegacyConversion = metadata == nil && canMigrateStorage(at: url)

        guard requiresRelocation || requiresSchemaMigration || requiresLegacyConversion else {
            return MigrationResult(didMigrate: false, record: record)
        }

        guard let payload = try migrationPayload(from: url, record: record) else {
            return MigrationResult(didMigrate: false, record: record)
        }

        try NativeCorpusDatabaseSupport.writeDocument(
            at: targetURL,
            document: payload.document,
            sourceType: payload.sourceType,
            representedPath: payload.representedPath,
            importedAt: payload.importedAt,
            metadataProfile: payload.metadataProfile,
            rawText: payload.rawText,
            cleaningSummary: payload.cleaningSummary
        )

        if requiresRelocation && fileManager.fileExists(atPath: url.path) {
            try? fileManager.removeItem(at: url)
        }

        return MigrationResult(
            didMigrate: true,
            record: NativeCorpusRecord(
                id: record.id,
                name: record.name,
                folderId: record.folderId,
                folderName: record.folderName,
                sourceType: payload.sourceType,
                representedPath: payload.representedPath,
                storageFileName: targetFileName,
                metadata: payload.metadataProfile,
                cleaningSummary: payload.cleaningSummary
            )
        )
    }

    func needsMigration(at url: URL) throws -> Bool {
        guard let metadata = try NativeCorpusDatabaseSupport.readMetadata(at: url) else {
            return false
        }
        return metadata.schemaVersion < NativeCorpusDatabaseSupport.currentSchemaVersion
    }

    private func canonicalStorageFileName(for record: NativeCorpusRecord) -> String {
        guard !record.storageFileName.lowercased().hasSuffix(".db") else {
            return record.storageFileName
        }
        return "\(record.id).db"
    }

    func canMigrateStorage(at url: URL) -> Bool {
        if (try? NativeCorpusDatabaseSupport.readDocument(at: url)) != nil {
            return true
        }
        if let data = try? Data(contentsOf: url, options: [.mappedIfSafe]), !data.isEmpty {
            if (try? JSONDecoder().decode(NativeStoredCorpusDocument.self, from: data)) != nil {
                return true
            }
            return (try? TextFileDecodingSupport.readTextDocument(at: url)) != nil
        }
        return false
    }

    private func migrationPayload(from url: URL, record: NativeCorpusRecord) throws -> MigrationPayload? {
        if let storedDocument = try NativeCorpusDatabaseSupport.readDocument(at: url) {
            let mergedMetadata = storedDocument.metadata.metadataProfile.merged(over: record.metadata)
            return MigrationPayload(
                document: DecodedTextDocument(
                    text: storedDocument.text,
                    encodingName: storedDocument.metadata.detectedEncoding
                ),
                sourceType: storedDocument.metadata.sourceType.isEmpty ? record.sourceType : storedDocument.metadata.sourceType,
                representedPath: storedDocument.metadata.representedPath.isEmpty
                    ? fallbackRepresentedPath(for: record, storageURL: url)
                    : storedDocument.metadata.representedPath,
                importedAt: storedDocument.metadata.importedAt.isEmpty
                    ? NativeDateFormatting.iso8601String(from: Date())
                    : storedDocument.metadata.importedAt,
                metadataProfile: mergedMetadata,
                rawText: storedDocument.rawText.isEmpty ? storedDocument.text : storedDocument.rawText,
                cleaningSummary: storedDocument.metadata.cleaningSummary ?? record.cleaningSummary
            )
        }

        if let legacyDocument = try readLegacyJSONDocument(at: url) {
            return MigrationPayload(
                document: DecodedTextDocument(
                    text: legacyDocument.text,
                    encodingName: legacyDocument.detectedEncoding
                ),
                sourceType: legacyDocument.sourceType.isEmpty ? record.sourceType : legacyDocument.sourceType,
                representedPath: legacyDocument.representedPath.isEmpty
                    ? fallbackRepresentedPath(for: record, storageURL: url)
                    : legacyDocument.representedPath,
                importedAt: legacyDocument.importedAt.isEmpty
                    ? NativeDateFormatting.iso8601String(from: Date())
                    : legacyDocument.importedAt,
                metadataProfile: record.metadata,
                rawText: legacyDocument.text,
                cleaningSummary: record.cleaningSummary
            )
        }

        guard let decoded = try? TextFileDecodingSupport.readTextDocument(at: url) else {
            return nil
        }
        return MigrationPayload(
            document: decoded,
            sourceType: record.sourceType,
            representedPath: fallbackRepresentedPath(for: record, storageURL: url),
            importedAt: NativeDateFormatting.iso8601String(from: Date()),
            metadataProfile: record.metadata,
            rawText: decoded.text,
            cleaningSummary: record.cleaningSummary
        )
    }

    private func readLegacyJSONDocument(at url: URL) throws -> NativeStoredCorpusDocument? {
        let data = try Data(contentsOf: url, options: [.mappedIfSafe])
        guard !data.isEmpty else { return nil }
        return try? JSONDecoder().decode(NativeStoredCorpusDocument.self, from: data)
    }

    private func fallbackRepresentedPath(for record: NativeCorpusRecord, storageURL: URL) -> String {
        record.representedPath.isEmpty ? storageURL.path : record.representedPath
    }

    private func standardizedURL(_ url: URL) -> URL {
        url.standardizedFileURL
    }
}
