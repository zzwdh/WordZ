import Foundation

@MainActor
protocol WorkspaceRepository: AnyObject {
    func start(userDataURL: URL?) async throws
    func loadBootstrapState() async throws -> WorkspaceBootstrapState
    func listLibrary(folderId: String) async throws -> LibrarySnapshot
    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) async throws -> LibraryImportResult
    func openSavedCorpus(corpusId: String) async throws -> OpenedCorpus
    func loadCorpusInfo(corpusId: String) async throws -> CorpusInfoSummary
    func updateCorpusMetadata(corpusId: String, metadata: CorpusMetadataProfile) async throws -> LibraryCorpusItem
    func renameCorpus(corpusId: String, newName: String) async throws -> LibraryCorpusItem
    func moveCorpus(corpusId: String, targetFolderId: String) async throws -> LibraryCorpusItem
    func deleteCorpus(corpusId: String) async throws
    func createFolder(name: String) async throws -> LibraryFolderItem
    func renameFolder(folderId: String, newName: String) async throws -> LibraryFolderItem
    func deleteFolder(folderId: String) async throws
    func listRecycleBin() async throws -> RecycleBinSnapshot
    func restoreRecycleEntry(recycleEntryId: String) async throws
    func purgeRecycleEntry(recycleEntryId: String) async throws
    func backupLibrary(destinationPath: String) async throws -> LibraryBackupSummary
    func restoreLibrary(sourcePath: String) async throws -> LibraryRestoreSummary
    func repairLibrary() async throws -> LibraryRepairSummary
    func runStats(text: String) async throws -> StatsResult
    func runTokenize(text: String) async throws -> TokenizeResult
    func runTopics(text: String, options: TopicAnalysisOptions) async throws -> TopicAnalysisResult
    func runCompare(comparisonEntries: [CompareRequestEntry]) async throws -> CompareResult
    func runKeyword(
        targetEntry: KeywordRequestEntry,
        referenceEntry: KeywordRequestEntry,
        options: KeywordPreprocessingOptions
    ) async throws -> KeywordResult
    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) async throws -> ChiSquareResult
    func runNgram(text: String, n: Int) async throws -> NgramResult
    func runKWIC(text: String, keyword: String, leftWindow: Int, rightWindow: Int, searchOptions: SearchOptionsState) async throws -> KWICResult
    func runCollocate(text: String, keyword: String, leftWindow: Int, rightWindow: Int, minFreq: Int, searchOptions: SearchOptionsState) async throws -> CollocateResult
    func runLocator(text: String, sentenceId: Int, nodeIndex: Int, leftWindow: Int, rightWindow: Int) async throws -> LocatorResult
    func saveWorkspaceState(_ draft: WorkspaceStateDraft) async throws
    func saveUISettings(_ snapshot: UISettingsSnapshot) async throws
    func stop() async
}

@MainActor
protocol TopicProgressReportingRepository: AnyObject {
    func runTopics(
        text: String,
        options: TopicAnalysisOptions,
        progress: (@Sendable (TopicAnalysisProgress) -> Void)?
    ) async throws -> TopicAnalysisResult
}

@MainActor
protocol LibraryImportProgressReportingRepository: AnyObject {
    func importCorpusPaths(
        _ paths: [String],
        folderId: String,
        preserveHierarchy: Bool,
        progress: (@Sendable (LibraryImportProgressSnapshot) -> Void)?
    ) async throws -> LibraryImportResult
}

@MainActor
protocol CorpusSetManagingRepository: AnyObject {
    func saveCorpusSet(
        name: String,
        corpusIDs: [String],
        metadataFilterState: CorpusMetadataFilterState
    ) async throws -> LibraryCorpusSetItem
    func deleteCorpusSet(corpusSetID: String) async throws
}
