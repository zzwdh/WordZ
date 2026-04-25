import Foundation

extension NativeCorpusStore {
    func snapshotLibraryCatalogMutation(
        _ transaction: StorageMutationTransaction,
        folders: [NativeFolderRecord]? = nil,
        corpora: [NativeCorpusRecord]? = nil,
        recycleEntries: [NativeRecycleRecord]? = nil
    ) throws {
        try transaction.snapshotDatabase(at: libraryDatabaseURL, configuration: .libraryCatalog)
        transaction.registerRollback { [self, folders, corpora, recycleEntries] in
            if let folders {
                cachedFolders = folders
            }
            if let corpora {
                cachedCorpora = corpora
            }
            if let recycleEntries {
                cachedRecycleEntries = recycleEntries
            }
        }
    }

    func resolvedStorage(for record: NativeCorpusRecord) throws -> (record: NativeCorpusRecord, url: URL) {
        let migratedRecord = try migrateShardIfNeeded(record: record)
        return (
            migratedRecord,
            corporaDirectoryURL.appendingPathComponent(migratedRecord.storageFileName)
        )
    }

    @discardableResult
    func migrateShardIfNeeded(record: NativeCorpusRecord) throws -> NativeCorpusRecord {
        let url = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        guard fileManager.fileExists(atPath: url.path) else { return record }
        let result = try shardMigrator.migrateIfNeeded(
            at: url,
            record: record,
            destinationDirectoryURL: corporaDirectoryURL
        )
        guard result.didMigrate else { return record }

        try libraryCatalogStore.refreshCorpus(result.record)
        if var cachedCorpora,
           let index = cachedCorpora.firstIndex(where: { $0.id == result.record.id }) {
            cachedCorpora[index] = result.record
            self.cachedCorpora = cachedCorpora
        }
        return result.record
    }

    func expandImportRequests(
        paths: [String],
        preserveHierarchy: Bool,
        folders: inout [NativeFolderRecord]
    ) throws -> NativeExpandedImportRequests {
        var requests: [NativeImportRequest] = []
        var skippedItems: [LibraryImportFailureItem] = []
        for rawPath in paths {
            let sourceURL = URL(fileURLWithPath: rawPath)
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: sourceURL.path, isDirectory: &isDirectory) else { continue }
            if isDirectory.boolValue {
                let baseFolder = preserveHierarchy
                    ? ensureFolder(named: sourceURL.lastPathComponent, folders: &folders)
                    : nil
                let enumerator = fileManager.enumerator(
                    at: sourceURL,
                    includingPropertiesForKeys: [.isRegularFileKey],
                    options: [.skipsHiddenFiles]
                )
                while let nextURL = enumerator?.nextObject() as? URL {
                    let values = try nextURL.resourceValues(forKeys: [.isRegularFileKey])
                    guard values.isRegularFile == true else { continue }
                    if ImportedDocumentReadingSupport.canImport(url: nextURL) {
                        requests.append(NativeImportRequest(sourceURL: nextURL, folder: baseFolder))
                    } else {
                        skippedItems.append(
                            LibraryImportFailureItem(
                                path: nextURL.path,
                                fileName: nextURL.lastPathComponent,
                                reason: ImportedDocumentReadingSupport.unsupportedFormatError(
                                    fileName: nextURL.lastPathComponent
                                ).localizedDescription
                            )
                        )
                    }
                }
            } else {
                requests.append(NativeImportRequest(sourceURL: sourceURL, folder: nil))
            }
        }
        return NativeExpandedImportRequests(requests: requests, skippedItems: skippedItems)
    }

    func ensureFolder(named name: String, folders: inout [NativeFolderRecord]) -> NativeFolderRecord {
        if let existing = folders.first(where: { $0.name == name }) {
            return existing
        }
        let created = NativeFolderRecord(id: UUID().uuidString, name: name)
        folders.append(created)
        return created
    }

    func resolvedFolder(for folderId: String, folders: [NativeFolderRecord]) -> NativeFolderRecord? {
        guard !folderId.isEmpty else { return nil }
        return folders.first(where: { $0.id == folderId })
    }

    func moveStorageToRecycle(for record: NativeCorpusRecord) throws {
        let sourceURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        let recycleURL = recycleDirectoryURL.appendingPathComponent(record.storageFileName)
        if fileManager.fileExists(atPath: sourceURL.path) {
            try? fileManager.removeItem(at: recycleURL)
            try fileManager.moveItem(at: sourceURL, to: recycleURL)
        }
    }

    func moveStorageToRecycle(
        for record: NativeCorpusRecord,
        transaction: StorageMutationTransaction
    ) throws {
        let sourceURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        let recycleURL = recycleDirectoryURL.appendingPathComponent(record.storageFileName)
        try transaction.moveItem(at: sourceURL, to: recycleURL)
    }

    func restoreStorageFromRecycle(for record: NativeCorpusRecord) throws {
        let recycleURL = recycleDirectoryURL.appendingPathComponent(record.storageFileName)
        let storageURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        if fileManager.fileExists(atPath: recycleURL.path) {
            try? fileManager.removeItem(at: storageURL)
            try fileManager.moveItem(at: recycleURL, to: storageURL)
        }
    }

    func restoreStorageFromRecycle(
        for record: NativeCorpusRecord,
        transaction: StorageMutationTransaction
    ) throws {
        let recycleURL = recycleDirectoryURL.appendingPathComponent(record.storageFileName)
        let storageURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        try transaction.moveItem(at: recycleURL, to: storageURL)
    }

    func copyDirectoryContents(from source: URL, to destination: URL) throws {
        if isSameOrDescendant(destination, of: source) {
            throw missingItemError("目标目录不能位于源目录内部。")
        }
        try fileManager.createDirectory(at: destination, withIntermediateDirectories: true)
        let contents = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for item in contents {
            let target = destination.appendingPathComponent(item.lastPathComponent)
            try? fileManager.removeItem(at: target)
            try fileManager.copyItem(at: item, to: target)
        }
    }

    func copyItemIfPresent(from sourceURL: URL, to destinationURL: URL) throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else { return }
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    func backupPersistentLibraryContents(from sourceRoot: URL, to destinationRoot: URL) throws {
        try fileManager.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
        try backupCentralDatabaseIfPresent(
            from: sourceRoot.appendingPathComponent("library.db"),
            to: destinationRoot.appendingPathComponent("library.db"),
            configuration: .libraryCatalog
        )
        try backupCentralDatabaseIfPresent(
            from: sourceRoot.appendingPathComponent("workspace.db"),
            to: destinationRoot.appendingPathComponent("workspace.db"),
            configuration: .workspaceState
        )
        try copyItemIfPresent(
            from: sourceRoot.appendingPathComponent("corpora", isDirectory: true),
            to: destinationRoot.appendingPathComponent("corpora", isDirectory: true)
        )
        try copyItemIfPresent(
            from: sourceRoot.appendingPathComponent("recycle", isDirectory: true),
            to: destinationRoot.appendingPathComponent("recycle", isDirectory: true)
        )
    }

    func restorePersistentLibraryContents(
        from sourceRoot: URL,
        to destinationRoot: URL
    ) throws {
        let sourceLibraryDB = sourceRoot.appendingPathComponent("library.db")
        let sourceWorkspaceDB = sourceRoot.appendingPathComponent("workspace.db")
        guard fileManager.fileExists(atPath: sourceLibraryDB.path),
              fileManager.fileExists(atPath: sourceWorkspaceDB.path) else {
            throw missingItemError("备份目录缺少 `library.db` 或 `workspace.db`。")
        }

        try fileManager.createDirectory(at: destinationRoot, withIntermediateDirectories: true)
        try removePersistentLibraryContents(at: destinationRoot)
        let destinationLibraryDB = destinationRoot.appendingPathComponent("library.db")
        let destinationWorkspaceDB = destinationRoot.appendingPathComponent("workspace.db")
        try copyItemIfPresent(from: sourceLibraryDB, to: destinationLibraryDB)
        try copyItemIfPresent(from: sourceWorkspaceDB, to: destinationWorkspaceDB)
        SQLiteDatabase.removeDatabaseSidecars(for: destinationLibraryDB, fileManager: fileManager)
        SQLiteDatabase.removeDatabaseSidecars(for: destinationWorkspaceDB, fileManager: fileManager)
        try copyItemIfPresent(
            from: sourceRoot.appendingPathComponent("corpora", isDirectory: true),
            to: destinationRoot.appendingPathComponent("corpora", isDirectory: true)
        )
        try copyItemIfPresent(
            from: sourceRoot.appendingPathComponent("recycle", isDirectory: true),
            to: destinationRoot.appendingPathComponent("recycle", isDirectory: true)
        )
    }

    func removePersistentLibraryContents(at rootURL: URL) throws {
        let libraryDB = rootURL.appendingPathComponent("library.db")
        let workspaceDB = rootURL.appendingPathComponent("workspace.db")

        if fileManager.fileExists(atPath: libraryDB.path) {
            try fileManager.removeItem(at: libraryDB)
        }
        if fileManager.fileExists(atPath: workspaceDB.path) {
            try fileManager.removeItem(at: workspaceDB)
        }
        SQLiteDatabase.removeDatabaseSidecars(for: libraryDB, fileManager: fileManager)
        SQLiteDatabase.removeDatabaseSidecars(for: workspaceDB, fileManager: fileManager)

        let corporaURL = rootURL.appendingPathComponent("corpora", isDirectory: true)
        if fileManager.fileExists(atPath: corporaURL.path) {
            try fileManager.removeItem(at: corporaURL)
        }
        let recycleURL = rootURL.appendingPathComponent("recycle", isDirectory: true)
        if fileManager.fileExists(atPath: recycleURL.path) {
            try fileManager.removeItem(at: recycleURL)
        }
    }

    func backupCentralDatabaseIfPresent(
        from sourceURL: URL,
        to destinationURL: URL,
        configuration: SQLiteDatabaseConfiguration
    ) throws {
        guard fileManager.fileExists(atPath: sourceURL.path) else { return }
        try SQLiteDatabase.backupDatabase(
            from: sourceURL,
            to: destinationURL,
            configuration: configuration,
            fileManager: fileManager
        )
    }

    func removeDirectoryContents(at url: URL) throws {
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
        let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
        for item in contents {
            try fileManager.removeItem(at: item)
        }
    }

    func missingItemError(_ message: String) -> NSError {
        NSError(
            domain: "WordZMac.NativeCorpusStore",
            code: 404,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
    }

    func timestamp() -> String {
        NativeDateFormatting.iso8601String(from: Date())
    }

    func compactTimestamp() -> String {
        NativeDateFormatting.compactTimestampString(from: Date())
    }

    func standardizedDirectoryURL(_ url: URL) -> URL {
        let standardized = url.standardizedFileURL
        guard standardized.hasDirectoryPath else {
            return standardized.deletingLastPathComponent()
        }
        return standardized
    }

    func isSameOrDescendant(_ candidate: URL, of parent: URL) -> Bool {
        let normalizedCandidate = standardizedDirectoryURL(candidate)
        let normalizedParent = standardizedDirectoryURL(parent)
        return normalizedCandidate.path == normalizedParent.path
            || normalizedCandidate.path.hasPrefix(normalizedParent.path + "/")
    }

    func readStoredCorpusText(at _: URL, record: NativeCorpusRecord) throws -> String {
        let currentRecord = try migrateShardIfNeeded(record: record)
        let currentURL = corporaDirectoryURL.appendingPathComponent(currentRecord.storageFileName)

        if let document = try NativeCorpusDatabaseSupport.readDocument(at: currentURL) {
            return document.text
        }

        throw missingItemError(
            "语料分片不可读取，或不是当前支持的数据库格式：\(currentURL.lastPathComponent)"
        )
    }

    func shouldRefreshCorpusMetadata(_ metadata: NativeStoredCorpusMetadata) -> Bool {
        metadata.ttr == 0 && metadata.tokenCount > 0
    }

    func corpusInfoSummary(
        from record: NativeCorpusRecord,
        metadata: NativeStoredCorpusMetadata,
        fallbackPath: String
    ) -> CorpusInfoSummary {
        CorpusInfoSummary(json: [
            "corpusId": record.id,
            "title": record.name,
            "folderName": record.folderName,
            "sourceType": metadata.sourceType.isEmpty ? record.sourceType : metadata.sourceType,
            "representedPath": metadata.representedPath.isEmpty ? (record.representedPath.isEmpty ? fallbackPath : record.representedPath) : metadata.representedPath,
            "detectedEncoding": metadata.detectedEncoding,
            "importedAt": metadata.importedAt,
            "tokenCount": metadata.tokenCount,
            "typeCount": metadata.typeCount,
            "sentenceCount": metadata.sentenceCount,
            "paragraphCount": metadata.paragraphCount,
            "characterCount": metadata.characterCount,
            "ttr": metadata.ttr > 0 ? metadata.ttr : fallbackTTR(typeCount: metadata.typeCount, tokenCount: metadata.tokenCount),
            "sttr": metadata.sttr,
            "metadata": metadata.metadataProfile.merged(over: record.metadata).jsonObject,
            "cleaningStatus": (metadata.cleaningSummary ?? record.cleaningSummary ?? .pending).status.rawValue,
            "cleaningSummary": (metadata.cleaningSummary ?? record.cleaningSummary ?? .pending).jsonObject
        ])
    }

    func fallbackTTR(typeCount: Int, tokenCount: Int) -> Double {
        guard tokenCount > 0 else { return 0 }
        return Double(typeCount) / Double(tokenCount)
    }

    func isStoredCorpusReadable(at url: URL) -> Bool {
        if let databaseDocument = try? NativeCorpusDatabaseSupport.readDocument(at: url) {
            return !databaseDocument.text.isEmpty || databaseDocument.metadata.characterCount == 0
        }
        return shardMigrator.canMigrateStorage(at: url)
    }

    func aggregateCleaningRuleHits(
        from summaries: [LibraryCorpusCleaningReportSummary]
    ) -> [LibraryCorpusCleaningRuleHit] {
        let merged = summaries
            .flatMap(\.ruleHits)
            .reduce(into: [String: Int]()) { partialResult, hit in
                partialResult[hit.id, default: 0] += hit.count
            }
        return merged.keys.sorted().map { key in
            LibraryCorpusCleaningRuleHit(id: key, count: merged[key] ?? 0)
        }
    }
}
