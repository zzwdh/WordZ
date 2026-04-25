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
}
