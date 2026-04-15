import Foundation

extension NativeCorpusStore {
    func listLibrary(folderId: String = "all") throws -> LibrarySnapshot {
        let folders = try loadFolders()
        let corpora = try loadCorpora()
        let corpusSets = try loadCorpusSets()
        let filtered = folderId == "all" || folderId.isEmpty
            ? corpora
            : corpora.filter { $0.folderId == folderId }
        return LibrarySnapshot(
            folders: folders.map(\.libraryItem),
            corpora: filtered.map(\.libraryItem),
            corpusSets: corpusSets.map(\.libraryItem)
        )
    }

    func openSavedCorpus(corpusId: String) throws -> OpenedCorpus {
        let corpora = try loadCorpora()
        guard let record = corpora.first(where: { $0.id == corpusId }) else {
            throw NSError(
                domain: "WordZMac.NativeCorpusStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "未找到语料：\(corpusId)"]
            )
        }
        let storageURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        guard fileManager.fileExists(atPath: storageURL.path) else {
            throw NSError(
                domain: "WordZMac.NativeCorpusStore",
                code: 410,
                userInfo: [NSLocalizedDescriptionKey: "语料文件已丢失：\(record.name)"]
            )
        }
        let content = try readStoredCorpusText(at: storageURL, record: record)
        return OpenedCorpus(json: [
            "mode": "saved",
            "filePath": record.representedPath.isEmpty ? storageURL.path : record.representedPath,
            "displayName": record.name,
            "content": content,
            "sourceType": record.sourceType
        ])
    }

    func loadCorpusInfo(corpusId: String) throws -> CorpusInfoSummary {
        let corpora = try loadCorpora()
        guard let record = corpora.first(where: { $0.id == corpusId }) else {
            throw NSError(
                domain: "WordZMac.NativeCorpusStore",
                code: 404,
                userInfo: [NSLocalizedDescriptionKey: "未找到语料：\(corpusId)"]
            )
        }
        let storageURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        guard fileManager.fileExists(atPath: storageURL.path) else {
            throw NSError(
                domain: "WordZMac.NativeCorpusStore",
                code: 410,
                userInfo: [NSLocalizedDescriptionKey: "语料文件已丢失：\(record.name)"]
            )
        }

        if var metadata = try NativeCorpusDatabaseSupport.readMetadata(at: storageURL) {
            if shouldRefreshCorpusMetadata(metadata),
               let databaseDocument = try NativeCorpusDatabaseSupport.readDocument(at: storageURL) {
                try NativeCorpusDatabaseSupport.writeDocument(
                    at: storageURL,
                    document: DecodedTextDocument(
                        text: databaseDocument.text,
                        encodingName: databaseDocument.metadata.detectedEncoding
                    ),
                    sourceType: databaseDocument.metadata.sourceType,
                    representedPath: databaseDocument.metadata.representedPath,
                    importedAt: databaseDocument.metadata.importedAt,
                    metadataProfile: databaseDocument.metadata.metadataProfile.merged(over: record.metadata),
                    rawText: databaseDocument.rawText.isEmpty ? databaseDocument.text : databaseDocument.rawText,
                    cleaningSummary: databaseDocument.metadata.cleaningSummary
                )
                metadata = try NativeCorpusDatabaseSupport.readMetadata(at: storageURL) ?? metadata
            }
            return corpusInfoSummary(from: record, metadata: metadata, fallbackPath: storageURL.path)
        }

        _ = try readStoredCorpusText(at: storageURL, record: record)
        if let metadata = try NativeCorpusDatabaseSupport.readMetadata(at: storageURL) {
            return corpusInfoSummary(from: record, metadata: metadata, fallbackPath: storageURL.path)
        }

        let content = try TextFileDecodingSupport.readTextDocument(at: storageURL).text
        let stats = NativeAnalysisEngine().runStats(text: content)
        return CorpusInfoSummary(json: [
            "corpusId": record.id,
            "title": record.name,
            "folderName": record.folderName,
            "sourceType": record.sourceType,
            "representedPath": record.representedPath.isEmpty ? storageURL.path : record.representedPath,
            "detectedEncoding": "",
            "importedAt": "",
            "tokenCount": stats.tokenCount,
            "typeCount": stats.typeCount,
            "sentenceCount": stats.sentenceCount,
            "paragraphCount": stats.paragraphCount,
            "characterCount": content.count,
            "ttr": stats.ttr,
            "sttr": stats.sttr,
            "metadata": record.metadata.jsonObject,
            "cleaningStatus": (record.cleaningSummary ?? .pending).status.rawValue,
            "cleaningSummary": (record.cleaningSummary ?? .pending).jsonObject
        ])
    }
}
