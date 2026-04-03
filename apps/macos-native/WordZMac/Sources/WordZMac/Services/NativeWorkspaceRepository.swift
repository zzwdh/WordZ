import Foundation

@MainActor
final class NativeWorkspaceRepository: WorkspaceRepository, TopicProgressReportingRepository {
    private let core: NativeWorkspaceRepositoryCore

    init(rootURL: URL = EnginePaths.defaultUserDataURL()) {
        self.core = NativeWorkspaceRepositoryCore(rootURL: rootURL)
    }

    func start(userDataURL: URL?) async throws {
        try await core.start(userDataURL: userDataURL)
    }

    func loadBootstrapState() async throws -> WorkspaceBootstrapState {
        try await core.loadBootstrapState()
    }

    func listLibrary(folderId: String) async throws -> LibrarySnapshot {
        try await core.listLibrary(folderId: folderId)
    }

    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) async throws -> LibraryImportResult {
        try await core.importCorpusPaths(paths, folderId: folderId, preserveHierarchy: preserveHierarchy)
    }

    func openSavedCorpus(corpusId: String) async throws -> OpenedCorpus {
        try await core.openSavedCorpus(corpusId: corpusId)
    }

    func loadCorpusInfo(corpusId: String) async throws -> CorpusInfoSummary {
        try await core.loadCorpusInfo(corpusId: corpusId)
    }

    func updateCorpusMetadata(corpusId: String, metadata: CorpusMetadataProfile) async throws -> LibraryCorpusItem {
        try await core.updateCorpusMetadata(corpusId: corpusId, metadata: metadata)
    }

    func renameCorpus(corpusId: String, newName: String) async throws -> LibraryCorpusItem {
        try await core.renameCorpus(corpusId: corpusId, newName: newName)
    }

    func moveCorpus(corpusId: String, targetFolderId: String) async throws -> LibraryCorpusItem {
        try await core.moveCorpus(corpusId: corpusId, targetFolderId: targetFolderId)
    }

    func deleteCorpus(corpusId: String) async throws {
        try await core.deleteCorpus(corpusId: corpusId)
    }

    func createFolder(name: String) async throws -> LibraryFolderItem {
        try await core.createFolder(name: name)
    }

    func renameFolder(folderId: String, newName: String) async throws -> LibraryFolderItem {
        try await core.renameFolder(folderId: folderId, newName: newName)
    }

    func deleteFolder(folderId: String) async throws {
        try await core.deleteFolder(folderId: folderId)
    }

    func listRecycleBin() async throws -> RecycleBinSnapshot {
        try await core.listRecycleBin()
    }

    func restoreRecycleEntry(recycleEntryId: String) async throws {
        try await core.restoreRecycleEntry(recycleEntryId: recycleEntryId)
    }

    func purgeRecycleEntry(recycleEntryId: String) async throws {
        try await core.purgeRecycleEntry(recycleEntryId: recycleEntryId)
    }

    func backupLibrary(destinationPath: String) async throws -> LibraryBackupSummary {
        try await core.backupLibrary(destinationPath: destinationPath)
    }

    func restoreLibrary(sourcePath: String) async throws -> LibraryRestoreSummary {
        try await core.restoreLibrary(sourcePath: sourcePath)
    }

    func repairLibrary() async throws -> LibraryRepairSummary {
        try await core.repairLibrary()
    }

    func runStats(text: String) async throws -> StatsResult {
        await core.runStats(text: text)
    }

    func runTokenize(text: String) async throws -> TokenizeResult {
        await core.runTokenize(text: text)
    }

    func runTopics(text: String, options: TopicAnalysisOptions) async throws -> TopicAnalysisResult {
        try await core.runTopics(text: text, options: options, progress: nil)
    }

    func runTopics(
        text: String,
        options: TopicAnalysisOptions,
        progress: (@Sendable (TopicAnalysisProgress) -> Void)?
    ) async throws -> TopicAnalysisResult {
        try await core.runTopics(text: text, options: options, progress: progress)
    }

    func runCompare(comparisonEntries: [CompareRequestEntry]) async throws -> CompareResult {
        await core.runCompare(comparisonEntries: comparisonEntries)
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) async throws -> ChiSquareResult {
        await core.runChiSquare(a: a, b: b, c: c, d: d, yates: yates)
    }

    func runNgram(text: String, n: Int) async throws -> NgramResult {
        await core.runNgram(text: text, n: n)
    }

    func runKWIC(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) async throws -> KWICResult {
        try await core.runKWIC(
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
        try await core.runCollocate(
            text: text,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq,
            searchOptions: searchOptions
        )
    }

    func runWordCloud(text: String, limit: Int) async throws -> WordCloudResult {
        await core.runWordCloud(text: text, limit: limit)
    }

    func runLocator(text: String, sentenceId: Int, nodeIndex: Int, leftWindow: Int, rightWindow: Int) async throws -> LocatorResult {
        await core.runLocator(
            text: text,
            sentenceId: sentenceId,
            nodeIndex: nodeIndex,
            leftWindow: leftWindow,
            rightWindow: rightWindow
        )
    }

    func saveWorkspaceState(_ draft: WorkspaceStateDraft) async throws {
        try await core.saveWorkspaceState(draft)
    }

    func saveUISettings(_ snapshot: UISettingsSnapshot) async throws {
        try await core.saveUISettings(snapshot)
    }

    func stop() async {
        await core.stop()
    }
}

private actor NativeWorkspaceRepositoryCore {
    private var rootURL: URL
    private var corpusStore: NativeCorpusStore
    private let analysisEngine: NativeAnalysisEngine
    private let topicEngine: NativeTopicEngine
    private let analysisResultCache = NativeAnalysisResultCache(
        maxEntries: 32,
        maxEntriesByKind: [
            "compare": 8,
            "kwic": 12,
            "collocate": 12,
            "locator": 12
        ]
    )
    private var openedCorpusCache: [String: OpenedCorpus] = [:]
    private var corpusInfoCache: [String: CorpusInfoSummary] = [:]

    init(rootURL: URL) {
        self.rootURL = rootURL
        self.corpusStore = NativeCorpusStore(rootURL: rootURL)
        self.analysisEngine = NativeAnalysisEngine()
        self.topicEngine = NativeTopicEngine()
    }

    func start(userDataURL: URL?) throws {
        let resolvedRoot = userDataURL ?? rootURL
        if resolvedRoot != rootURL {
            rootURL = resolvedRoot
            corpusStore = NativeCorpusStore(rootURL: resolvedRoot)
            openedCorpusCache = [:]
            corpusInfoCache = [:]
            analysisResultCache.removeAll()
        }
        try corpusStore.ensureInitialized()
    }

    func loadBootstrapState() throws -> WorkspaceBootstrapState {
        try ensureReady()
        return WorkspaceBootstrapState(
            appInfo: corpusStore.appInfo(),
            librarySnapshot: try corpusStore.listLibrary(),
            workspaceSnapshot: try corpusStore.loadWorkspaceSnapshot(),
            uiSettings: try corpusStore.loadUISettings()
        )
    }

    func listLibrary(folderId: String) throws -> LibrarySnapshot {
        try ensureReady()
        return try corpusStore.listLibrary(folderId: folderId)
    }

    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) throws -> LibraryImportResult {
        try ensureReady()
        return try corpusStore.importCorpusPaths(paths, folderId: folderId, preserveHierarchy: preserveHierarchy)
    }

    func openSavedCorpus(corpusId: String) throws -> OpenedCorpus {
        try ensureReady()
        if let cached = openedCorpusCache[corpusId] {
            return cached
        }
        let openedCorpus = try corpusStore.openSavedCorpus(corpusId: corpusId)
        openedCorpusCache[corpusId] = openedCorpus
        return openedCorpus
    }

    func loadCorpusInfo(corpusId: String) throws -> CorpusInfoSummary {
        try ensureReady()
        if let cached = corpusInfoCache[corpusId] {
            return cached
        }
        let summary = try corpusStore.loadCorpusInfo(corpusId: corpusId)
        corpusInfoCache[corpusId] = summary
        return summary
    }

    func updateCorpusMetadata(corpusId: String, metadata: CorpusMetadataProfile) throws -> LibraryCorpusItem {
        try ensureReady()
        let item = try corpusStore.updateCorpusMetadata(corpusId: corpusId, metadata: metadata)
        invalidateCorpusInfoCache(corpusId: corpusId)
        return item
    }

    func renameCorpus(corpusId: String, newName: String) throws -> LibraryCorpusItem {
        try ensureReady()
        let item = try corpusStore.renameCorpus(corpusId: corpusId, newName: newName)
        invalidateOpenedCorpusCache(corpusId: corpusId)
        invalidateCorpusInfoCache(corpusId: corpusId)
        invalidateCompareCache()
        return item
    }

    func moveCorpus(corpusId: String, targetFolderId: String) throws -> LibraryCorpusItem {
        try ensureReady()
        let item = try corpusStore.moveCorpus(corpusId: corpusId, targetFolderId: targetFolderId)
        invalidateCorpusInfoCache(corpusId: corpusId)
        invalidateCompareCache()
        return item
    }

    func deleteCorpus(corpusId: String) throws {
        try ensureReady()
        try corpusStore.deleteCorpus(corpusId: corpusId)
        invalidateOpenedCorpusCache(corpusId: corpusId)
        invalidateCorpusInfoCache(corpusId: corpusId)
        invalidateCompareCache()
    }

    func createFolder(name: String) throws -> LibraryFolderItem {
        try ensureReady()
        return try corpusStore.createFolder(name: name)
    }

    func renameFolder(folderId: String, newName: String) throws -> LibraryFolderItem {
        try ensureReady()
        let item = try corpusStore.renameFolder(folderId: folderId, newName: newName)
        invalidateCorpusInfoCache()
        invalidateCompareCache()
        return item
    }

    func deleteFolder(folderId: String) throws {
        try ensureReady()
        try corpusStore.deleteFolder(folderId: folderId)
        invalidateOpenedCorpusCache()
        invalidateCorpusInfoCache()
        invalidateCompareCache()
    }

    func listRecycleBin() throws -> RecycleBinSnapshot {
        try ensureReady()
        return try corpusStore.listRecycleBin()
    }

    func restoreRecycleEntry(recycleEntryId: String) throws {
        try ensureReady()
        try corpusStore.restoreRecycleEntry(recycleEntryId: recycleEntryId)
        invalidateOpenedCorpusCache()
        invalidateCorpusInfoCache()
        invalidateCompareCache()
    }

    func purgeRecycleEntry(recycleEntryId: String) throws {
        try ensureReady()
        try corpusStore.purgeRecycleEntry(recycleEntryId: recycleEntryId)
        invalidateOpenedCorpusCache()
        invalidateCorpusInfoCache()
        invalidateCompareCache()
    }

    func backupLibrary(destinationPath: String) throws -> LibraryBackupSummary {
        try ensureReady()
        return try corpusStore.backupLibrary(destinationPath: destinationPath)
    }

    func restoreLibrary(sourcePath: String) throws -> LibraryRestoreSummary {
        try ensureReady()
        let summary = try corpusStore.restoreLibrary(sourcePath: sourcePath)
        invalidateOpenedCorpusCache()
        invalidateCorpusInfoCache()
        analysisResultCache.removeAll()
        return summary
    }

    func repairLibrary() throws -> LibraryRepairSummary {
        try ensureReady()
        let summary = try corpusStore.repairLibrary()
        invalidateOpenedCorpusCache()
        invalidateCorpusInfoCache()
        invalidateCompareCache()
        return summary
    }

    func runStats(text: String) -> StatsResult {
        let key = NativeAnalysisResultCacheKey.stats(text: text)
        if let cached: StatsResult = analysisResultCache.value(for: key) {
            return cached
        }
        let result = analysisEngine.runStats(text: text)
        analysisResultCache.store(result, for: key)
        return result
    }

    func runTokenize(text: String) -> TokenizeResult {
        let key = NativeAnalysisResultCacheKey.tokenize(text: text)
        if let cached: TokenizeResult = analysisResultCache.value(for: key) {
            return cached
        }
        let result = analysisEngine.runTokenize(text: text)
        analysisResultCache.store(result, for: key)
        return result
    }

    func runTopics(
        text: String,
        options: TopicAnalysisOptions,
        progress: (@Sendable (TopicAnalysisProgress) -> Void)?
    ) async throws -> TopicAnalysisResult {
        try await topicEngine.analyze(text: text, options: options, progress: progress)
    }

    func runCompare(comparisonEntries: [CompareRequestEntry]) -> CompareResult {
        let key = NativeAnalysisResultCacheKey.compare(entries: comparisonEntries)
        if let cached: CompareResult = analysisResultCache.value(for: key) {
            return cached
        }
        let result = analysisEngine.runCompare(comparisonEntries: comparisonEntries)
        analysisResultCache.store(result, for: key)
        return result
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) -> ChiSquareResult {
        analysisEngine.runChiSquare(a: a, b: b, c: c, d: d, yates: yates)
    }

    func runNgram(text: String, n: Int) -> NgramResult {
        let key = NativeAnalysisResultCacheKey.ngram(text: text, n: n)
        if let cached: NgramResult = analysisResultCache.value(for: key) {
            return cached
        }
        let result = analysisEngine.runNgram(text: text, n: n)
        analysisResultCache.store(result, for: key)
        return result
    }

    func runKWIC(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) throws -> KWICResult {
        let key = NativeAnalysisResultCacheKey.kwic(
            text: text,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            searchOptions: searchOptions
        )
        if let cached: KWICResult = analysisResultCache.value(for: key) {
            return cached
        }
        let result = try analysisEngine.runKWIC(
            text: text,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            searchOptions: searchOptions
        )
        analysisResultCache.store(result, for: key)
        return result
    }

    func runCollocate(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        searchOptions: SearchOptionsState
    ) throws -> CollocateResult {
        let key = NativeAnalysisResultCacheKey.collocate(
            text: text,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq,
            searchOptions: searchOptions
        )
        if let cached: CollocateResult = analysisResultCache.value(for: key) {
            return cached
        }
        let result = try analysisEngine.runCollocate(
            text: text,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq,
            searchOptions: searchOptions
        )
        analysisResultCache.store(result, for: key)
        return result
    }

    func runWordCloud(text: String, limit: Int) -> WordCloudResult {
        let key = NativeAnalysisResultCacheKey.wordCloud(text: text)
        if let cached: WordCloudResult = analysisResultCache.value(for: key) {
            return cached
        }
        let result = analysisEngine.runWordCloud(text: text, limit: limit)
        analysisResultCache.store(result, for: key)
        return result
    }

    func runLocator(text: String, sentenceId: Int, nodeIndex: Int, leftWindow: Int, rightWindow: Int) -> LocatorResult {
        let key = NativeAnalysisResultCacheKey.locator(
            text: text,
            sentenceId: sentenceId,
            nodeIndex: nodeIndex,
            leftWindow: leftWindow,
            rightWindow: rightWindow
        )
        if let cached: LocatorResult = analysisResultCache.value(for: key) {
            return cached
        }
        let result = analysisEngine.runLocator(
            text: text,
            sentenceId: sentenceId,
            nodeIndex: nodeIndex,
            leftWindow: leftWindow,
            rightWindow: rightWindow
        )
        analysisResultCache.store(result, for: key)
        return result
    }

    func saveWorkspaceState(_ draft: WorkspaceStateDraft) throws {
        try ensureReady()
        try corpusStore.saveWorkspaceSnapshot(draft)
    }

    func saveUISettings(_ snapshot: UISettingsSnapshot) throws {
        try ensureReady()
        try corpusStore.saveUISettings(snapshot)
    }

    func stop() {}

    private func ensureReady() throws {
        try corpusStore.ensureInitialized()
    }

    private func invalidateOpenedCorpusCache(corpusId: String? = nil) {
        if let corpusId {
            openedCorpusCache[corpusId] = nil
        } else {
            openedCorpusCache.removeAll()
        }
    }

    private func invalidateCorpusInfoCache(corpusId: String? = nil) {
        if let corpusId {
            corpusInfoCache[corpusId] = nil
        } else {
            corpusInfoCache.removeAll()
        }
    }

    private func invalidateCompareCache() {
        analysisResultCache.remove(kind: "compare")
    }
}
