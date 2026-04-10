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
        let storageURL = corporaDirectoryURL.appendingPathComponent(corpora[index].storageFileName)
        if fileManager.fileExists(atPath: storageURL.path) {
            _ = try readStoredCorpusText(at: storageURL, record: corpora[index])
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
        var corpora = try loadCorpora()
        guard let index = corpora.firstIndex(where: { $0.id == corpusId }) else {
            throw missingItemError("未找到要删除的语料。")
        }
        let record = corpora.remove(at: index)
        try moveStorageToRecycle(for: record)
        var recycle = try loadRecycleEntries()
        recycle.append(
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
        try saveCorpora(corpora)
        try saveRecycleEntries(recycle)
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
        var folders = try loadFolders()
        guard let folderIndex = folders.firstIndex(where: { $0.id == folderId }) else {
            throw missingItemError("未找到要删除的文件夹。")
        }
        let folder = folders.remove(at: folderIndex)

        var corpora = try loadCorpora()
        let removedCorpora = corpora.filter { $0.folderId == folder.id }
        corpora.removeAll { $0.folderId == folder.id }
        for corpus in removedCorpora {
            try moveStorageToRecycle(for: corpus)
        }

        var recycle = try loadRecycleEntries()
        recycle.append(
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

        try saveFolders(folders)
        try saveCorpora(corpora)
        try saveRecycleEntries(recycle)
    }
}
