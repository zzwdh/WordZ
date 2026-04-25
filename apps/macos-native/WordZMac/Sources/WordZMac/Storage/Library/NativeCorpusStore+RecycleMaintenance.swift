import Foundation

extension NativeCorpusStore {
    func listRecycleBin() throws -> RecycleBinSnapshot {
        let entries = try loadRecycleEntries()
        let entryItems = entries.map(\.recycleItem)
        let folderCount = entries.filter { $0.folder != nil }.count
        let corpusCount = entries.reduce(0) { $0 + $1.corpora.count }
        return RecycleBinSnapshot(
            entries: entryItems,
            folderCount: folderCount,
            corpusCount: corpusCount,
            totalCount: entryItems.count
        )
    }

    func restoreRecycleEntry(recycleEntryId: String) throws {
        let existingRecycle = try loadRecycleEntries()
        guard let index = existingRecycle.firstIndex(where: { $0.recycleEntryId == recycleEntryId }) else {
            throw missingItemError("未找到要恢复的回收站项目。")
        }
        let existingFolders = try loadFolders()
        let existingCorpora = try loadCorpora()
        var nextRecycle = existingRecycle
        let entry = nextRecycle.remove(at: index)

        var nextFolders = existingFolders
        if let folder = entry.folder, !nextFolders.contains(where: { $0.id == folder.id }) {
            nextFolders.append(folder)
        }

        var nextCorpora = existingCorpora
        for var corpus in entry.corpora {
            if let folder = entry.folder {
                corpus.folderId = folder.id
                corpus.folderName = folder.name
            }
            nextCorpora.removeAll { $0.id == corpus.id }
            nextCorpora.append(corpus)
        }

        try storageMutationCoordinator.perform { transaction in
            try snapshotLibraryCatalogMutation(
                transaction,
                folders: existingFolders,
                corpora: existingCorpora,
                recycleEntries: existingRecycle
            )
            for corpus in entry.corpora {
                try restoreStorageFromRecycle(for: corpus, transaction: transaction)
            }
            try saveFolders(nextFolders)
            try saveCorpora(nextCorpora)
            try saveRecycleEntries(nextRecycle)
        }
    }

    func purgeRecycleEntry(recycleEntryId: String) throws {
        let existingRecycle = try loadRecycleEntries()
        guard let index = existingRecycle.firstIndex(where: { $0.recycleEntryId == recycleEntryId }) else {
            throw missingItemError("未找到要彻底删除的回收站项目。")
        }
        var nextRecycle = existingRecycle
        let entry = nextRecycle.remove(at: index)
        try storageMutationCoordinator.perform { transaction in
            try snapshotLibraryCatalogMutation(
                transaction,
                recycleEntries: existingRecycle
            )
            for corpus in entry.corpora {
                let recyclePath = recycleDirectoryURL.appendingPathComponent(corpus.storageFileName)
                try transaction.removeItem(at: recyclePath)
            }
            try saveRecycleEntries(nextRecycle)
        }
    }

    func backupLibrary(destinationPath: String) throws -> LibraryBackupSummary {
        let destinationRoot = URL(fileURLWithPath: destinationPath, isDirectory: true)
        if isSameOrDescendant(destinationRoot, of: rootURL) {
            throw missingItemError("备份目录不能位于当前语料库目录内部。")
        }
        let backupDir = destinationRoot.appendingPathComponent("WordZMac-backup-\(compactTimestamp())", isDirectory: true)
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        try backupPersistentLibraryContents(from: rootURL, to: backupDir)

        let catalogSummary = try libraryCatalogStore.storageSummary()
        let workspaceSummary = try workspaceDatabaseStore.storageSummary()
        return LibraryBackupSummary(json: [
            "backupDir": backupDir.path,
            "folderCount": catalogSummary.folderCount,
            "corpusCount": catalogSummary.activeCorpusCount,
            "librarySchemaVersion": catalogSummary.schemaVersion,
            "workspaceSchemaVersion": workspaceSummary.schemaVersion,
            "pendingShardMigrationCount": catalogSummary.pendingShardMigrationCount,
            "quarantinedCorpusCount": catalogSummary.quarantinedCorpusCount,
            "corpusSetCount": catalogSummary.corpusSetCount,
            "recycleEntryCount": catalogSummary.recycleEntryCount
        ])
    }

    func restoreLibrary(sourcePath: String) throws -> LibraryRestoreSummary {
        let sourceRoot = URL(fileURLWithPath: sourcePath, isDirectory: true)
        guard fileManager.fileExists(atPath: sourceRoot.path) else {
            throw missingItemError("备份目录不存在。")
        }
        if isSameOrDescendant(sourceRoot, of: rootURL) {
            throw missingItemError("恢复源目录不能位于当前语料库目录内部。")
        }

        let stagedRestore = rootURL.deletingLastPathComponent()
            .appendingPathComponent("restore-staging-\(compactTimestamp())", isDirectory: true)
        try fileManager.createDirectory(at: stagedRestore, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagedRestore) }
        try restorePersistentLibraryContents(from: sourceRoot, to: stagedRestore)

        let previousBackup = rootURL.deletingLastPathComponent()
            .appendingPathComponent("restore-backup-\(compactTimestamp())", isDirectory: true)
        var hasPreviousBackup = false
        if fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.createDirectory(at: previousBackup, withIntermediateDirectories: true)
            try backupPersistentLibraryContents(from: rootURL, to: previousBackup)
            hasPreviousBackup = true
        }

        do {
            try restorePersistentLibraryContents(from: stagedRestore, to: rootURL)
            invalidateCaches()
            try ensureInitialized()
        } catch {
            invalidateCaches()
            if hasPreviousBackup {
                try? restorePersistentLibraryContents(from: previousBackup, to: rootURL)
            }
            invalidateCaches()
            throw error
        }

        let catalogSummary = try libraryCatalogStore.storageSummary()
        let workspaceSummary = try workspaceDatabaseStore.storageSummary()
        return LibraryRestoreSummary(json: [
            "restoredFromDir": sourceRoot.path,
            "previousLibraryBackupDir": previousBackup.path,
            "folderCount": catalogSummary.folderCount,
            "corpusCount": catalogSummary.activeCorpusCount,
            "librarySchemaVersion": catalogSummary.schemaVersion,
            "workspaceSchemaVersion": workspaceSummary.schemaVersion,
            "pendingShardMigrationCount": catalogSummary.pendingShardMigrationCount,
            "quarantinedCorpusCount": catalogSummary.quarantinedCorpusCount,
            "corpusSetCount": catalogSummary.corpusSetCount,
            "recycleEntryCount": catalogSummary.recycleEntryCount
        ])
    }

    func repairLibrary() throws -> LibraryRepairSummary {
        let existingCorpora = try loadCorpora()
        let folders = try loadFolders()
        let checkedCorpora = existingCorpora.count
        let checkedFolders = folders.count

        var nextCorpora = existingCorpora
        var repairedCorpora = 0
        var quarantinedCorpora = 0
        var quarantineDirectoryURL: URL?
        var quarantinedEntries: [LibraryCatalogStore.QuarantinedCorpusEntry] = []

        nextCorpora.removeAll { corpus in
            let storageURL = corporaDirectoryURL.appendingPathComponent(corpus.storageFileName)
            let isReadable = fileManager.fileExists(atPath: storageURL.path) && isStoredCorpusReadable(at: storageURL)
            guard !isReadable else { return false }

            repairedCorpora += 1
            let activeQuarantineDirectory = quarantineDirectoryURL ?? makeRepairQuarantineDirectory()
            quarantineDirectoryURL = activeQuarantineDirectory
            let quarantineURL = activeQuarantineDirectory.appendingPathComponent(corpus.storageFileName)
            quarantinedEntries.append(
                LibraryCatalogStore.QuarantinedCorpusEntry(
                    record: corpus,
                    integrityNote: "repair-quarantine:\(quarantineURL.path)",
                    quarantineURL: quarantineURL
                )
            )
            quarantinedCorpora += 1
            return true
        }

        if !quarantinedEntries.isEmpty {
            try storageMutationCoordinator.perform { transaction in
                try snapshotLibraryCatalogMutation(transaction, corpora: existingCorpora)
                for entry in quarantinedEntries {
                    let sourceURL = corporaDirectoryURL.appendingPathComponent(entry.record.storageFileName)
                    try transaction.moveItem(at: sourceURL, to: entry.quarantineURL)
                }
                try libraryCatalogStore.quarantineCorpora(quarantinedEntries)
                try saveCorpora(nextCorpora)
            }
        }

        return LibraryRepairSummary(json: [
            "summary": [
                "repairedManifest": repairedCorpora > 0,
                "repairedFolders": 0,
                "repairedCorpora": repairedCorpora,
                "recoveredCorpusMeta": 0,
                "quarantinedFolders": 0,
                "quarantinedCorpora": quarantinedCorpora,
                "checkedFolders": checkedFolders,
                "checkedCorpora": checkedCorpora
            ],
            "quarantineDir": quarantineDirectoryURL?.path ?? recycleDirectoryURL.path
        ])
    }

    func makeRepairQuarantineDirectory() -> URL {
        let quarantineDirectoryURL = recycleDirectoryURL
            .appendingPathComponent("repair-quarantine-\(compactTimestamp())", isDirectory: true)
        try? fileManager.createDirectory(at: quarantineDirectoryURL, withIntermediateDirectories: true)
        return quarantineDirectoryURL
    }
}
