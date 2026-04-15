import Foundation

extension NativeCorpusStore {
    func cleanCorpora(corpusIds: [String]) throws -> LibraryCorpusCleaningBatchResult {
        try cleanCorpora(corpusIds: corpusIds, progress: nil, isCancelled: nil)
    }

    func cleanCorpora(
        corpusIds: [String],
        progress: LibraryCorpusCleaningProgressHandler?,
        isCancelled: LibraryCorpusCleaningCancellationHandler?
    ) throws -> LibraryCorpusCleaningBatchResult {
        var seen = Set<String>()
        let requestedIDs = corpusIds.filter { seen.insert($0).inserted }
        let totalCount = requestedIDs.count

        progress?(
            LibraryCorpusCleaningProgressSnapshot(
                phase: .preparing,
                totalCount: totalCount,
                completedCount: 0,
                changedCount: 0,
                currentCorpusID: "",
                currentCorpusName: ""
            )
        )

        guard !requestedIDs.isEmpty else {
            return LibraryCorpusCleaningBatchResult(json: [
                "requestedCount": 0,
                "cleanedCount": 0,
                "changedCount": 0,
                "cleanedItems": [],
                "failureItems": [],
                "ruleHits": [],
                "cancelled": false
            ])
        }

        var corpora = try loadCorpora()
        var cleanedItems: [LibraryCorpusItem] = []
        var failureItems: [LibraryCorpusCleaningFailureItem] = []
        var cleanedSummaries: [LibraryCorpusCleaningReportSummary] = []

        for (index, corpusId) in requestedIDs.enumerated() {
            try throwIfCleaningCancelled(isCancelled)

            guard let recordIndex = corpora.firstIndex(where: { $0.id == corpusId }) else {
                failureItems.append(
                    LibraryCorpusCleaningFailureItem(
                        corpusId: corpusId,
                        corpusName: "",
                        reason: "未找到要清洗的语料。"
                    )
                )
                continue
            }

            let record = corpora[recordIndex]
            progress?(
                LibraryCorpusCleaningProgressSnapshot(
                    phase: .cleaning,
                    totalCount: totalCount,
                    completedCount: index,
                    changedCount: cleanedSummaries.filter(\.hasChanges).count,
                    currentCorpusID: record.id,
                    currentCorpusName: record.name
                )
            )

            do {
                let storageURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
                guard fileManager.fileExists(atPath: storageURL.path) else {
                    throw missingItemError("语料文件已丢失：\(record.name)")
                }

                let storedDocument = try loadStoredDocumentForCleaning(at: storageURL, record: record)
                let rawInput = storedDocument.rawText.isEmpty ? storedDocument.text : storedDocument.rawText
                let cleaned = CorpusAutoCleaningSupport.clean(rawInput)
                guard !cleaned.cleanedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    throw NSError(
                        domain: "WordZMac.NativeCorpusStore",
                        code: 422,
                        userInfo: [NSLocalizedDescriptionKey: "自动清洗后未保留可用文本：\(record.name)。"]
                    )
                }

                let cleanedAt = timestamp()
                let cleaningSummary = CorpusAutoCleaningSupport.makeReportSummary(
                    from: cleaned,
                    cleanedAt: cleanedAt
                )
                let mergedMetadata = storedDocument.metadata.metadataProfile.merged(over: record.metadata)
                try NativeCorpusDatabaseSupport.writeDocument(
                    at: storageURL,
                    document: DecodedTextDocument(
                        text: cleaned.cleanedText,
                        encodingName: storedDocument.metadata.detectedEncoding
                    ),
                    sourceType: storedDocument.metadata.sourceType.isEmpty ? record.sourceType : storedDocument.metadata.sourceType,
                    representedPath: storedDocument.metadata.representedPath.isEmpty ? record.representedPath : storedDocument.metadata.representedPath,
                    importedAt: storedDocument.metadata.importedAt.isEmpty ? timestamp() : storedDocument.metadata.importedAt,
                    metadataProfile: mergedMetadata,
                    rawText: cleaned.rawText,
                    cleaningSummary: cleaningSummary
                )

                corpora[recordIndex].metadata = mergedMetadata
                corpora[recordIndex].cleaningSummary = cleaningSummary
                cleanedItems.append(corpora[recordIndex].libraryItem)
                cleanedSummaries.append(cleaningSummary)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failureItems.append(
                    LibraryCorpusCleaningFailureItem(
                        corpusId: record.id,
                        corpusName: record.name,
                        reason: error.localizedDescription
                    )
                )
            }

            progress?(
                LibraryCorpusCleaningProgressSnapshot(
                    phase: .cleaning,
                    totalCount: totalCount,
                    completedCount: index + 1,
                    changedCount: cleanedSummaries.filter(\.hasChanges).count,
                    currentCorpusID: record.id,
                    currentCorpusName: record.name
                )
            )
        }

        try throwIfCleaningCancelled(isCancelled)
        progress?(
            LibraryCorpusCleaningProgressSnapshot(
                phase: .committing,
                totalCount: totalCount,
                completedCount: totalCount,
                changedCount: cleanedSummaries.filter(\.hasChanges).count,
                currentCorpusID: "",
                currentCorpusName: ""
            )
        )

        try saveCorpora(corpora)

        progress?(
            LibraryCorpusCleaningProgressSnapshot(
                phase: .completed,
                totalCount: totalCount,
                completedCount: totalCount,
                changedCount: cleanedSummaries.filter(\.hasChanges).count,
                currentCorpusID: "",
                currentCorpusName: ""
            )
        )

        return LibraryCorpusCleaningBatchResult(json: [
            "requestedCount": totalCount,
            "cleanedCount": cleanedItems.count,
            "changedCount": cleanedSummaries.filter(\.hasChanges).count,
            "cleanedItems": cleanedItems.map { corpus in
                [
                    "id": corpus.id,
                    "name": corpus.name,
                    "folderId": corpus.folderId,
                    "folderName": corpus.folderName,
                    "sourceType": corpus.sourceType,
                    "representedPath": corpus.representedPath,
                    "metadata": corpus.metadata.jsonObject,
                    "cleaningStatus": corpus.cleaningStatus.rawValue,
                    "cleaningSummary": corpus.cleaningSummary?.jsonObject ?? [:]
                ]
            },
            "failureItems": failureItems.map(\.jsonObject),
            "ruleHits": aggregateCleaningRuleHits(from: cleanedSummaries).map(\.jsonObject),
            "cancelled": false
        ])
    }

    private func loadStoredDocumentForCleaning(
        at url: URL,
        record: NativeCorpusRecord
    ) throws -> NativeStoredCorpusDatabaseDocument {
        if let storedDocument = try NativeCorpusDatabaseSupport.readDocument(at: url) {
            return storedDocument
        }

        _ = try readStoredCorpusText(at: url, record: record)
        if let storedDocument = try NativeCorpusDatabaseSupport.readDocument(at: url) {
            return storedDocument
        }

        throw missingItemError("无法读取语料内容：\(record.name)")
    }

    private func throwIfCleaningCancelled(_ isCancelled: LibraryCorpusCleaningCancellationHandler?) throws {
        if isCancelled?() == true {
            throw CancellationError()
        }
    }
}
