import Foundation

extension NativeWorkspaceRepositoryCore {
    func start(userDataURL: URL?) throws {
        let resolvedRoot = userDataURL ?? rootURL
        if resolvedRoot != rootURL {
            rootURL = resolvedRoot
            storage = NativeCorpusStore(rootURL: resolvedRoot)
            openedCorpusCache = [:]
            corpusInfoCache = [:]
            invalidateStoredFrequencyArtifactCache()
            invalidateStoredTokenizedArtifactCache()
            invalidateStoredTokenPositionIndexCache()
            analysisResultCache.removeAll()
        }
        try storage.ensureInitialized()
    }

    func loadBootstrapState() throws -> WorkspaceBootstrapState {
        try ensureReady()
        return WorkspaceBootstrapState(
            appInfo: storage.appInfo(),
            librarySnapshot: try storage.listLibrary(folderId: "all"),
            workspaceSnapshot: try storage.loadWorkspaceSnapshot(),
            uiSettings: try storage.loadUISettings()
        )
    }

    func listLibrary(folderId: String) throws -> LibrarySnapshot {
        try ensureReady()
        return try storage.listLibrary(folderId: folderId)
    }

    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) throws -> LibraryImportResult {
        try importCorpusPaths(paths, folderId: folderId, preserveHierarchy: preserveHierarchy, progress: nil)
    }

    func importCorpusPaths(
        _ paths: [String],
        folderId: String,
        preserveHierarchy: Bool,
        progress: (@Sendable (LibraryImportProgressSnapshot) -> Void)?
    ) throws -> LibraryImportResult {
        try ensureReady()
        let result: LibraryImportResult
        if let progressStore = storage as? any ProgressReportingLibraryStore {
            result = try progressStore.importCorpusPaths(
                paths,
                folderId: folderId,
                preserveHierarchy: preserveHierarchy,
                progress: progress,
                isCancelled: { Task.isCancelled }
            )
        } else {
            progress?(
                LibraryImportProgressSnapshot(
                    phase: .preparing,
                    totalCount: paths.count,
                    completedCount: 0,
                    importedCount: 0,
                    skippedCount: 0,
                    currentPath: "",
                    currentName: ""
                )
            )
            result = try storage.importCorpusPaths(paths, folderId: folderId, preserveHierarchy: preserveHierarchy)
            progress?(
                LibraryImportProgressSnapshot(
                    phase: .completed,
                    totalCount: max(paths.count, result.importedCount + result.skippedCount),
                    completedCount: max(paths.count, result.importedCount + result.skippedCount),
                    importedCount: result.importedCount,
                    skippedCount: result.skippedCount,
                    currentPath: "",
                    currentName: ""
                )
            )
        }
        invalidateOpenedCorpusCache()
        invalidateCorpusInfoCache()
        invalidateStoredFrequencyArtifactCache()
        invalidateStoredTokenizedArtifactCache()
        invalidateStoredTokenPositionIndexCache()
        invalidateCompareCache()
        return result
    }

    func openSavedCorpus(corpusId: String) throws -> OpenedCorpus {
        try ensureReady()
        if let cached = openedCorpusCache[corpusId] {
            try cacheStoredFrequencyArtifact(for: corpusId, text: cached.content)
            try cacheStoredTokenizedArtifact(for: corpusId, text: cached.content)
            return cached
        }
        let openedCorpus = try storage.openSavedCorpus(corpusId: corpusId)
        openedCorpusCache[corpusId] = openedCorpus
        try cacheStoredFrequencyArtifact(for: corpusId, text: openedCorpus.content)
        try cacheStoredTokenizedArtifact(for: corpusId, text: openedCorpus.content)
        return openedCorpus
    }

    func loadCorpusInfo(corpusId: String) throws -> CorpusInfoSummary {
        try ensureReady()
        if let cached = corpusInfoCache[corpusId] {
            return cached
        }
        let summary = try storage.loadCorpusInfo(corpusId: corpusId)
        corpusInfoCache[corpusId] = summary
        return summary
    }

    func cleanCorpora(corpusIds: [String]) throws -> LibraryCorpusCleaningBatchResult {
        try cleanCorpora(corpusIds: corpusIds, progress: nil)
    }

    func cleanCorpora(
        corpusIds: [String],
        progress: (@Sendable (LibraryCorpusCleaningProgressSnapshot) -> Void)?
    ) throws -> LibraryCorpusCleaningBatchResult {
        try ensureReady()
        let result: LibraryCorpusCleaningBatchResult
        if let cleaningStore = storage as? any CorpusCleaningProgressReportingLibraryStore {
            result = try cleaningStore.cleanCorpora(
                corpusIds: corpusIds,
                progress: progress,
                isCancelled: { Task.isCancelled }
            )
        } else {
            result = try storage.cleanCorpora(corpusIds: corpusIds)
            progress?(
                LibraryCorpusCleaningProgressSnapshot(
                    phase: .completed,
                    totalCount: result.requestedCount,
                    completedCount: result.requestedCount,
                    changedCount: result.changedCount,
                    currentCorpusID: "",
                    currentCorpusName: ""
                )
            )
        }
        let affectedIDs = Set(corpusIds)
        for corpusId in affectedIDs {
            invalidateOpenedCorpusCache(corpusId: corpusId)
            invalidateCorpusInfoCache(corpusId: corpusId)
            invalidateStoredFrequencyArtifactCache(corpusId: corpusId)
            invalidateStoredTokenizedArtifactCache(corpusId: corpusId)
            invalidateStoredTokenPositionIndexCache(corpusId: corpusId)
        }
        analysisResultCache.removeAll()
        return result
    }

    func updateCorpusMetadata(corpusId: String, metadata: CorpusMetadataProfile) throws -> LibraryCorpusItem {
        try ensureReady()
        let item = try storage.updateCorpusMetadata(corpusId: corpusId, metadata: metadata)
        invalidateCorpusInfoCache(corpusId: corpusId)
        return item
    }

    func renameCorpus(corpusId: String, newName: String) throws -> LibraryCorpusItem {
        try ensureReady()
        let item = try storage.renameCorpus(corpusId: corpusId, newName: newName)
        invalidateOpenedCorpusCache(corpusId: corpusId)
        invalidateCorpusInfoCache(corpusId: corpusId)
        invalidateCompareCache()
        return item
    }

    func moveCorpus(corpusId: String, targetFolderId: String) throws -> LibraryCorpusItem {
        try ensureReady()
        let item = try storage.moveCorpus(corpusId: corpusId, targetFolderId: targetFolderId)
        invalidateCorpusInfoCache(corpusId: corpusId)
        invalidateCompareCache()
        return item
    }

    func deleteCorpus(corpusId: String) throws {
        try ensureReady()
        try storage.deleteCorpus(corpusId: corpusId)
        invalidateOpenedCorpusCache(corpusId: corpusId)
        invalidateCorpusInfoCache(corpusId: corpusId)
        invalidateStoredFrequencyArtifactCache(corpusId: corpusId)
        invalidateStoredTokenizedArtifactCache(corpusId: corpusId)
        invalidateStoredTokenPositionIndexCache(corpusId: corpusId)
        invalidateCompareCache()
    }

    func createFolder(name: String) throws -> LibraryFolderItem {
        try ensureReady()
        return try storage.createFolder(name: name)
    }

    func renameFolder(folderId: String, newName: String) throws -> LibraryFolderItem {
        try ensureReady()
        let item = try storage.renameFolder(folderId: folderId, newName: newName)
        invalidateCorpusInfoCache()
        invalidateCompareCache()
        return item
    }

    func deleteFolder(folderId: String) throws {
        try ensureReady()
        try storage.deleteFolder(folderId: folderId)
        invalidateOpenedCorpusCache()
        invalidateCorpusInfoCache()
        invalidateStoredFrequencyArtifactCache()
        invalidateStoredTokenizedArtifactCache()
        invalidateStoredTokenPositionIndexCache()
        invalidateCompareCache()
    }

    func listRecycleBin() throws -> RecycleBinSnapshot {
        try ensureReady()
        return try storage.listRecycleBin()
    }

    func restoreRecycleEntry(recycleEntryId: String) throws {
        try ensureReady()
        try storage.restoreRecycleEntry(recycleEntryId: recycleEntryId)
        invalidateOpenedCorpusCache()
        invalidateCorpusInfoCache()
        invalidateStoredFrequencyArtifactCache()
        invalidateStoredTokenizedArtifactCache()
        invalidateStoredTokenPositionIndexCache()
        invalidateCompareCache()
    }

    func purgeRecycleEntry(recycleEntryId: String) throws {
        try ensureReady()
        try storage.purgeRecycleEntry(recycleEntryId: recycleEntryId)
        invalidateOpenedCorpusCache()
        invalidateCorpusInfoCache()
        invalidateStoredFrequencyArtifactCache()
        invalidateStoredTokenizedArtifactCache()
        invalidateStoredTokenPositionIndexCache()
        invalidateCompareCache()
    }

    func backupLibrary(destinationPath: String) throws -> LibraryBackupSummary {
        try ensureReady()
        return try storage.backupLibrary(destinationPath: destinationPath)
    }

    func restoreLibrary(sourcePath: String) throws -> LibraryRestoreSummary {
        try ensureReady()
        let summary = try storage.restoreLibrary(sourcePath: sourcePath)
        invalidateOpenedCorpusCache()
        invalidateCorpusInfoCache()
        invalidateStoredFrequencyArtifactCache()
        invalidateStoredTokenizedArtifactCache()
        invalidateStoredTokenPositionIndexCache()
        analysisResultCache.removeAll()
        return summary
    }

    func repairLibrary() throws -> LibraryRepairSummary {
        try ensureReady()
        let summary = try storage.repairLibrary()
        invalidateOpenedCorpusCache()
        invalidateCorpusInfoCache()
        invalidateStoredFrequencyArtifactCache()
        invalidateStoredTokenizedArtifactCache()
        invalidateStoredTokenPositionIndexCache()
        invalidateCompareCache()
        return summary
    }

    func saveCorpusSet(
        name: String,
        corpusIDs: [String],
        metadataFilterState: CorpusMetadataFilterState
    ) throws -> LibraryCorpusSetItem {
        try ensureReady()
        guard let store = storage as? any CorpusSetManagingLibraryStore else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 21,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持命名语料集。"]
            )
        }
        return try store.saveCorpusSet(
            name: name,
            corpusIDs: corpusIDs,
            metadataFilterState: metadataFilterState
        )
    }

    func deleteCorpusSet(corpusSetID: String) throws {
        try ensureReady()
        guard let store = storage as? any CorpusSetManagingLibraryStore else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 22,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持命名语料集。"]
            )
        }
        try store.deleteCorpusSet(corpusSetID: corpusSetID)
    }

    func listAnalysisPresets() throws -> [AnalysisPresetItem] {
        try ensureReady()
        guard let store = storage as? any AnalysisPresetManagingStorage else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 23,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持分析预设。"]
            )
        }
        return try store.listAnalysisPresets()
    }

    func saveAnalysisPreset(name: String, draft: WorkspaceStateDraft) throws -> AnalysisPresetItem {
        try ensureReady()
        guard let store = storage as? any AnalysisPresetManagingStorage else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 24,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持分析预设。"]
            )
        }
        return try store.saveAnalysisPreset(name: name, draft: draft)
    }

    func deleteAnalysisPreset(presetID: String) throws {
        try ensureReady()
        guard let store = storage as? any AnalysisPresetManagingStorage else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 25,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持分析预设。"]
            )
        }
        try store.deleteAnalysisPreset(presetID: presetID)
    }

    func listKeywordSavedLists() throws -> [KeywordSavedList] {
        try ensureReady()
        guard let store = storage as? any KeywordSavedListManagingStorage else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 26,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持关键词词表。"]
            )
        }
        return try store.listKeywordSavedLists()
    }

    func saveKeywordSavedList(_ list: KeywordSavedList) throws -> KeywordSavedList {
        try ensureReady()
        guard let store = storage as? any KeywordSavedListManagingStorage else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 27,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持关键词词表。"]
            )
        }
        return try store.saveKeywordSavedList(list)
    }

    func deleteKeywordSavedList(listID: String) throws {
        try ensureReady()
        guard let store = storage as? any KeywordSavedListManagingStorage else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 28,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持关键词词表。"]
            )
        }
        try store.deleteKeywordSavedList(listID: listID)
    }

    func listConcordanceSavedSets() throws -> [ConcordanceSavedSet] {
        try ensureReady()
        guard let store = storage as? any ConcordanceSavedSetManagingStorage else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 29,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持命中集。"]
            )
        }
        return try store.listConcordanceSavedSets()
    }

    func saveConcordanceSavedSet(_ set: ConcordanceSavedSet) throws -> ConcordanceSavedSet {
        try ensureReady()
        guard let store = storage as? any ConcordanceSavedSetManagingStorage else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 30,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持命中集。"]
            )
        }
        return try store.saveConcordanceSavedSet(set)
    }

    func deleteConcordanceSavedSet(setID: String) throws {
        try ensureReady()
        guard let store = storage as? any ConcordanceSavedSetManagingStorage else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 31,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持命中集。"]
            )
        }
        try store.deleteConcordanceSavedSet(setID: setID)
    }

    func listEvidenceItems() throws -> [EvidenceItem] {
        try ensureReady()
        guard let store = storage as? any EvidenceItemManagingStorage else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 32,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持证据条目工作台。"]
            )
        }
        return try store.listEvidenceItems()
    }

    func saveEvidenceItem(_ item: EvidenceItem) throws -> EvidenceItem {
        try ensureReady()
        guard let store = storage as? any EvidenceItemManagingStorage else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 33,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持证据条目工作台。"]
            )
        }
        return try store.saveEvidenceItem(item)
    }

    func deleteEvidenceItem(itemID: String) throws {
        try ensureReady()
        guard let store = storage as? any EvidenceItemManagingStorage else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 34,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持证据条目工作台。"]
            )
        }
        try store.deleteEvidenceItem(itemID: itemID)
    }

    func replaceEvidenceItems(_ items: [EvidenceItem]) throws {
        try ensureReady()
        guard let store = storage as? any EvidenceItemManagingStorage else {
            throw NSError(
                domain: "WordZMac.NativeWorkspaceRepository",
                code: 35,
                userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持证据条目工作台。"]
            )
        }
        try store.replaceEvidenceItems(items)
    }

    func saveWorkspaceState(_ draft: WorkspaceStateDraft) throws {
        try ensureReady()
        try storage.saveWorkspaceSnapshot(draft)
    }

    func saveUISettings(_ snapshot: UISettingsSnapshot) throws {
        try ensureReady()
        try storage.saveUISettings(snapshot)
    }

    func stop() {}
}
