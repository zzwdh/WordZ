import Foundation

extension NativeWorkspaceRepositoryCore {
    func start(userDataURL: URL?) throws {
        let resolvedRoot = userDataURL ?? rootURL
        if resolvedRoot != rootURL {
            rootURL = resolvedRoot
            storage = NativeCorpusStore(rootURL: resolvedRoot)
            openedCorpusCache = [:]
            corpusInfoCache = [:]
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
        invalidateCompareCache()
        return result
    }

    func openSavedCorpus(corpusId: String) throws -> OpenedCorpus {
        try ensureReady()
        if let cached = openedCorpusCache[corpusId] {
            return cached
        }
        let openedCorpus = try storage.openSavedCorpus(corpusId: corpusId)
        openedCorpusCache[corpusId] = openedCorpus
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
        invalidateCompareCache()
    }

    func purgeRecycleEntry(recycleEntryId: String) throws {
        try ensureReady()
        try storage.purgeRecycleEntry(recycleEntryId: recycleEntryId)
        invalidateOpenedCorpusCache()
        invalidateCorpusInfoCache()
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
        analysisResultCache.removeAll()
        return summary
    }

    func repairLibrary() throws -> LibraryRepairSummary {
        try ensureReady()
        let summary = try storage.repairLibrary()
        invalidateOpenedCorpusCache()
        invalidateCorpusInfoCache()
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
