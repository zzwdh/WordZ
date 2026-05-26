import Foundation

extension NativeCorpusStore {
    func importCorpusPaths(
        _ paths: [String],
        folderId: String,
        preserveHierarchy: Bool
    ) throws -> LibraryImportResult {
        try importCorpusPaths(
            paths,
            folderId: folderId,
            preserveHierarchy: preserveHierarchy,
            progress: nil,
            isCancelled: nil
        )
    }

    func importMergedCorpusPaths(
        _ paths: [String],
        name: String,
        folderId: String
    ) throws -> LibraryImportResult {
        try importMergedCorpusPaths(
            paths,
            name: name,
            folderId: folderId,
            progress: nil,
            isCancelled: nil
        )
    }

    func importMergedCorpusPaths(
        _ paths: [String],
        name: String,
        folderId: String,
        progress: LibraryImportProgressHandler?,
        isCancelled: LibraryImportCancellationHandler?
    ) throws -> LibraryImportResult {
        let existingFolders = try loadFolders()
        let existingCorpora = try loadCorpora()
        var folders = existingFolders
        let expandedRequests = try expandImportRequests(paths: paths, preserveHierarchy: false, folders: &folders)
        let requests = expandedRequests.requests
        let requestedFolder = resolvedFolder(for: folderId, folders: existingFolders)
        let displayName = normalizedMergedCorpusName(name)
        let totalCount = requests.count + expandedRequests.skippedItems.count

        progress?(
            LibraryImportProgressSnapshot(
                phase: .preparing,
                totalCount: totalCount,
                completedCount: 0,
                importedCount: 0,
                skippedCount: expandedRequests.skippedItems.count,
                currentPath: "",
                currentName: displayName
            )
        )

        var failureItems = expandedRequests.skippedItems

        guard !requests.isEmpty else {
            progress?(
                LibraryImportProgressSnapshot(
                    phase: .completed,
                    totalCount: totalCount,
                    completedCount: totalCount,
                    importedCount: 0,
                    skippedCount: failureItems.count,
                    currentPath: "",
                    currentName: displayName
                )
            )
            return LibraryImportResult(json: [
                "importedCount": 0,
                "skippedCount": failureItems.count,
                "importedItems": [],
                "failureItems": failureItems.map(\.jsonObject),
                "cleaningSummary": LibraryImportCleaningSummary.empty.jsonObject,
                "cancelled": false
            ])
        }

        var sourceDocuments: [NativeMergedImportSourceDocument] = []
        let initialSkippedCount = failureItems.count
        for (index, request) in requests.enumerated() {
            try throwIfCancelled(isCancelled)
            progress?(
                LibraryImportProgressSnapshot(
                    phase: .importing,
                    totalCount: totalCount,
                    completedCount: initialSkippedCount + index,
                    importedCount: sourceDocuments.count,
                    skippedCount: failureItems.count,
                    currentPath: request.sourceURL.path,
                    currentName: request.sourceURL.lastPathComponent
                )
            )

            do {
                let document = try ImportedDocumentReadingSupport.readImportedDocument(at: request.sourceURL)
                sourceDocuments.append(
                    NativeMergedImportSourceDocument(
                        document: document
                    )
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failureItems.append(
                    LibraryImportFailureItem(
                        path: request.sourceURL.path,
                        fileName: request.sourceURL.lastPathComponent,
                        reason: error.localizedDescription
                    )
                )
            }

            progress?(
                LibraryImportProgressSnapshot(
                    phase: .importing,
                    totalCount: totalCount,
                    completedCount: initialSkippedCount + index + 1,
                    importedCount: sourceDocuments.count,
                    skippedCount: failureItems.count,
                    currentPath: request.sourceURL.path,
                    currentName: request.sourceURL.lastPathComponent
                )
            )
        }

        try throwIfCancelled(isCancelled)
        guard !sourceDocuments.isEmpty else {
            progress?(
                LibraryImportProgressSnapshot(
                    phase: .completed,
                    totalCount: totalCount,
                    completedCount: totalCount,
                    importedCount: 0,
                    skippedCount: failureItems.count,
                    currentPath: "",
                    currentName: displayName
                )
            )
            return LibraryImportResult(json: [
                "importedCount": 0,
                "skippedCount": failureItems.count,
                "importedItems": [],
                "failureItems": failureItems.map(\.jsonObject),
                "cleaningSummary": LibraryImportCleaningSummary.empty.jsonObject,
                "cancelled": false
            ])
        }

        progress?(
            LibraryImportProgressSnapshot(
                phase: .committing,
                totalCount: totalCount,
                completedCount: totalCount,
                importedCount: 0,
                skippedCount: failureItems.count,
                currentPath: "",
                currentName: displayName
            )
        )

        let stagingDirectoryURL = rootURL.appendingPathComponent("import-staging-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectoryURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDirectoryURL) }

        let importedAt = timestamp()
        var importedRecords: [NativeCorpusRecord] = []
        do {
            let record = try writeMergedImportedCorpus(
                name: displayName,
                sources: sourceDocuments,
                folder: requestedFolder,
                storageDirectoryURL: stagingDirectoryURL,
                importedAt: importedAt
            )
            let stagedArtifact = NativeStagedImportArtifact(
                record: record,
                stagedStorageURL: stagingDirectoryURL.appendingPathComponent(record.storageFileName)
            )
            try commitImportedArtifacts(
                [stagedArtifact],
                existingFolders: existingFolders,
                nextFolders: existingFolders,
                existingCorpora: existingCorpora
            )
            importedRecords = [record]
        } catch {
            failureItems.append(
                LibraryImportFailureItem(
                    path: paths.joined(separator: "\n"),
                    fileName: displayName,
                    reason: error.localizedDescription
                )
            )
        }

        let cleaningSummaries = importedRecords.compactMap(\.cleaningSummary)
        let importCleaningSummary = LibraryImportCleaningSummary(
            cleanedCount: cleaningSummaries.count,
            changedCount: cleaningSummaries.filter(\.hasChanges).count,
            ruleHits: aggregateCleaningRuleHits(from: cleaningSummaries)
        )

        progress?(
            LibraryImportProgressSnapshot(
                phase: .completed,
                totalCount: totalCount,
                completedCount: totalCount,
                importedCount: importedRecords.count,
                skippedCount: failureItems.count,
                currentPath: "",
                currentName: displayName
            )
        )

        return LibraryImportResult(json: [
            "importedCount": importedRecords.count,
            "skippedCount": failureItems.count,
            "importedItems": importedRecords.map(\.jsonObject),
            "failureItems": failureItems.map(\.jsonObject),
            "cleaningSummary": importCleaningSummary.jsonObject,
            "cancelled": false
        ])
    }

    func importCorpusPaths(
        _ paths: [String],
        folderId: String,
        preserveHierarchy: Bool,
        progress: LibraryImportProgressHandler?,
        isCancelled: LibraryImportCancellationHandler?
    ) throws -> LibraryImportResult {
        let existingFolders = try loadFolders()
        let existingCorpora = try loadCorpora()
        var folders = existingFolders
        let expandedRequests = try expandImportRequests(paths: paths, preserveHierarchy: preserveHierarchy, folders: &folders)
        let requests = expandedRequests.requests
        let requestedFolder = resolvedFolder(for: folderId, folders: folders)
        let totalCount = requests.count + expandedRequests.skippedItems.count

        progress?(
            LibraryImportProgressSnapshot(
                phase: .preparing,
                totalCount: totalCount,
                completedCount: 0,
                importedCount: 0,
                skippedCount: expandedRequests.skippedItems.count,
                currentPath: "",
                currentName: ""
            )
        )

        var failureItems = expandedRequests.skippedItems

        guard !requests.isEmpty else {
            progress?(
                LibraryImportProgressSnapshot(
                    phase: .completed,
                    totalCount: totalCount,
                    completedCount: totalCount,
                    importedCount: 0,
                    skippedCount: failureItems.count,
                    currentPath: "",
                    currentName: ""
                )
            )
            return LibraryImportResult(json: [
                "importedCount": 0,
                "skippedCount": failureItems.count,
                "importedItems": [],
                "failureItems": failureItems.map(\.jsonObject),
                "cleaningSummary": LibraryImportCleaningSummary.empty.jsonObject,
                "cancelled": false
            ])
        }

        let stagingDirectoryURL = rootURL.appendingPathComponent("import-staging-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: stagingDirectoryURL, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: stagingDirectoryURL) }

        var stagedArtifacts: [NativeStagedImportArtifact] = []
        let importedAt = timestamp()
        let initialSkippedCount = failureItems.count

        for (index, request) in requests.enumerated() {
            try throwIfCancelled(isCancelled)
            progress?(
                LibraryImportProgressSnapshot(
                    phase: .importing,
                    totalCount: totalCount,
                    completedCount: initialSkippedCount + index,
                    importedCount: stagedArtifacts.count,
                    skippedCount: failureItems.count,
                    currentPath: request.sourceURL.path,
                    currentName: request.sourceURL.lastPathComponent
                )
            )

            do {
                let document = try ImportedDocumentReadingSupport.readImportedDocument(at: request.sourceURL)
                let folder = request.folder ?? requestedFolder
                let record = try writeImportedCorpus(
                    sourceURL: request.sourceURL,
                    document: document,
                    folder: folder,
                    storageDirectoryURL: stagingDirectoryURL,
                    importedAt: importedAt
                )
                stagedArtifacts.append(
                    NativeStagedImportArtifact(
                        record: record,
                        stagedStorageURL: stagingDirectoryURL.appendingPathComponent(record.storageFileName)
                    )
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                failureItems.append(
                    LibraryImportFailureItem(
                        path: request.sourceURL.path,
                        fileName: request.sourceURL.lastPathComponent,
                        reason: error.localizedDescription
                    )
                )
            }

            progress?(
                LibraryImportProgressSnapshot(
                    phase: .importing,
                    totalCount: totalCount,
                    completedCount: initialSkippedCount + index + 1,
                    importedCount: stagedArtifacts.count,
                    skippedCount: failureItems.count,
                    currentPath: request.sourceURL.path,
                    currentName: request.sourceURL.lastPathComponent
                )
            )
        }

        try throwIfCancelled(isCancelled)
        progress?(
            LibraryImportProgressSnapshot(
                phase: .committing,
                totalCount: totalCount,
                completedCount: totalCount,
                importedCount: stagedArtifacts.count,
                skippedCount: failureItems.count,
                currentPath: "",
                currentName: ""
            )
        )

        let importedRecords = stagedArtifacts.map(\.record)
        let cleaningSummaries = importedRecords.compactMap(\.cleaningSummary)
        let importCleaningSummary = LibraryImportCleaningSummary(
            cleanedCount: cleaningSummaries.count,
            changedCount: cleaningSummaries.filter(\.hasChanges).count,
            ruleHits: aggregateCleaningRuleHits(from: cleaningSummaries)
        )
        if !stagedArtifacts.isEmpty {
            try commitImportedArtifacts(
                stagedArtifacts,
                existingFolders: existingFolders,
                nextFolders: folders,
                existingCorpora: existingCorpora
            )
        }

        progress?(
            LibraryImportProgressSnapshot(
                phase: .completed,
                totalCount: totalCount,
                completedCount: totalCount,
                importedCount: importedRecords.count,
                skippedCount: failureItems.count,
                currentPath: "",
                currentName: ""
            )
        )

        return LibraryImportResult(json: [
            "importedCount": importedRecords.count,
            "skippedCount": failureItems.count,
            "importedItems": importedRecords.map(\.jsonObject),
            "failureItems": failureItems.map(\.jsonObject),
            "cleaningSummary": importCleaningSummary.jsonObject,
            "cancelled": false
        ])
    }

    private func throwIfCancelled(_ isCancelled: LibraryImportCancellationHandler?) throws {
        if isCancelled?() == true {
            throw CancellationError()
        }
    }

    private func commitImportedArtifacts(
        _ stagedArtifacts: [NativeStagedImportArtifact],
        existingFolders: [NativeFolderRecord],
        nextFolders: [NativeFolderRecord],
        existingCorpora: [NativeCorpusRecord]
    ) throws {
        try storageMutationCoordinator.perform { transaction in
            try snapshotLibraryCatalogMutation(
                transaction,
                folders: existingFolders,
                corpora: existingCorpora
            )
            for artifact in stagedArtifacts {
                let destinationURL = corporaDirectoryURL.appendingPathComponent(artifact.record.storageFileName)
                try transaction.moveItem(at: artifact.stagedStorageURL, to: destinationURL)
            }

            try saveFolders(nextFolders)
            try saveCorpora(existingCorpora + stagedArtifacts.map(\.record))
        }
    }

    private func normalizedMergedCorpusName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "我的语料库" : trimmed
    }

    private func writeMergedImportedCorpus(
        name: String,
        sources: [NativeMergedImportSourceDocument],
        folder: NativeFolderRecord?,
        storageDirectoryURL: URL,
        importedAt: String
    ) throws -> NativeCorpusRecord {
        let rawText = sources
            .map { $0.document.text.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        let cleaned = CorpusAutoCleaningSupport.clean(rawText)
        let trimmedCleanedText = cleaned.cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCleanedText.isEmpty else {
            throw NSError(
                domain: "WordZMac.NativeCorpusStore",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "自动清洗后未保留可用文本：\(name)。"]
            )
        }

        let id = UUID().uuidString
        let storageFileName = uniqueDatabaseFileName(for: name)
        let storageURL = storageDirectoryURL.appendingPathComponent(storageFileName)
        let cleaningSummary = CorpusAutoCleaningSupport.makeReportSummary(
            from: cleaned,
            cleanedAt: importedAt
        )
        try NativeCorpusDatabaseSupport.writeDocument(
            at: storageURL,
            document: DecodedTextDocument(
                text: cleaned.cleanedText,
                encodingName: mergedEncodingName(from: sources)
            ),
            sourceType: "db",
            representedPath: "",
            importedAt: importedAt,
            metadataProfile: .empty,
            rawText: cleaned.rawText,
            cleaningSummary: cleaningSummary,
            sourceFileCount: sources.count
        )

        return NativeCorpusRecord(
            id: id,
            name: name,
            folderId: folder?.id ?? "",
            folderName: folder?.name ?? "未分类",
            sourceType: "db",
            representedPath: "",
            storageFileName: storageFileName,
            metadata: .empty,
            cleaningSummary: cleaningSummary
        )
    }

    private func mergedEncodingName(from sources: [NativeMergedImportSourceDocument]) -> String {
        let names = Set(sources.map(\.document.encodingName).filter { !$0.isEmpty })
        return names.count == 1 ? (names.first ?? "UTF-8") : "Mixed"
    }

    private func uniqueDatabaseFileName(for corpusName: String) -> String {
        let baseName = sanitizedDatabaseBaseName(for: corpusName)
        var candidate = "\(baseName).db"
        var suffix = 2
        while fileManager.fileExists(atPath: corporaDirectoryURL.appendingPathComponent(candidate).path) {
            candidate = "\(baseName)-\(suffix).db"
            suffix += 1
        }
        return candidate
    }

    private func sanitizedDatabaseBaseName(for corpusName: String) -> String {
        let trimmed = normalizedMergedCorpusName(corpusName)
        let withoutExtension = trimmed.lowercased().hasSuffix(".db")
            ? String(trimmed.dropLast(3))
            : trimmed
        let invalidScalars = CharacterSet(charactersIn: "/:")
            .union(.controlCharacters)
        let sanitizedScalars = withoutExtension.unicodeScalars.map { scalar in
            invalidScalars.contains(scalar) ? "-" : String(scalar)
        }
        let sanitized = sanitizedScalars.joined()
            .trimmingCharacters(in: CharacterSet(charactersIn: ". ").union(.whitespacesAndNewlines))
        let fallback = sanitized.isEmpty ? "我的语料库" : sanitized
        return String(fallback.prefix(96))
    }
}

private struct NativeMergedImportSourceDocument {
    let document: DecodedTextDocument
}
