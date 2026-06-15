import Foundation
import WordZStorage

extension NativeCorpusStore: CorpusSetOpeningLibraryStore {
    func openSavedCorpusSet(corpusSetID: String) throws -> OpenedCorpus {
        let corpusSets = try loadCorpusSets()
        guard let corpusSet = corpusSets.first(where: { $0.id == corpusSetID }) else {
            throw missingItemError("未找到语料集：\(corpusSetID)")
        }

        let storageURL = corpusSetStorageURL(corpusSetID: corpusSet.id)
        let hasReadableDatabase: Bool
        if fileManager.fileExists(atPath: storageURL.path) {
            hasReadableDatabase = try NativeCorpusDatabaseSupport.readDocument(at: storageURL) != nil
        } else {
            hasReadableDatabase = false
        }
        if !hasReadableDatabase {
            try materializeCorpusSet(corpusSet)
        }

        guard let document = try NativeCorpusDatabaseSupport.readDocument(at: storageURL) else {
            throw missingItemError("语料集数据库不可读取：\(corpusSet.name)")
        }

        return OpenedCorpus(json: [
            "mode": "corpus-set",
            "filePath": storageURL.path,
            "displayName": corpusSet.name,
            "content": document.text,
            "sourceType": "db"
        ])
    }

    func materializeCorpusSet(_ corpusSet: NativeCorpusSetRecord) throws {
        let corpora = try loadCorpora()
        let corporaByID = Dictionary(uniqueKeysWithValues: corpora.map { ($0.id, $0) })
        let members = corpusSet.corpusIDs.compactMap { corporaByID[$0] }
        guard !members.isEmpty else {
            throw missingItemError("语料集“\(corpusSet.name)”没有可合并的语料。")
        }

        let mergedText = try members
            .map { try materializedText(for: $0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        guard !mergedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw missingItemError("语料集“\(corpusSet.name)”合并后没有可分析文本。")
        }

        let storageURL = corpusSetStorageURL(corpusSetID: corpusSet.id)
        try NativeCorpusDatabaseSupport.writeDocument(
            at: storageURL,
            document: DecodedTextDocument(text: mergedText, encodingName: "UTF-8"),
            sourceType: "db",
            representedPath: "wordz://corpus-set/\(corpusSet.id)",
            importedAt: corpusSet.updatedAt.isEmpty ? timestamp() : corpusSet.updatedAt,
            metadataProfile: .empty,
            rawText: mergedText,
            cleaningSummary: nil,
            sourceFileCount: members.count
        )
    }

    func removeMaterializedCorpusSet(corpusSetID: String) {
        let storageURL = corpusSetStorageURL(corpusSetID: corpusSetID)
        try? fileManager.removeItem(at: storageURL)
        SQLiteDatabase.removeDatabaseSidecars(for: storageURL, fileManager: fileManager)
    }

    func storedDatabaseURL(for sourceID: String) throws -> URL? {
        if let corpusSetID = CorpusSetSourceID.corpusSetID(from: sourceID) {
            guard try loadCorpusSets().contains(where: { $0.id == corpusSetID }) else {
                return nil
            }
            return corpusSetStorageURL(corpusSetID: corpusSetID)
        }

        let records = try loadCorpora()
        guard let existingRecord = records.first(where: { $0.id == sourceID }) else {
            return nil
        }
        let (_, storageURL) = try resolvedStorage(for: existingRecord)
        return storageURL
    }

    func corpusSetStorageURL(corpusSetID: String) -> URL {
        corpusSetsDirectoryURL.appendingPathComponent("\(corpusSetID).db")
    }

    private func materializedText(for record: NativeCorpusRecord) throws -> String {
        let (currentRecord, storageURL) = try resolvedStorage(for: record)
        guard fileManager.fileExists(atPath: storageURL.path) else {
            throw missingItemError("语料集成员文件已丢失：\(currentRecord.name)")
        }
        guard let document = try NativeCorpusDatabaseSupport.readDocument(at: storageURL) else {
            throw missingItemError("语料集成员数据库不可读取：\(currentRecord.name)")
        }
        return document.text
    }
}
