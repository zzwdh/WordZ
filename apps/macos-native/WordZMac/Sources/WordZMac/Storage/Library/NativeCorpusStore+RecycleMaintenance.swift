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
        var recycle = try loadRecycleEntries()
        guard let index = recycle.firstIndex(where: { $0.recycleEntryId == recycleEntryId }) else {
            throw missingItemError("未找到要恢复的回收站项目。")
        }
        let entry = recycle.remove(at: index)

        var folders = try loadFolders()
        if let folder = entry.folder, !folders.contains(where: { $0.id == folder.id }) {
            folders.append(folder)
        }

        var corpora = try loadCorpora()
        for var corpus in entry.corpora {
            if let folder = entry.folder {
                corpus.folderId = folder.id
                corpus.folderName = folder.name
            }
            try restoreStorageFromRecycle(for: corpus)
            corpora.removeAll { $0.id == corpus.id }
            corpora.append(corpus)
        }

        try saveFolders(folders)
        try saveCorpora(corpora)
        try saveRecycleEntries(recycle)
    }

    func purgeRecycleEntry(recycleEntryId: String) throws {
        var recycle = try loadRecycleEntries()
        guard let index = recycle.firstIndex(where: { $0.recycleEntryId == recycleEntryId }) else {
            throw missingItemError("未找到要彻底删除的回收站项目。")
        }
        let entry = recycle.remove(at: index)
        for corpus in entry.corpora {
            let recyclePath = recycleDirectoryURL.appendingPathComponent(corpus.storageFileName)
            try? fileManager.removeItem(at: recyclePath)
        }
        try saveRecycleEntries(recycle)
    }

    func backupLibrary(destinationPath: String) throws -> LibraryBackupSummary {
        let destinationRoot = URL(fileURLWithPath: destinationPath, isDirectory: true)
        if isSameOrDescendant(destinationRoot, of: rootURL) {
            throw missingItemError("备份目录不能位于当前语料库目录内部。")
        }
        let backupDir = destinationRoot.appendingPathComponent("WordZMac-backup-\(compactTimestamp())", isDirectory: true)
        try fileManager.createDirectory(at: backupDir, withIntermediateDirectories: true)
        try copyDirectoryContents(from: rootURL, to: backupDir)

        let corpora = try loadCorpora()
        let folders = try loadFolders()
        return LibraryBackupSummary(json: [
            "backupDir": backupDir.path,
            "folderCount": folders.count,
            "corpusCount": corpora.count
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
        try copyDirectoryContents(from: sourceRoot, to: stagedRestore)

        let previousBackup = rootURL.deletingLastPathComponent()
            .appendingPathComponent("restore-backup-\(compactTimestamp())", isDirectory: true)
        var hasPreviousBackup = false
        if fileManager.fileExists(atPath: rootURL.path) {
            try fileManager.createDirectory(at: previousBackup, withIntermediateDirectories: true)
            try copyDirectoryContents(from: rootURL, to: previousBackup)
            hasPreviousBackup = true
        }

        do {
            try removeDirectoryContents(at: rootURL)
            try copyDirectoryContents(from: stagedRestore, to: rootURL)
            invalidateCaches()
            try ensureInitialized()
        } catch {
            invalidateCaches()
            if hasPreviousBackup {
                try? removeDirectoryContents(at: rootURL)
                try? copyDirectoryContents(from: previousBackup, to: rootURL)
            }
            invalidateCaches()
            throw error
        }

        let corpora = try loadCorpora()
        let folders = try loadFolders()
        return LibraryRestoreSummary(json: [
            "restoredFromDir": sourceRoot.path,
            "previousLibraryBackupDir": previousBackup.path,
            "folderCount": folders.count,
            "corpusCount": corpora.count
        ])
    }

    func repairLibrary() throws -> LibraryRepairSummary {
        var corpora = try loadCorpora()
        let folders = try loadFolders()
        let checkedCorpora = corpora.count
        let checkedFolders = folders.count

        var removedCorpora = 0
        var quarantinedCorpora = 0
        var quarantineDirectoryURL: URL?

        corpora.removeAll { corpus in
            let storageURL = corporaDirectoryURL.appendingPathComponent(corpus.storageFileName)
            let isReadable = fileManager.fileExists(atPath: storageURL.path) && isStoredCorpusReadable(at: storageURL)
            if !isReadable {
                removedCorpora += 1
                if fileManager.fileExists(atPath: storageURL.path) {
                    let activeQuarantineDirectory = quarantineDirectoryURL ?? makeRepairQuarantineDirectory()
                    quarantineDirectoryURL = activeQuarantineDirectory
                    let targetURL = activeQuarantineDirectory.appendingPathComponent(corpus.storageFileName)
                    try? fileManager.removeItem(at: targetURL)
                    do {
                        try fileManager.moveItem(at: storageURL, to: targetURL)
                        quarantinedCorpora += 1
                    } catch {
                        let fallbackURL = activeQuarantineDirectory.appendingPathComponent(
                            "\(UUID().uuidString)-\(corpus.storageFileName)"
                        )
                        try? fileManager.moveItem(at: storageURL, to: fallbackURL)
                        if fileManager.fileExists(atPath: fallbackURL.path) {
                            quarantinedCorpora += 1
                        }
                    }
                }
            }
            return !isReadable
        }

        try saveCorpora(corpora)

        return LibraryRepairSummary(json: [
            "summary": [
                "repairedManifest": removedCorpora > 0,
                "repairedFolders": 0,
                "repairedCorpora": removedCorpora,
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
