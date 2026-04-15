import Foundation

@MainActor
extension NativeWorkspaceRepository {
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

    func importCorpusPaths(
        _ paths: [String],
        folderId: String,
        preserveHierarchy: Bool,
        progress: (@Sendable (LibraryImportProgressSnapshot) -> Void)?
    ) async throws -> LibraryImportResult {
        try await core.importCorpusPaths(
            paths,
            folderId: folderId,
            preserveHierarchy: preserveHierarchy,
            progress: progress
        )
    }

    func openSavedCorpus(corpusId: String) async throws -> OpenedCorpus {
        try await core.openSavedCorpus(corpusId: corpusId)
    }

    func loadCorpusInfo(corpusId: String) async throws -> CorpusInfoSummary {
        try await core.loadCorpusInfo(corpusId: corpusId)
    }

    func cleanCorpora(corpusIds: [String]) async throws -> LibraryCorpusCleaningBatchResult {
        try await core.cleanCorpora(corpusIds: corpusIds)
    }

    func cleanCorpora(
        corpusIds: [String],
        progress: (@Sendable (LibraryCorpusCleaningProgressSnapshot) -> Void)?
    ) async throws -> LibraryCorpusCleaningBatchResult {
        try await core.cleanCorpora(corpusIds: corpusIds, progress: progress)
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

    func saveCorpusSet(
        name: String,
        corpusIDs: [String],
        metadataFilterState: CorpusMetadataFilterState
    ) async throws -> LibraryCorpusSetItem {
        try await core.saveCorpusSet(
            name: name,
            corpusIDs: corpusIDs,
            metadataFilterState: metadataFilterState
        )
    }

    func deleteCorpusSet(corpusSetID: String) async throws {
        try await core.deleteCorpusSet(corpusSetID: corpusSetID)
    }

    func listAnalysisPresets() async throws -> [AnalysisPresetItem] {
        try await core.listAnalysisPresets()
    }

    func saveAnalysisPreset(name: String, draft: WorkspaceStateDraft) async throws -> AnalysisPresetItem {
        try await core.saveAnalysisPreset(name: name, draft: draft)
    }

    func deleteAnalysisPreset(presetID: String) async throws {
        try await core.deleteAnalysisPreset(presetID: presetID)
    }

    func runStats(text: String) async throws -> StatsResult {
        try await core.runStats(text: text)
    }

    func runTokenize(text: String) async throws -> TokenizeResult {
        try await core.runTokenize(text: text)
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
        try await core.runCompare(comparisonEntries: comparisonEntries)
    }

    func runSentiment(_ request: SentimentRunRequest) async throws -> SentimentRunResult {
        try await core.runSentiment(request)
    }

    func runKeywordSuite(_ request: KeywordSuiteRunRequest) async throws -> KeywordSuiteResult {
        try await core.runKeywordSuite(request)
    }

    func runKeyword(
        targetEntry: KeywordRequestEntry,
        referenceEntry: KeywordRequestEntry,
        options: KeywordPreprocessingOptions
    ) async throws -> KeywordResult {
        try await core.runKeyword(
            targetEntry: targetEntry,
            referenceEntry: referenceEntry,
            options: options
        )
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) async throws -> ChiSquareResult {
        await core.runChiSquare(a: a, b: b, c: c, d: d, yates: yates)
    }

    func runNgram(text: String, n: Int) async throws -> NgramResult {
        try await core.runNgram(text: text, n: n)
    }

    func runPlot(_ request: PlotRunRequest) async throws -> PlotResult {
        try await core.runPlot(request)
    }

    func runCluster(_ request: ClusterRunRequest) async throws -> ClusterResult {
        try await core.runCluster(request)
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

    func runLocator(text: String, sentenceId: Int, nodeIndex: Int, leftWindow: Int, rightWindow: Int) async throws -> LocatorResult {
        try await core.runLocator(
            text: text,
            sentenceId: sentenceId,
            nodeIndex: nodeIndex,
            leftWindow: leftWindow,
            rightWindow: rightWindow
        )
    }

    func listKeywordSavedLists() async throws -> [KeywordSavedList] {
        try await core.listKeywordSavedLists()
    }

    func saveKeywordSavedList(_ list: KeywordSavedList) async throws -> KeywordSavedList {
        try await core.saveKeywordSavedList(list)
    }

    func deleteKeywordSavedList(listID: String) async throws {
        try await core.deleteKeywordSavedList(listID: listID)
    }

    func listConcordanceSavedSets() async throws -> [ConcordanceSavedSet] {
        try await core.listConcordanceSavedSets()
    }

    func saveConcordanceSavedSet(_ set: ConcordanceSavedSet) async throws -> ConcordanceSavedSet {
        try await core.saveConcordanceSavedSet(set)
    }

    func deleteConcordanceSavedSet(setID: String) async throws {
        try await core.deleteConcordanceSavedSet(setID: setID)
    }

    func listEvidenceItems() async throws -> [EvidenceItem] {
        try await core.listEvidenceItems()
    }

    func saveEvidenceItem(_ item: EvidenceItem) async throws -> EvidenceItem {
        try await core.saveEvidenceItem(item)
    }

    func deleteEvidenceItem(itemID: String) async throws {
        try await core.deleteEvidenceItem(itemID: itemID)
    }

    func replaceEvidenceItems(_ items: [EvidenceItem]) async throws {
        try await core.replaceEvidenceItems(items)
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
