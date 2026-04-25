import Foundation

extension NativeCorpusStore {
    func updateCorpusMetadata(corpusId: String, metadata: CorpusMetadataProfile) throws -> LibraryCorpusItem {
        var corpora = try loadCorpora()
        guard let index = corpora.firstIndex(where: { $0.id == corpusId }) else {
            throw NSError(
                domain: "WordZMac.NativeCorpusStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "未找到语料：\(corpusId)"]
            )
        }

        corpora[index].metadata = metadata
        let updatedRecord = try migrateShardIfNeeded(record: corpora[index])
        corpora[index] = updatedRecord
        let storageURL = corporaDirectoryURL.appendingPathComponent(updatedRecord.storageFileName)
        if fileManager.fileExists(atPath: storageURL.path) {
            _ = try readStoredCorpusText(at: storageURL, record: updatedRecord)
            try NativeCorpusDatabaseSupport.updateMetadata(at: storageURL, metadataProfile: metadata)
        }
        try saveCorpora(corpora)
        return corpora[index].libraryItem
    }

    func renameCorpus(corpusId: String, newName: String) throws -> LibraryCorpusItem {
        var corpora = try loadCorpora()
        guard let index = corpora.firstIndex(where: { $0.id == corpusId }) else {
            throw missingItemError("未找到要重命名的语料。")
        }
        corpora[index].name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        try saveCorpora(corpora)
        return corpora[index].libraryItem
    }

    func moveCorpus(corpusId: String, targetFolderId: String) throws -> LibraryCorpusItem {
        let folders = try loadFolders()
        let target = resolvedFolder(for: targetFolderId, folders: folders)
        var corpora = try loadCorpora()
        guard let index = corpora.firstIndex(where: { $0.id == corpusId }) else {
            throw missingItemError("未找到要移动的语料。")
        }
        corpora[index].folderId = target?.id ?? ""
        corpora[index].folderName = target?.name ?? "未分类"
        try saveCorpora(corpora)
        return corpora[index].libraryItem
    }

    func deleteCorpus(corpusId: String) throws {
        let existingCorpora = try loadCorpora()
        guard let index = existingCorpora.firstIndex(where: { $0.id == corpusId }) else {
            throw missingItemError("未找到要删除的语料。")
        }
        let existingRecycle = try loadRecycleEntries()
        var nextCorpora = existingCorpora
        let record = nextCorpora.remove(at: index)
        var nextRecycle = existingRecycle
        nextRecycle.append(
            NativeRecycleRecord(
                recycleEntryId: UUID().uuidString,
                type: "corpus",
                deletedAt: timestamp(),
                name: record.name,
                originalFolderName: record.folderName,
                sourceType: record.sourceType,
                itemCount: 1,
                folder: nil,
                corpora: [record]
            )
        )

        try storageMutationCoordinator.perform { transaction in
            try snapshotLibraryCatalogMutation(
                transaction,
                corpora: existingCorpora,
                recycleEntries: existingRecycle
            )
            try moveStorageToRecycle(for: record, transaction: transaction)
            try saveCorpora(nextCorpora)
            try saveRecycleEntries(nextRecycle)
        }
    }

    func createFolder(name: String) throws -> LibraryFolderItem {
        var folders = try loadFolders()
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let folder = NativeFolderRecord(id: UUID().uuidString, name: trimmed.isEmpty ? "未命名文件夹" : trimmed)
        folders.append(folder)
        try saveFolders(folders)
        return folder.libraryItem
    }

    func renameFolder(folderId: String, newName: String) throws -> LibraryFolderItem {
        var folders = try loadFolders()
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderId }) else {
            throw missingItemError("未找到要重命名的文件夹。")
        }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        folders[folderIndex].name = trimmed.isEmpty ? folders[folderIndex].name : trimmed

        var corpora = try loadCorpora()
        for index in corpora.indices where corpora[index].folderId == folderId {
            corpora[index].folderName = folders[folderIndex].name
        }

        try saveFolders(folders)
        try saveCorpora(corpora)
        return folders[folderIndex].libraryItem
    }

    func deleteFolder(folderId: String) throws {
        let existingFolders = try loadFolders()
        guard let folderIndex = existingFolders.firstIndex(where: { $0.id == folderId }) else {
            throw missingItemError("未找到要删除的文件夹。")
        }
        let existingCorpora = try loadCorpora()
        let existingRecycle = try loadRecycleEntries()
        var nextFolders = existingFolders
        let folder = nextFolders.remove(at: folderIndex)

        var nextCorpora = existingCorpora
        let removedCorpora = nextCorpora.filter { $0.folderId == folder.id }
        nextCorpora.removeAll { $0.folderId == folder.id }

        var nextRecycle = existingRecycle
        nextRecycle.append(
            NativeRecycleRecord(
                recycleEntryId: UUID().uuidString,
                type: "folder",
                deletedAt: timestamp(),
                name: folder.name,
                originalFolderName: folder.name,
                sourceType: "folder",
                itemCount: removedCorpora.count,
                folder: folder,
                corpora: removedCorpora
            )
        )

        try storageMutationCoordinator.perform { transaction in
            try snapshotLibraryCatalogMutation(
                transaction,
                folders: existingFolders,
                corpora: existingCorpora,
                recycleEntries: existingRecycle
            )
            for corpus in removedCorpora {
                try moveStorageToRecycle(for: corpus, transaction: transaction)
            }
            try saveFolders(nextFolders)
            try saveCorpora(nextCorpora)
            try saveRecycleEntries(nextRecycle)
        }
    }
}
