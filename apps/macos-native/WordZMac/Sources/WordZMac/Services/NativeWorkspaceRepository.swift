import Foundation

@MainActor
final class NativeWorkspaceRepository: WorkspaceRepository {
    private var rootURL: URL
    private var corpusStore: NativeCorpusStore
    private let analysisEngine: NativeAnalysisEngine

    init(
        rootURL: URL = EnginePaths.defaultUserDataURL(),
        analysisEngine: NativeAnalysisEngine = NativeAnalysisEngine()
    ) {
        self.rootURL = rootURL
        self.corpusStore = NativeCorpusStore(rootURL: rootURL)
        self.analysisEngine = analysisEngine
    }

    func start(userDataURL: URL?) async throws {
        let resolvedRoot = userDataURL ?? rootURL
        if resolvedRoot != rootURL {
            rootURL = resolvedRoot
            corpusStore = NativeCorpusStore(rootURL: resolvedRoot)
        }
        try corpusStore.ensureInitialized()
    }

    func loadBootstrapState() async throws -> WorkspaceBootstrapState {
        try ensureReady()
        return WorkspaceBootstrapState(
            appInfo: corpusStore.appInfo(),
            librarySnapshot: try corpusStore.listLibrary(),
            workspaceSnapshot: try corpusStore.loadWorkspaceSnapshot(),
            uiSettings: try corpusStore.loadUISettings()
        )
    }

    func listLibrary(folderId: String) async throws -> LibrarySnapshot {
        try ensureReady()
        return try corpusStore.listLibrary(folderId: folderId)
    }

    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) async throws -> LibraryImportResult {
        try ensureReady()
        return try corpusStore.importCorpusPaths(paths, folderId: folderId, preserveHierarchy: preserveHierarchy)
    }

    func openSavedCorpus(corpusId: String) async throws -> OpenedCorpus {
        try ensureReady()
        return try corpusStore.openSavedCorpus(corpusId: corpusId)
    }

    func renameCorpus(corpusId: String, newName: String) async throws -> LibraryCorpusItem {
        try ensureReady()
        return try corpusStore.renameCorpus(corpusId: corpusId, newName: newName)
    }

    func moveCorpus(corpusId: String, targetFolderId: String) async throws -> LibraryCorpusItem {
        try ensureReady()
        return try corpusStore.moveCorpus(corpusId: corpusId, targetFolderId: targetFolderId)
    }

    func deleteCorpus(corpusId: String) async throws {
        try ensureReady()
        try corpusStore.deleteCorpus(corpusId: corpusId)
    }

    func createFolder(name: String) async throws -> LibraryFolderItem {
        try ensureReady()
        return try corpusStore.createFolder(name: name)
    }

    func renameFolder(folderId: String, newName: String) async throws -> LibraryFolderItem {
        try ensureReady()
        return try corpusStore.renameFolder(folderId: folderId, newName: newName)
    }

    func deleteFolder(folderId: String) async throws {
        try ensureReady()
        try corpusStore.deleteFolder(folderId: folderId)
    }

    func listRecycleBin() async throws -> RecycleBinSnapshot {
        try ensureReady()
        return try corpusStore.listRecycleBin()
    }

    func restoreRecycleEntry(recycleEntryId: String) async throws {
        try ensureReady()
        try corpusStore.restoreRecycleEntry(recycleEntryId: recycleEntryId)
    }

    func purgeRecycleEntry(recycleEntryId: String) async throws {
        try ensureReady()
        try corpusStore.purgeRecycleEntry(recycleEntryId: recycleEntryId)
    }

    func backupLibrary(destinationPath: String) async throws -> LibraryBackupSummary {
        try ensureReady()
        return try corpusStore.backupLibrary(destinationPath: destinationPath)
    }

    func restoreLibrary(sourcePath: String) async throws -> LibraryRestoreSummary {
        try ensureReady()
        return try corpusStore.restoreLibrary(sourcePath: sourcePath)
    }

    func repairLibrary() async throws -> LibraryRepairSummary {
        try ensureReady()
        return try corpusStore.repairLibrary()
    }

    func runStats(text: String) async throws -> StatsResult {
        analysisEngine.runStats(text: text)
    }

    func runCompare(comparisonEntries: [CompareRequestEntry]) async throws -> CompareResult {
        analysisEngine.runCompare(comparisonEntries: comparisonEntries)
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) async throws -> ChiSquareResult {
        analysisEngine.runChiSquare(a: a, b: b, c: c, d: d, yates: yates)
    }

    func runNgram(text: String, n: Int) async throws -> NgramResult {
        analysisEngine.runNgram(text: text, n: n)
    }

    func runKWIC(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) async throws -> KWICResult {
        try analysisEngine.runKWIC(
            text: text,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            searchOptions: searchOptions
        )
    }

    func runCollocate(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        searchOptions: SearchOptionsState
    ) async throws -> CollocateResult {
        try analysisEngine.runCollocate(
            text: text,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq,
            searchOptions: searchOptions
        )
    }

    func runWordCloud(text: String, limit: Int) async throws -> WordCloudResult {
        analysisEngine.runWordCloud(text: text, limit: limit)
    }

    func runLocator(text: String, sentenceId: Int, nodeIndex: Int, leftWindow: Int, rightWindow: Int) async throws -> LocatorResult {
        analysisEngine.runLocator(
            text: text,
            sentenceId: sentenceId,
            nodeIndex: nodeIndex,
            leftWindow: leftWindow,
            rightWindow: rightWindow
        )
    }

    func saveWorkspaceState(_ draft: WorkspaceStateDraft) async throws {
        try ensureReady()
        try corpusStore.saveWorkspaceSnapshot(draft)
    }

    func saveUISettings(_ snapshot: UISettingsSnapshot) async throws {
        try ensureReady()
        try corpusStore.saveUISettings(snapshot)
    }

    func stop() async {}

    private func ensureReady() throws {
        try corpusStore.ensureInitialized()
    }
}
