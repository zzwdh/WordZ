import Foundation
import WordZEngine

@MainActor
final class EngineWorkspaceRepository: WorkspaceRepository, MetadataFilteringLibraryRepository {
    private let engineClient: EngineClient
    private let nativeAnalysisRuntime = NativeAnalysisRuntime()

    init(engineClient: EngineClient = EngineClient()) {
        self.engineClient = engineClient
    }

    func start(userDataURL: URL?) async throws {
        try await engineClient.start(userDataURL: userDataURL)
    }

    func loadBootstrapState() async throws -> WorkspaceBootstrapState {
        let nextAppInfo = try await engineClient.fetchAppInfo()
        let nextLibrary = try await engineClient.listLibrary()
        let nextWorkspace = try await engineClient.fetchWorkspaceState()
        let nextUISettings = try await engineClient.fetchUISettings()

        return WorkspaceBootstrapState(
            appInfo: nextAppInfo,
            librarySnapshot: nextLibrary,
            workspaceSnapshot: nextWorkspace,
            uiSettings: nextUISettings
        )
    }

    func listLibrary(folderId: String = "all") async throws -> LibrarySnapshot {
        try await engineClient.listLibrary(folderId: folderId)
    }

    func listLibrary(
        folderId: String,
        metadataFilterState: CorpusMetadataFilterState
    ) async throws -> LibrarySnapshot {
        try await engineClient.listLibrary(
            folderId: folderId,
            metadataFilterState: metadataFilterState
        )
    }

    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) async throws -> LibraryImportResult {
        try await engineClient.importCorpusPaths(paths, folderId: folderId, preserveHierarchy: preserveHierarchy)
    }

    func openSavedCorpus(corpusId: String) async throws -> OpenedCorpus {
        try await engineClient.openSavedCorpus(corpusId: corpusId)
    }

    func loadCorpusInfo(corpusId: String) async throws -> CorpusInfoSummary {
        let corpus = try await openSavedCorpus(corpusId: corpusId)
        let stats = try await runStats(text: corpus.content)
        return CorpusInfoSummary(json: [
            "corpusId": corpusId,
            "title": corpus.displayName,
            "folderName": "",
            "sourceType": corpus.sourceType,
            "representedPath": corpus.filePath,
            "detectedEncoding": "",
            "importedAt": "",
            "tokenCount": stats.tokenCount,
            "typeCount": stats.typeCount,
            "sentenceCount": stats.sentenceCount,
            "paragraphCount": stats.paragraphCount,
            "characterCount": corpus.content.count,
            "ttr": stats.ttr,
            "sttr": stats.sttr,
            "metadata": CorpusMetadataProfile.empty.jsonObject
        ])
    }

    func cleanCorpora(corpusIds: [String]) async throws -> LibraryCorpusCleaningBatchResult {
        throw NSError(
            domain: "WordZMac.EngineWorkspaceRepository",
            code: 12,
            userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持语料自动清洗。"]
        )
    }

    func updateCorpusMetadata(corpusId: String, metadata: CorpusMetadataProfile) async throws -> LibraryCorpusItem {
        throw NSError(
            domain: "WordZMac.EngineWorkspaceRepository",
            code: 11,
            userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持编辑语料元数据。"]
        )
    }

    func renameCorpus(corpusId: String, newName: String) async throws -> LibraryCorpusItem {
        try await engineClient.renameCorpus(corpusId: corpusId, newName: newName)
    }

    func moveCorpus(corpusId: String, targetFolderId: String) async throws -> LibraryCorpusItem {
        try await engineClient.moveCorpus(corpusId: corpusId, targetFolderId: targetFolderId)
    }

    func deleteCorpus(corpusId: String) async throws {
        try await engineClient.deleteCorpus(corpusId: corpusId)
    }

    func createFolder(name: String) async throws -> LibraryFolderItem {
        try await engineClient.createFolder(name: name)
    }

    func renameFolder(folderId: String, newName: String) async throws -> LibraryFolderItem {
        try await engineClient.renameFolder(folderId: folderId, newName: newName)
    }

    func deleteFolder(folderId: String) async throws {
        try await engineClient.deleteFolder(folderId: folderId)
    }

    func listRecycleBin() async throws -> RecycleBinSnapshot {
        try await engineClient.listRecycleBin()
    }

    func restoreRecycleEntry(recycleEntryId: String) async throws {
        try await engineClient.restoreRecycleEntry(recycleEntryId: recycleEntryId)
    }

    func purgeRecycleEntry(recycleEntryId: String) async throws {
        try await engineClient.purgeRecycleEntry(recycleEntryId: recycleEntryId)
    }

    func backupLibrary(destinationPath: String) async throws -> LibraryBackupSummary {
        try await engineClient.backupLibrary(destinationPath: destinationPath)
    }

    func restoreLibrary(sourcePath: String) async throws -> LibraryRestoreSummary {
        try await engineClient.restoreLibrary(sourcePath: sourcePath)
    }

    func repairLibrary() async throws -> LibraryRepairSummary {
        try await engineClient.repairLibrary()
    }

    func runStats(text: String) async throws -> StatsResult {
        try await engineClient.runStats(text: text)
    }

    func runTokenize(text: String) async throws -> TokenizeResult {
        throw NSError(
            domain: "WordZMac.EngineWorkspaceRepository",
            code: 10,
            userInfo: [NSLocalizedDescriptionKey: "当前仓储尚不支持分词分析。"]
        )
    }

    func runTopics(text: String, options: TopicAnalysisOptions) async throws -> TopicAnalysisResult {
        throw TopicAnalysisError.unsupportedRepository
    }

    func runCompare(comparisonEntries: [CompareRequestEntry]) async throws -> CompareResult {
        try await engineClient.runCompare(comparisonEntries: comparisonEntries)
    }

    func runSentiment(_ request: SentimentRunRequest) async throws -> SentimentRunResult {
        return await nativeAnalysisRuntime.runSentiment(request)
    }

    func runKeywordSuite(_ request: KeywordSuiteRunRequest) async throws -> KeywordSuiteResult {
        KeywordSuiteAnalyzer.analyze(request)
    }

    func runKeyword(
        targetEntry: KeywordRequestEntry,
        referenceEntry: KeywordRequestEntry,
        options: KeywordPreprocessingOptions
    ) async throws -> KeywordResult {
        KeywordSuiteAnalyzer.legacyAnalyze(
            target: targetEntry,
            reference: referenceEntry,
            options: options
        )
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) async throws -> ChiSquareResult {
        try await engineClient.runChiSquare(a: a, b: b, c: c, d: d, yates: yates)
    }

    func runNgram(text: String, n: Int) async throws -> NgramResult {
        try await engineClient.runNgram(text: text, n: n)
    }

    func runPlot(_ request: PlotRunRequest) async throws -> PlotResult {
        let normalizedQuery = request.normalizedQuery
        guard !normalizedQuery.isEmpty else {
            throw NSError(
                domain: "WordZMac.EngineWorkspaceRepository",
                code: 13,
                userInfo: [NSLocalizedDescriptionKey: "请输入 Plot 检索词。"]
            )
        }

        var rows: [PlotRow] = []
        rows.reserveCapacity(request.entries.count)

        for (index, entry) in request.entries.enumerated() {
            let distribution = try await nativeAnalysisRuntime.runPlot(
                text: entry.content,
                keyword: normalizedQuery,
                searchOptions: request.searchOptions
            )
            rows.append(
                PlotRow(
                    id: entry.corpusId,
                    corpusId: entry.corpusId,
                    fileID: index,
                    filePath: entry.filePath,
                    displayName: entry.displayName,
                    fileTokens: distribution.tokenCount,
                    frequency: distribution.hitMarkers.count,
                    normalizedFrequency: plotEngineNormalizedFrequency(
                        count: distribution.hitMarkers.count,
                        tokenCount: distribution.tokenCount
                    ),
                    hitMarkers: distribution.hitMarkers
                )
            )
        }

        let totalHits = rows.reduce(0) { $0 + $1.frequency }
        let totalFilesWithHits = rows.reduce(0) { partialResult, row in
            partialResult + (row.frequency > 0 ? 1 : 0)
        }

        return PlotResult(
            request: request,
            totalHits: totalHits,
            totalFilesWithHits: totalFilesWithHits,
            totalFiles: request.entries.count,
            rows: rows
        )
    }

    func runCluster(_ request: ClusterRunRequest) async throws -> ClusterResult {
        return await nativeAnalysisRuntime.runCluster(request)
    }

    func runKWIC(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) async throws -> KWICResult {
        try await engineClient.runKWIC(
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
        try await engineClient.runCollocate(
            text: text,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq,
            searchOptions: searchOptions
        )
    }

    func runLocator(text: String, sentenceId: Int, nodeIndex: Int, leftWindow: Int, rightWindow: Int) async throws -> LocatorResult {
        try await engineClient.runLocator(
            text: text,
            sentenceId: sentenceId,
            nodeIndex: nodeIndex,
            leftWindow: leftWindow,
            rightWindow: rightWindow
        )
    }

    func listKeywordSavedLists() async throws -> [KeywordSavedList] {
        []
    }

    func saveKeywordSavedList(_ list: KeywordSavedList) async throws -> KeywordSavedList {
        list
    }

    func deleteKeywordSavedList(listID: String) async throws {
    }

    func listConcordanceSavedSets() async throws -> [ConcordanceSavedSet] {
        []
    }

    func saveConcordanceSavedSet(_ set: ConcordanceSavedSet) async throws -> ConcordanceSavedSet {
        set
    }

    func deleteConcordanceSavedSet(setID: String) async throws {
    }

    func listEvidenceItems() async throws -> [EvidenceItem] {
        []
    }

    func saveEvidenceItem(_ item: EvidenceItem) async throws -> EvidenceItem {
        item
    }

    func deleteEvidenceItem(itemID: String) async throws {
    }

    func replaceEvidenceItems(_ items: [EvidenceItem]) async throws {
    }

    func listSentimentReviewSamples() async throws -> [SentimentReviewSample] {
        []
    }

    func saveSentimentReviewSample(_ sample: SentimentReviewSample) async throws -> SentimentReviewSample {
        sample
    }

    func deleteSentimentReviewSample(sampleID: String) async throws {
    }

    func replaceSentimentReviewSamples(_ samples: [SentimentReviewSample]) async throws {
    }

    func saveWorkspaceState(_ draft: WorkspaceStateDraft) async throws {
        try await engineClient.saveWorkspaceState(draft)
    }

    func saveUISettings(_ snapshot: UISettingsSnapshot) async throws {
        try await engineClient.saveUISettings(snapshot)
    }

    func stop() async {
        await engineClient.stop()
    }
}

private func plotEngineNormalizedFrequency(count: Int, tokenCount: Int) -> Double {
    guard tokenCount > 0 else { return 0 }
    return (Double(count) / Double(tokenCount)) * 10_000
}
