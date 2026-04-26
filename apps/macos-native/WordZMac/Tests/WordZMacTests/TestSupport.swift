import AppKit
import Foundation
@testable import WordZWorkspaceCore

@MainActor
final class FakeWorkspaceRepository: WorkspaceRepository, CorpusSetManagingRepository, AnalysisPresetManagingRepository, FullTextSearchingLibraryRepository, StoredTokenizedArtifactReadingRepository, StoredFrequencyArtifactReadingRepository {
    var startedUserDataURL: URL?
    var stopCalled = false
    var loadBootstrapStateCallCount = 0
    var openSavedCorpusCallCount = 0
    var loadCorpusInfoCallCount = 0
    var updateCorpusMetadataCallCount = 0
    var runStatsCallCount = 0
    var runTokenizeCallCount = 0
    var runTopicsCallCount = 0
    var runCompareCallCount = 0
    var runSentimentCallCount = 0
    var runKeywordSuiteCallCount = 0
    var runKeywordCallCount = 0
    var runChiSquareCallCount = 0
    var runNgramCallCount = 0
    var runPlotCallCount = 0
    var runClusterCallCount = 0
    var runKWICCallCount = 0
    var runCollocateCallCount = 0
    var runLocatorCallCount = 0
    var lastRunPlotRequest: PlotRunRequest?
    var lastRunTopicsText: String?
    var lastRunTopicsOptions: TopicAnalysisOptions?
    var lastSentimentRequest: SentimentRunRequest?
    var lastCompareRequestEntries: [CompareRequestEntry] = []
    var lastKeywordSuiteRequest: KeywordSuiteRunRequest?
    var lastRunKWICKeyword = ""
    var lastRunKWICSearchOptions = SearchOptionsState.default
    var lastRunCollocateSearchOptions = SearchOptionsState.default
    var lastRunLocatorSentenceId: Int?
    var lastRunLocatorNodeIndex: Int?
    var importCorpusPathsCallCount = 0
    var cleanCorporaCallCount = 0
    var listLibraryCallCount = 0
    var fullTextListLibraryCallCount = 0
    var createFolderCallCount = 0
    var renameCorpusCallCount = 0
    var moveCorpusCallCount = 0
    var deleteCorpusCallCount = 0
    var renameFolderCallCount = 0
    var deleteFolderCallCount = 0
    var listRecycleBinCallCount = 0
    var restoreRecycleEntryCallCount = 0
    var purgeRecycleEntryCallCount = 0
    var backupLibraryCallCount = 0
    var restoreLibraryCallCount = 0
    var repairLibraryCallCount = 0
    var saveCorpusSetCallCount = 0
    var deleteCorpusSetCallCount = 0
    var listAnalysisPresetsCallCount = 0
    var saveAnalysisPresetCallCount = 0
    var deleteAnalysisPresetCallCount = 0
    var listKeywordSavedListsCallCount = 0
    var saveKeywordSavedListCallCount = 0
    var deleteKeywordSavedListCallCount = 0
    var listConcordanceSavedSetsCallCount = 0
    var saveConcordanceSavedSetCallCount = 0
    var deleteConcordanceSavedSetCallCount = 0
    var listEvidenceItemsCallCount = 0
    var saveEvidenceItemCallCount = 0
    var deleteEvidenceItemCallCount = 0
    var replaceEvidenceItemsCallCount = 0
    var listSentimentReviewSamplesCallCount = 0
    var saveSentimentReviewSampleCallCount = 0
    var deleteSentimentReviewSampleCallCount = 0
    var replaceSentimentReviewSamplesCallCount = 0
    var savedWorkspaceDrafts: [WorkspaceStateDraft] = []
    var savedUISettings: [UISettingsSnapshot] = []
    var analysisPresetItems: [AnalysisPresetItem] = []
    var keywordSavedLists: [KeywordSavedList] = []
    var concordanceSavedSets: [ConcordanceSavedSet] = []
    var evidenceItems: [EvidenceItem] = []
    var sentimentReviewSamples: [SentimentReviewSample] = []

    var bootstrapState: WorkspaceBootstrapState
    var openedCorpus: OpenedCorpus
    var openedCorporaByID: [String: OpenedCorpus]
    var storedFrequencyArtifactsByCorpusID: [String: StoredFrequencyArtifact] = [:]
    var storedTokenizedArtifactsByCorpusID: [String: StoredTokenizedArtifact] = [:]
    var librarySnapshot: LibrarySnapshot
    var recycleSnapshot: RecycleBinSnapshot
    var statsResult: StatsResult
    var corpusInfoResult: CorpusInfoSummary
    var tokenizeResult: TokenizeResult
    var topicsResult: TopicAnalysisResult
    var compareResult: CompareResult
    var sentimentResult: SentimentRunResult
    var keywordSuiteResult: KeywordSuiteResult
    var keywordResult: KeywordResult
    var chiSquareResult: ChiSquareResult
    var ngramResult: NgramResult
    var plotResult: PlotResult
    var clusterResult: ClusterResult
    var kwicResult: KWICResult
    var collocateResult: CollocateResult
    var locatorResult: LocatorResult
    var backupSummary: LibraryBackupSummary
    var restoreSummary: LibraryRestoreSummary
    var repairSummary: LibraryRepairSummary

    var startError: Error?
    var loadError: Error?
    var openError: Error?
    var updateCorpusMetadataError: Error?
    var importError: Error?
    var cleanCorporaError: Error?
    var listLibraryError: Error?
    var createFolderError: Error?
    var renameCorpusError: Error?
    var moveCorpusError: Error?
    var deleteCorpusError: Error?
    var renameFolderError: Error?
    var deleteFolderError: Error?
    var listRecycleError: Error?
    var restoreRecycleError: Error?
    var purgeRecycleError: Error?
    var backupError: Error?
    var restoreError: Error?
    var repairError: Error?
    var saveCorpusSetError: Error?
    var deleteCorpusSetError: Error?
    var listAnalysisPresetsError: Error?
    var saveAnalysisPresetError: Error?
    var deleteAnalysisPresetError: Error?
    var listConcordanceSavedSetsError: Error?
    var saveConcordanceSavedSetError: Error?
    var deleteConcordanceSavedSetError: Error?
    var listEvidenceItemsError: Error?
    var saveEvidenceItemError: Error?
    var deleteEvidenceItemError: Error?
    var replaceEvidenceItemsError: Error?
    var listSentimentReviewSamplesError: Error?
    var saveSentimentReviewSampleError: Error?
    var deleteSentimentReviewSampleError: Error?
    var replaceSentimentReviewSamplesError: Error?
    var statsError: Error?
    var tokenizeError: Error?
    var topicsError: Error?
    var compareError: Error?
    var sentimentError: Error?
    var keywordSuiteError: Error?
    var keywordError: Error?
    var chiSquareError: Error?
    var ngramError: Error?
    var plotError: Error?
    var clusterError: Error?
    var kwicError: Error?
    var collocateError: Error?
    var locatorError: Error?
    var saveWorkspaceError: Error?
    var saveUISettingsError: Error?
    var topicsDelayNanoseconds: UInt64 = 0
    var compareDelayNanoseconds: UInt64 = 0
    var keywordSuiteDelayNanoseconds: UInt64 = 0
    var kwicDelayNanoseconds: UInt64 = 0
    var saveWorkspaceDelayNanoseconds: UInt64 = 0
    var compareResultProvider: (([CompareRequestEntry]) async throws -> CompareResult)?
    var keywordSuiteResultProvider: ((KeywordSuiteRunRequest) async throws -> KeywordSuiteResult)?
    var kwicResultProvider: ((String) async throws -> KWICResult)?
    var lastListLibrarySearchQuery = ""

    init(
        bootstrapState: WorkspaceBootstrapState = makeBootstrapState(),
        openedCorpus: OpenedCorpus = makeOpenedCorpus(),
        openedCorporaByID: [String: OpenedCorpus] = [:],
        recycleSnapshot: RecycleBinSnapshot = makeRecycleSnapshot(),
        statsResult: StatsResult = makeStatsResult(),
        corpusInfoResult: CorpusInfoSummary = makeCorpusInfoSummary(),
        tokenizeResult: TokenizeResult = makeTokenizeResult(),
        topicsResult: TopicAnalysisResult = makeTopicAnalysisResult(),
        compareResult: CompareResult = makeCompareResult(),
        sentimentResult: SentimentRunResult = makeSentimentResult(),
        keywordSuiteResult: KeywordSuiteResult = makeKeywordSuiteResult(),
        keywordResult: KeywordResult = makeKeywordResult(),
        chiSquareResult: ChiSquareResult = makeChiSquareResult(),
        ngramResult: NgramResult = makeNgramResult(),
        plotResult: PlotResult = makePlotResult(),
        clusterResult: ClusterResult = makeClusterResult(),
        kwicResult: KWICResult = makeKWICResult(),
        collocateResult: CollocateResult = makeCollocateResult(),
        locatorResult: LocatorResult = makeLocatorResult(),
        backupSummary: LibraryBackupSummary = makeLibraryBackupSummary(),
        restoreSummary: LibraryRestoreSummary = makeLibraryRestoreSummary(),
        repairSummary: LibraryRepairSummary = makeLibraryRepairSummary()
    ) {
        self.bootstrapState = bootstrapState
        self.openedCorpus = openedCorpus
        self.openedCorporaByID = openedCorporaByID
        self.librarySnapshot = bootstrapState.librarySnapshot
        self.recycleSnapshot = recycleSnapshot
        self.statsResult = statsResult
        self.corpusInfoResult = corpusInfoResult
        self.tokenizeResult = tokenizeResult
        self.topicsResult = topicsResult
        self.compareResult = compareResult
        self.sentimentResult = sentimentResult
        self.keywordSuiteResult = keywordSuiteResult
        self.keywordResult = keywordResult
        self.chiSquareResult = chiSquareResult
        self.ngramResult = ngramResult
        self.plotResult = plotResult
        self.clusterResult = clusterResult
        self.kwicResult = kwicResult
        self.collocateResult = collocateResult
        self.locatorResult = locatorResult
        self.backupSummary = backupSummary
        self.restoreSummary = restoreSummary
        self.repairSummary = repairSummary
    }

    func start(userDataURL: URL?) async throws {
        startedUserDataURL = userDataURL
        if let startError { throw startError }
    }

    func loadBootstrapState() async throws -> WorkspaceBootstrapState {
        loadBootstrapStateCallCount += 1
        if let loadError { throw loadError }
        return WorkspaceBootstrapState(
            appInfo: bootstrapState.appInfo,
            librarySnapshot: librarySnapshot,
            workspaceSnapshot: bootstrapState.workspaceSnapshot,
            uiSettings: bootstrapState.uiSettings
        )
    }

    func listLibrary(folderId: String) async throws -> LibrarySnapshot {
        listLibraryCallCount += 1
        if let listLibraryError { throw listLibraryError }
        return librarySnapshot
    }

    func listLibrary(
        folderId: String,
        metadataFilterState: CorpusMetadataFilterState,
        searchQuery: String
    ) async throws -> LibrarySnapshot {
        fullTextListLibraryCallCount += 1
        lastListLibrarySearchQuery = searchQuery
        if let listLibraryError { throw listLibraryError }

        let trimmedSearchQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        let filteredCorpora = librarySnapshot.corpora.filter { corpus in
            let metadataMatches = metadataFilterState.isEmpty || metadataFilterState.matches(corpus.metadata)
            let folderMatches = folderId.isEmpty || folderId == "all" || corpus.folderId == folderId
            let searchMatches: Bool
            if trimmedSearchQuery.isEmpty {
                searchMatches = true
            } else {
                let searchableFields = [
                    corpus.name,
                    corpus.folderName,
                    corpus.sourceType,
                    corpus.metadata.sourceLabel,
                    corpus.metadata.yearLabel,
                    corpus.metadata.genreLabel,
                    corpus.metadata.tagsText
                ]
                searchMatches = searchableFields.contains {
                    $0.localizedCaseInsensitiveContains(trimmedSearchQuery)
                }
            }
            return metadataMatches && folderMatches && searchMatches
        }

        return LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: filteredCorpora,
            corpusSets: librarySnapshot.corpusSets
        )
    }

    func saveCorpusSet(
        name: String,
        corpusIDs: [String],
        metadataFilterState: CorpusMetadataFilterState
    ) async throws -> LibraryCorpusSetItem {
        saveCorpusSetCallCount += 1
        if let saveCorpusSetError { throw saveCorpusSetError }

        let corporaByID = Dictionary(uniqueKeysWithValues: librarySnapshot.corpora.map { ($0.id, $0) })
        let resolvedCorpora = corpusIDs.compactMap { corporaByID[$0] }
        let existingSet = librarySnapshot.corpusSets.first {
            $0.name.caseInsensitiveCompare(name) == .orderedSame
        }
        let savedSet = LibraryCorpusSetItem(json: [
            "id": existingSet?.id ?? "set-\(saveCorpusSetCallCount)",
            "name": name,
            "corpusIds": resolvedCorpora.map(\.id),
            "corpusNames": resolvedCorpora.map(\.name),
            "metadataFilter": metadataFilterState.jsonObject,
            "createdAt": existingSet?.createdAt ?? "today",
            "updatedAt": "today"
        ])
        let remainingSets = librarySnapshot.corpusSets.filter { $0.id != savedSet.id }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora,
            corpusSets: remainingSets + [savedSet]
        )
        return savedSet
    }

    func deleteCorpusSet(corpusSetID: String) async throws {
        deleteCorpusSetCallCount += 1
        if let deleteCorpusSetError { throw deleteCorpusSetError }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora,
            corpusSets: librarySnapshot.corpusSets.filter { $0.id != corpusSetID }
        )
    }

    func listAnalysisPresets() async throws -> [AnalysisPresetItem] {
        listAnalysisPresetsCallCount += 1
        if let listAnalysisPresetsError { throw listAnalysisPresetsError }
        return analysisPresetItems
    }

    func saveAnalysisPreset(name: String, draft: WorkspaceStateDraft) async throws -> AnalysisPresetItem {
        saveAnalysisPresetCallCount += 1
        if let saveAnalysisPresetError { throw saveAnalysisPresetError }

        let existing = analysisPresetItems.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }
        let preset = AnalysisPresetItem(
            id: existing?.id ?? "preset-\(saveAnalysisPresetCallCount)",
            name: name,
            createdAt: existing?.createdAt ?? "today",
            updatedAt: "today",
            snapshot: WorkspaceSnapshotSummary(draft: draft)
        )
        analysisPresetItems.removeAll { $0.id == preset.id }
        analysisPresetItems.insert(preset, at: 0)
        return preset
    }

    func deleteAnalysisPreset(presetID: String) async throws {
        deleteAnalysisPresetCallCount += 1
        if let deleteAnalysisPresetError { throw deleteAnalysisPresetError }
        analysisPresetItems.removeAll { $0.id == presetID }
    }

    func importCorpusPaths(_ paths: [String], folderId: String, preserveHierarchy: Bool) async throws -> LibraryImportResult {
        importCorpusPathsCallCount += 1
        if let importError { throw importError }
        let cleaningSummary = makeCleaningReportSummary(
            status: .cleanedWithChanges,
            cleanedAt: "2026-04-11T00:00:00Z",
            originalCharacterCount: 120,
            cleanedCharacterCount: 116,
            ruleHits: [
                LibraryCorpusCleaningRuleHit(id: "space-normalization", count: 2),
                LibraryCorpusCleaningRuleHit(id: "blank-line-collapse", count: 1)
            ]
        )
        let nextCorpus = LibraryCorpusItem(json: makeLibraryCorpusJSON(
            id: "imported-\(importCorpusPathsCallCount)",
            name: URL(fileURLWithPath: paths.first ?? "Imported Corpus").deletingPathExtension().lastPathComponent,
            folderId: folderId,
            folderName: librarySnapshot.folders.first(where: { $0.id == folderId })?.name ?? "Imported",
            sourceType: "txt",
            representedPath: paths.first ?? "",
            metadata: .empty,
            cleaningSummary: cleaningSummary
        ))
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora + [nextCorpus],
            corpusSets: librarySnapshot.corpusSets
        )
        return LibraryImportResult(json: [
            "importedCount": 1,
            "skippedCount": max(0, paths.count - 1),
            "importedItems": [[
                "id": nextCorpus.id,
                "name": nextCorpus.name,
                "folderId": nextCorpus.folderId,
                "folderName": nextCorpus.folderName,
                "sourceType": nextCorpus.sourceType,
                "representedPath": nextCorpus.representedPath,
                "metadata": nextCorpus.metadata.jsonObject,
                "cleaningStatus": nextCorpus.cleaningStatus.rawValue,
                "cleaningSummary": nextCorpus.cleaningSummary?.jsonObject ?? [:]
            ]],
            "cleaningSummary": [
                "cleanedCount": 1,
                "changedCount": 1,
                "ruleHits": cleaningSummary.ruleHits.map(\.jsonObject)
            ],
            "cancelled": false
        ])
    }

    func cleanCorpora(corpusIds: [String]) async throws -> LibraryCorpusCleaningBatchResult {
        cleanCorporaCallCount += 1
        if let cleanCorporaError { throw cleanCorporaError }

        let requestedIDs = Array(Set(corpusIds))
        var cleanedItems: [LibraryCorpusItem] = []
        var ruleHits: [LibraryCorpusCleaningRuleHit] = []

        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora.map { corpus in
                guard requestedIDs.contains(corpus.id) else { return corpus }
                let cleaningSummary = makeCleaningReportSummary(
                    status: .cleanedWithChanges,
                    cleanedAt: "2026-04-11T00:00:00Z",
                    originalCharacterCount: 120,
                    cleanedCharacterCount: 116,
                    ruleHits: [
                        LibraryCorpusCleaningRuleHit(id: "space-normalization", count: 1),
                        LibraryCorpusCleaningRuleHit(id: "blank-line-collapse", count: 1)
                    ]
                )
                ruleHits.append(contentsOf: cleaningSummary.ruleHits)
                let updated = LibraryCorpusItem(json: makeLibraryCorpusJSON(from: corpus, cleaningSummary: cleaningSummary))
                cleanedItems.append(updated)
                return updated
            },
            corpusSets: librarySnapshot.corpusSets
        )

        if let cleanedInfoCorpus = cleanedItems.first(where: { $0.id == corpusInfoResult.corpusId }),
           let cleaningSummary = cleanedInfoCorpus.cleaningSummary {
            corpusInfoResult = CorpusInfoSummary(json: makeCorpusInfoJSON(from: corpusInfoResult, cleaningSummary: cleaningSummary))
        }

        let aggregatedRuleHits = Dictionary(grouping: ruleHits, by: \.id)
            .map { key, hits in
                LibraryCorpusCleaningRuleHit(id: key, count: hits.reduce(0) { $0 + $1.count })
            }
            .sorted { $0.id < $1.id }

        return LibraryCorpusCleaningBatchResult(json: [
            "requestedCount": requestedIDs.count,
            "cleanedCount": cleanedItems.count,
            "changedCount": cleanedItems.filter { $0.cleaningStatus == .cleanedWithChanges }.count,
            "cleanedItems": cleanedItems.map { makeLibraryCorpusJSON(from: $0) },
            "failureItems": [],
            "ruleHits": aggregatedRuleHits.map(\.jsonObject),
            "cancelled": false
        ])
    }

    func openSavedCorpus(corpusId: String) async throws -> OpenedCorpus {
        openSavedCorpusCallCount += 1
        if let openError { throw openError }
        if let openedCorpus = openedCorporaByID[corpusId] {
            return openedCorpus
        }
        return openedCorpus
    }

    func loadStoredFrequencyArtifact(corpusId: String) async throws -> StoredFrequencyArtifact? {
        storedFrequencyArtifactsByCorpusID[corpusId]
    }

    func loadStoredTokenizedArtifact(corpusId: String) async throws -> StoredTokenizedArtifact? {
        storedTokenizedArtifactsByCorpusID[corpusId]
    }

    func loadCorpusInfo(corpusId: String) async throws -> CorpusInfoSummary {
        loadCorpusInfoCallCount += 1
        if let openError { throw openError }
        return CorpusInfoSummary(json: makeCorpusInfoJSON(from: corpusInfoResult, corpusId: corpusId))
    }

    func updateCorpusMetadata(corpusId: String, metadata: CorpusMetadataProfile) async throws -> LibraryCorpusItem {
        updateCorpusMetadataCallCount += 1
        if let updateCorpusMetadataError { throw updateCorpusMetadataError }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora.map { corpus in
                guard corpus.id == corpusId else { return corpus }
                return LibraryCorpusItem(json: makeLibraryCorpusJSON(from: corpus, metadata: metadata))
            },
            corpusSets: librarySnapshot.corpusSets
        )
        if corpusInfoResult.corpusId == corpusId {
            corpusInfoResult = CorpusInfoSummary(json: makeCorpusInfoJSON(from: corpusInfoResult, metadata: metadata))
        }
        return librarySnapshot.corpora.first(where: { $0.id == corpusId }) ?? librarySnapshot.corpora.first ?? LibraryCorpusItem(json: [:])
    }

    func runStats(text: String) async throws -> StatsResult {
        runStatsCallCount += 1
        if let statsError { throw statsError }
        return statsResult
    }

    func runTokenize(text: String) async throws -> TokenizeResult {
        runTokenizeCallCount += 1
        if let tokenizeError { throw tokenizeError }
        return tokenizeResult
    }

    func runTopics(text: String, options: TopicAnalysisOptions) async throws -> TopicAnalysisResult {
        runTopicsCallCount += 1
        lastRunTopicsText = text
        lastRunTopicsOptions = options
        if topicsDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: topicsDelayNanoseconds)
        }
        if let topicsError { throw topicsError }
        return topicsResult
    }

    func runCompare(comparisonEntries: [CompareRequestEntry]) async throws -> CompareResult {
        runCompareCallCount += 1
        lastCompareRequestEntries = comparisonEntries
        if compareDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: compareDelayNanoseconds)
        }
        if let compareError { throw compareError }
        if let compareResultProvider {
            return try await compareResultProvider(comparisonEntries)
        }
        return compareResult
    }

    func runSentiment(_ request: SentimentRunRequest) async throws -> SentimentRunResult {
        runSentimentCallCount += 1
        lastSentimentRequest = request
        if let sentimentError { throw sentimentError }
        return sentimentResult
    }

    func runKeywordSuite(_ request: KeywordSuiteRunRequest) async throws -> KeywordSuiteResult {
        runKeywordSuiteCallCount += 1
        lastKeywordSuiteRequest = request
        if keywordSuiteDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: keywordSuiteDelayNanoseconds)
        }
        if let keywordSuiteError { throw keywordSuiteError }
        if let keywordSuiteResultProvider {
            return try await keywordSuiteResultProvider(request)
        }
        return keywordSuiteResult
    }

    func runKeyword(
        targetEntry: KeywordRequestEntry,
        referenceEntry: KeywordRequestEntry,
        options: KeywordPreprocessingOptions
    ) async throws -> KeywordResult {
        runKeywordCallCount += 1
        if let keywordError { throw keywordError }
        return keywordResult
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) async throws -> ChiSquareResult {
        runChiSquareCallCount += 1
        if let chiSquareError { throw chiSquareError }
        return chiSquareResult
    }

    func runNgram(text: String, n: Int) async throws -> NgramResult {
        runNgramCallCount += 1
        if let ngramError { throw ngramError }
        return NgramResult(json: [
            "n": n,
            "rows": ngramResult.rows.map { [$0.phrase, $0.count] }
        ])
    }

    func runPlot(_ request: PlotRunRequest) async throws -> PlotResult {
        runPlotCallCount += 1
        lastRunPlotRequest = request
        if let plotError { throw plotError }
        return plotResult
    }

    func runCluster(_ request: ClusterRunRequest) async throws -> ClusterResult {
        runClusterCallCount += 1
        if let clusterError { throw clusterError }
        return clusterResult
    }

    func runKWIC(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) async throws -> KWICResult {
        runKWICCallCount += 1
        lastRunKWICKeyword = keyword
        lastRunKWICSearchOptions = searchOptions
        if kwicDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: kwicDelayNanoseconds)
        }
        if let kwicError { throw kwicError }
        if let kwicResultProvider {
            return try await kwicResultProvider(keyword)
        }
        return kwicResult
    }

    func runCollocate(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        searchOptions: SearchOptionsState
    ) async throws -> CollocateResult {
        runCollocateCallCount += 1
        lastRunCollocateSearchOptions = searchOptions
        if let collocateError { throw collocateError }
        return collocateResult
    }

    func runLocator(text: String, sentenceId: Int, nodeIndex: Int, leftWindow: Int, rightWindow: Int) async throws -> LocatorResult {
        runLocatorCallCount += 1
        lastRunLocatorSentenceId = sentenceId
        lastRunLocatorNodeIndex = nodeIndex
        if let locatorError { throw locatorError }
        return locatorResult
    }

    func listKeywordSavedLists() async throws -> [KeywordSavedList] {
        listKeywordSavedListsCallCount += 1
        return keywordSavedLists
    }

    func saveKeywordSavedList(_ list: KeywordSavedList) async throws -> KeywordSavedList {
        saveKeywordSavedListCallCount += 1
        keywordSavedLists.removeAll { $0.id == list.id }
        keywordSavedLists.insert(list, at: 0)
        return list
    }

    func deleteKeywordSavedList(listID: String) async throws {
        deleteKeywordSavedListCallCount += 1
        keywordSavedLists.removeAll { $0.id == listID }
    }

    func listConcordanceSavedSets() async throws -> [ConcordanceSavedSet] {
        listConcordanceSavedSetsCallCount += 1
        if let listConcordanceSavedSetsError { throw listConcordanceSavedSetsError }
        return concordanceSavedSets
    }

    func saveConcordanceSavedSet(_ set: ConcordanceSavedSet) async throws -> ConcordanceSavedSet {
        saveConcordanceSavedSetCallCount += 1
        if let saveConcordanceSavedSetError { throw saveConcordanceSavedSetError }
        concordanceSavedSets.removeAll {
            $0.id == set.id || ($0.kind == set.kind && $0.name.caseInsensitiveCompare(set.name) == .orderedSame)
        }
        concordanceSavedSets.insert(set, at: 0)
        return set
    }

    func deleteConcordanceSavedSet(setID: String) async throws {
        deleteConcordanceSavedSetCallCount += 1
        if let deleteConcordanceSavedSetError { throw deleteConcordanceSavedSetError }
        concordanceSavedSets.removeAll { $0.id == setID }
    }

    func listEvidenceItems() async throws -> [EvidenceItem] {
        listEvidenceItemsCallCount += 1
        if let listEvidenceItemsError { throw listEvidenceItemsError }
        return evidenceItems
    }

    func saveEvidenceItem(_ item: EvidenceItem) async throws -> EvidenceItem {
        saveEvidenceItemCallCount += 1
        if let saveEvidenceItemError { throw saveEvidenceItemError }
        if let existingIndex = evidenceItems.firstIndex(where: { $0.id == item.id }) {
            evidenceItems[existingIndex] = item
        } else {
            evidenceItems.insert(item, at: 0)
        }
        return item
    }

    func deleteEvidenceItem(itemID: String) async throws {
        deleteEvidenceItemCallCount += 1
        if let deleteEvidenceItemError { throw deleteEvidenceItemError }
        evidenceItems.removeAll { $0.id == itemID }
    }

    func replaceEvidenceItems(_ items: [EvidenceItem]) async throws {
        replaceEvidenceItemsCallCount += 1
        if let replaceEvidenceItemsError { throw replaceEvidenceItemsError }
        evidenceItems = items
    }

    func listSentimentReviewSamples() async throws -> [SentimentReviewSample] {
        listSentimentReviewSamplesCallCount += 1
        if let listSentimentReviewSamplesError { throw listSentimentReviewSamplesError }
        return sentimentReviewSamples
    }

    func saveSentimentReviewSample(_ sample: SentimentReviewSample) async throws -> SentimentReviewSample {
        saveSentimentReviewSampleCallCount += 1
        if let saveSentimentReviewSampleError { throw saveSentimentReviewSampleError }
        if let existingIndex = sentimentReviewSamples.firstIndex(where: { $0.id == sample.id || $0.matchKey == sample.matchKey }) {
            sentimentReviewSamples[existingIndex] = sample
        } else {
            sentimentReviewSamples.insert(sample, at: 0)
        }
        return sample
    }

    func deleteSentimentReviewSample(sampleID: String) async throws {
        deleteSentimentReviewSampleCallCount += 1
        if let deleteSentimentReviewSampleError { throw deleteSentimentReviewSampleError }
        sentimentReviewSamples.removeAll { $0.id == sampleID }
    }

    func replaceSentimentReviewSamples(_ samples: [SentimentReviewSample]) async throws {
        replaceSentimentReviewSamplesCallCount += 1
        if let replaceSentimentReviewSamplesError { throw replaceSentimentReviewSamplesError }
        sentimentReviewSamples = samples
    }

    func renameCorpus(corpusId: String, newName: String) async throws -> LibraryCorpusItem {
        renameCorpusCallCount += 1
        if let renameCorpusError { throw renameCorpusError }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora.map { corpus in
                guard corpus.id == corpusId else { return corpus }
                return LibraryCorpusItem(json: makeLibraryCorpusJSON(from: corpus, name: newName))
            },
            corpusSets: librarySnapshot.corpusSets
        )
        return librarySnapshot.corpora.first(where: { $0.id == corpusId }) ?? LibraryCorpusItem(json: [:])
    }

    func moveCorpus(corpusId: String, targetFolderId: String) async throws -> LibraryCorpusItem {
        moveCorpusCallCount += 1
        if let moveCorpusError { throw moveCorpusError }
        let targetName = librarySnapshot.folders.first(where: { $0.id == targetFolderId })?.name ?? "未分类"
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora.map { corpus in
                guard corpus.id == corpusId else { return corpus }
                return LibraryCorpusItem(json: makeLibraryCorpusJSON(from: corpus, folderId: targetFolderId, folderName: targetName))
            },
            corpusSets: librarySnapshot.corpusSets
        )
        return librarySnapshot.corpora.first(where: { $0.id == corpusId }) ?? LibraryCorpusItem(json: [:])
    }

    func deleteCorpus(corpusId: String) async throws {
        deleteCorpusCallCount += 1
        if let deleteCorpusError { throw deleteCorpusError }
        if let deleted = librarySnapshot.corpora.first(where: { $0.id == corpusId }) {
            recycleSnapshot = RecycleBinSnapshot(
                entries: recycleSnapshot.entries + [RecycleBinEntry(json: [
                    "recycleEntryId": "recycle-\(deleteCorpusCallCount)",
                    "type": "corpus",
                    "deletedAt": "today",
                    "name": deleted.name,
                    "originalFolderName": deleted.folderName,
                    "sourceType": deleted.sourceType,
                    "itemCount": 1
                ])],
                folderCount: recycleSnapshot.folderCount,
                corpusCount: recycleSnapshot.corpusCount + 1,
                totalCount: recycleSnapshot.totalCount + 1
            )
        }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders,
            corpora: librarySnapshot.corpora.filter { $0.id != corpusId }
        )
    }

    func createFolder(name: String) async throws -> LibraryFolderItem {
        createFolderCallCount += 1
        if let createFolderError { throw createFolderError }
        let folder = LibraryFolderItem(json: ["id": "folder-\(createFolderCallCount + 10)", "name": name])
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders + [folder],
            corpora: librarySnapshot.corpora
        )
        return folder
    }

    func renameFolder(folderId: String, newName: String) async throws -> LibraryFolderItem {
        renameFolderCallCount += 1
        if let renameFolderError { throw renameFolderError }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders.map { folder in
                guard folder.id == folderId else { return folder }
                return LibraryFolderItem(json: ["id": folder.id, "name": newName])
            },
            corpora: librarySnapshot.corpora.map { corpus in
                guard corpus.folderId == folderId else { return corpus }
                return LibraryCorpusItem(json: makeLibraryCorpusJSON(from: corpus, folderName: newName))
            }
        )
        return librarySnapshot.folders.first(where: { $0.id == folderId }) ?? LibraryFolderItem(json: [:])
    }

    func deleteFolder(folderId: String) async throws {
        deleteFolderCallCount += 1
        if let deleteFolderError { throw deleteFolderError }
        librarySnapshot = LibrarySnapshot(
            folders: librarySnapshot.folders.filter { $0.id != folderId },
            corpora: librarySnapshot.corpora.filter { $0.folderId != folderId },
            corpusSets: librarySnapshot.corpusSets
        )
    }

    func listRecycleBin() async throws -> RecycleBinSnapshot {
        listRecycleBinCallCount += 1
        if let listRecycleError { throw listRecycleError }
        return recycleSnapshot
    }

    func restoreRecycleEntry(recycleEntryId: String) async throws {
        restoreRecycleEntryCallCount += 1
        if let restoreRecycleError { throw restoreRecycleError }
        recycleSnapshot = RecycleBinSnapshot(
            entries: recycleSnapshot.entries.filter { $0.recycleEntryId != recycleEntryId },
            folderCount: recycleSnapshot.folderCount,
            corpusCount: max(0, recycleSnapshot.corpusCount - 1),
            totalCount: max(0, recycleSnapshot.totalCount - 1)
        )
    }

    func purgeRecycleEntry(recycleEntryId: String) async throws {
        purgeRecycleEntryCallCount += 1
        if let purgeRecycleError { throw purgeRecycleError }
        recycleSnapshot = RecycleBinSnapshot(
            entries: recycleSnapshot.entries.filter { $0.recycleEntryId != recycleEntryId },
            folderCount: recycleSnapshot.folderCount,
            corpusCount: max(0, recycleSnapshot.corpusCount - 1),
            totalCount: max(0, recycleSnapshot.totalCount - 1)
        )
    }

    func backupLibrary(destinationPath: String) async throws -> LibraryBackupSummary {
        backupLibraryCallCount += 1
        if let backupError { throw backupError }
        return backupSummary
    }

    func restoreLibrary(sourcePath: String) async throws -> LibraryRestoreSummary {
        restoreLibraryCallCount += 1
        if let restoreError { throw restoreError }
        return restoreSummary
    }

    func repairLibrary() async throws -> LibraryRepairSummary {
        repairLibraryCallCount += 1
        if let repairError { throw repairError }
        return repairSummary
    }

    func saveWorkspaceState(_ draft: WorkspaceStateDraft) async throws {
        if saveWorkspaceDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: saveWorkspaceDelayNanoseconds)
        }
        if let saveWorkspaceError { throw saveWorkspaceError }
        savedWorkspaceDrafts.append(draft)
    }

    func saveUISettings(_ snapshot: UISettingsSnapshot) async throws {
        if let saveUISettingsError { throw saveUISettingsError }
        savedUISettings.append(snapshot)
        bootstrapState = WorkspaceBootstrapState(
            appInfo: bootstrapState.appInfo,
            librarySnapshot: librarySnapshot,
            workspaceSnapshot: bootstrapState.workspaceSnapshot,
            uiSettings: snapshot
        )
    }

    func stop() async {
        stopCalled = true
    }

    private func makeLibraryCorpusJSON(
        id: String,
        name: String,
        folderId: String,
        folderName: String,
        sourceType: String,
        representedPath: String,
        metadata: CorpusMetadataProfile,
        cleaningSummary: LibraryCorpusCleaningReportSummary? = nil
    ) -> JSONObject {
        var json: JSONObject = [
            "id": id,
            "name": name,
            "folderId": folderId,
            "folderName": folderName,
            "sourceType": sourceType,
            "representedPath": representedPath,
            "metadata": metadata.jsonObject,
            "cleaningStatus": (cleaningSummary?.status ?? .pending).rawValue
        ]
        if let cleaningSummary {
            json["cleaningSummary"] = cleaningSummary.jsonObject
        }
        return json
    }

    private func makeLibraryCorpusJSON(
        from corpus: LibraryCorpusItem,
        name: String? = nil,
        folderId: String? = nil,
        folderName: String? = nil,
        metadata: CorpusMetadataProfile? = nil,
        cleaningSummary: LibraryCorpusCleaningReportSummary? = nil
    ) -> JSONObject {
        let resolvedCleaningSummary = cleaningSummary ?? corpus.cleaningSummary
        return makeLibraryCorpusJSON(
            id: corpus.id,
            name: name ?? corpus.name,
            folderId: folderId ?? corpus.folderId,
            folderName: folderName ?? corpus.folderName,
            sourceType: corpus.sourceType,
            representedPath: corpus.representedPath,
            metadata: metadata ?? corpus.metadata,
            cleaningSummary: resolvedCleaningSummary
        )
    }

    private func makeCorpusInfoJSON(
        from summary: CorpusInfoSummary,
        corpusId: String? = nil,
        metadata: CorpusMetadataProfile? = nil,
        cleaningSummary: LibraryCorpusCleaningReportSummary? = nil
    ) -> JSONObject {
        let resolvedCleaningSummary = cleaningSummary ?? summary.cleaningSummary
        var json: JSONObject = [
            "corpusId": corpusId ?? summary.corpusId,
            "title": summary.title,
            "folderName": summary.folderName,
            "sourceType": summary.sourceType,
            "representedPath": summary.representedPath,
            "detectedEncoding": summary.detectedEncoding,
            "importedAt": summary.importedAt,
            "tokenCount": summary.tokenCount,
            "typeCount": summary.typeCount,
            "sentenceCount": summary.sentenceCount,
            "paragraphCount": summary.paragraphCount,
            "characterCount": summary.characterCount,
            "ttr": summary.ttr,
            "sttr": summary.sttr,
            "metadata": (metadata ?? summary.metadata).jsonObject,
            "cleaningStatus": (resolvedCleaningSummary?.status ?? summary.cleaningStatus).rawValue
        ]
        if let resolvedCleaningSummary {
            json["cleaningSummary"] = resolvedCleaningSummary.jsonObject
        }
        return json
    }
}

@MainActor
final class FakeLibraryCoordinator: LibraryCoordinating {
    var openedCorpus: OpenedCorpus
    var lastSelectedCorpusID: String?
    var handleSelectionChangeResult = false
    var openSelectionCallCount = 0
    var ensureOpenedCorpusCallCount = 0

    init(openedCorpus: OpenedCorpus = makeOpenedCorpus()) {
        self.openedCorpus = openedCorpus
    }

    func openSelection(selectedCorpusID: String?) async throws -> OpenedCorpus {
        openSelectionCallCount += 1
        lastSelectedCorpusID = selectedCorpusID
        return openedCorpus
    }

    func ensureOpenedCorpus(selectedCorpusID: String?) async throws -> OpenedCorpus {
        ensureOpenedCorpusCallCount += 1
        lastSelectedCorpusID = selectedCorpusID
        return openedCorpus
    }

    func handleSelectionChange(to selectedCorpusID: String?) -> Bool {
        lastSelectedCorpusID = selectedCorpusID
        return handleSelectionChangeResult
    }
}

struct FakeBootstrapApplier: WorkspaceBootstrapApplying {
    func apply(_ bootstrapState: WorkspaceBootstrapState, to features: WorkspaceFeatureSet) {}
    func finalizeRefresh(features: WorkspaceFeatureSet) async {}
}

@MainActor
final class FakeWorkspaceCoordinatorFactory: WorkspaceCoordinatorBuilding {
    let result: WorkspaceCoordinatorSet
    var makeCallCount = 0

    init(result: WorkspaceCoordinatorSet) {
        self.result = result
    }

    func make(
        repository: any WorkspaceRepository,
        workspacePersistence: WorkspacePersistenceService,
        workspacePresentation: WorkspacePresentationService,
        sceneStore: WorkspaceSceneStore,
        windowDocumentController: any WindowDocumentSyncing,
        dialogService: NativeDialogServicing,
        hostActionService: any NativeHostActionServicing,
        sessionStore: WorkspaceSessionStore,
        hostPreferencesStore: any NativeHostPreferencesStoring,
        buildMetadataProvider: any NativeBuildMetadataProviding,
        taskCenter: NativeTaskCenter,
        libraryCoordinator: (any LibraryCoordinating)?
    ) -> WorkspaceCoordinatorSet {
        makeCallCount += 1
        return result
    }
}

@MainActor
final class SpySentimentWorkflowService: WorkspaceSentimentWorkflowServing {
    var runSentimentCallCount = 0
    var importBundleCallCount = 0
    var exportSummaryCallCount = 0
    var exportStructuredJSONCallCount = 0
    var lastManualText: String?

    func runSentiment(
        features: WorkspaceSentimentWorkflowContext,
        syncFeatureContexts: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        runSentimentCallCount += 1
        lastManualText = features.sentiment.manualText
    }

    func importSentimentUserLexiconBundle(
        features: WorkspaceSentimentWorkflowContext,
        preferredRoute: NativeWindowRoute?,
        markWorkspaceEdited: @escaping @MainActor (WorkspaceFeatureSet) -> Void
    ) async {
        importBundleCallCount += 1
    }

    func exportSentimentSummary(
        features: WorkspaceSentimentWorkflowContext,
        preferredRoute: NativeWindowRoute?
    ) async {
        exportSummaryCallCount += 1
    }

    func exportSentimentStructuredJSON(
        features: WorkspaceSentimentWorkflowContext,
        preferredRoute: NativeWindowRoute?
    ) async {
        exportStructuredJSONCallCount += 1
    }
}

@MainActor
final class SpyWorkspaceFeatureWorkflowFactory: WorkspaceFeatureWorkflowBuilding {
    let sentimentWorkflow: any WorkspaceSentimentWorkflowServing
    var makeCallCount = 0

    init(sentimentWorkflow: any WorkspaceSentimentWorkflowServing) {
        self.sentimentWorkflow = sentimentWorkflow
    }

    func make(
        repository: any WorkspaceRepository,
        sessionStore: WorkspaceSessionStore,
        dialogService: NativeDialogServicing,
        hostActionService: any NativeHostActionServicing,
        exportCoordinator: any WorkspaceExportCoordinating,
        taskCenter: NativeTaskCenter,
        analysisWorkflow: WorkspaceAnalysisWorkflowService
    ) -> WorkspaceFeatureWorkflowSet {
        makeCallCount += 1
        return WorkspaceFeatureWorkflowSet(
            sentiment: sentimentWorkflow,
            topics: WorkspaceTopicsWorkflowService(
                repository: repository,
                sessionStore: sessionStore,
                taskCenter: taskCenter,
                analysisWorkflow: analysisWorkflow
            ),
            evidence: WorkspaceEvidenceWorkflowService(
                repository: repository,
                sessionStore: sessionStore,
                dialogService: dialogService,
                hostActionService: hostActionService,
                exportCoordinator: exportCoordinator
            )
        )
    }
}

@MainActor
final class FakeRuntimeDependencyFactory: MainWorkspaceRuntimeDependencyBuilding {
    let result: MainWorkspaceRuntimeDependencies
    var makeCallCount = 0

    init(result: MainWorkspaceRuntimeDependencies) {
        self.result = result
    }

    func make(
        repository: any WorkspaceRepository,
        workspacePersistence: WorkspacePersistenceService,
        workspacePresentation: WorkspacePresentationService,
        sceneStore: WorkspaceSceneStore,
        windowDocumentController: any WindowDocumentSyncing & WindowDocumentAttaching,
        dialogService: NativeDialogServicing,
        hostPreferencesStore: any NativeHostPreferencesStoring,
        hostActionService: (any NativeHostActionServicing)?,
        updateService: (any NativeUpdateServicing)?,
        notificationService: (any NativeNotificationServicing)?,
        applicationActivityInspector: (any ApplicationActivityInspecting)?,
        buildMetadataProvider: any NativeBuildMetadataProviding,
        taskCenter: NativeTaskCenter,
        sessionStore: WorkspaceSessionStore,
        libraryCoordinator: (any LibraryCoordinating)?,
        coordinatorFactory: (any WorkspaceCoordinatorBuilding)?
    ) -> MainWorkspaceRuntimeDependencies {
        makeCallCount += 1
        return result
    }
}

struct FakeBuildMetadataProvider: NativeBuildMetadataProviding {
    var metadata = NativeBuildMetadata(
        appName: "WordZ",
        bundleIdentifier: "com.test.wordz",
        version: "1.0",
        buildNumber: "1",
        architecture: "arm64",
        builtAt: "2026-04-08",
        gitCommit: "test-commit",
        gitBranch: "test",
        distributionChannel: "test",
        executableSHA256: "sha256"
        ,
        bundlePath: "/Applications/WordZ.app",
        executablePath: "/Applications/WordZ.app/Contents/MacOS/WordZ",
        sourceLabel: "test"
    )

    func current() -> NativeBuildMetadata {
        metadata
    }
}

@MainActor
final class FakeDialogService: NativeDialogServicing {
    var importPathsResult: [String]?
    var openPathResult: String?
    var directoryResult: String?
    var savePathResult: String?
    var exportFormatResult: TableExportFormat? = .csv
    var promptTextResult: String?
    var confirmResult = true
    var openPathPreferredRoute: NativeWindowRoute?
    var promptTextPreferredRoute: NativeWindowRoute?
    var savePathPreferredRoute: NativeWindowRoute?
    var confirmPreferredRoute: NativeWindowRoute?

    func chooseImportPaths(preferredRoute: NativeWindowRoute?) async -> [String]? {
        return importPathsResult
    }

    func chooseOpenPath(
        title: String,
        message: String,
        allowedExtensions: [String],
        preferredRoute: NativeWindowRoute?
    ) async -> String? {
        openPathPreferredRoute = preferredRoute
        return openPathResult
    }

    func chooseDirectory(title: String, message: String, preferredRoute: NativeWindowRoute?) async -> String? {
        return directoryResult
    }

    func chooseSavePath(
        title: String,
        suggestedName: String,
        allowedExtension: String,
        preferredRoute: NativeWindowRoute?
    ) async -> String? {
        savePathPreferredRoute = preferredRoute
        return savePathResult
    }

    func chooseExportFormat(preferredRoute: NativeWindowRoute?) async -> TableExportFormat? {
        return exportFormatResult
    }

    func promptText(
        title: String,
        message: String,
        defaultValue: String,
        confirmTitle: String,
        preferredRoute: NativeWindowRoute?
    ) async -> String? {
        promptTextPreferredRoute = preferredRoute
        return promptTextResult
    }

    func confirm(
        title: String,
        message: String,
        confirmTitle: String,
        preferredRoute: NativeWindowRoute?
    ) async -> Bool {
        confirmPreferredRoute = preferredRoute
        return confirmResult
    }
}

@MainActor
final class InMemoryHostPreferencesStore: NativeHostPreferencesStoring {
    var snapshot = NativeHostPreferencesSnapshot.default
    var saveCallCount = 0
    var recordRecentCallCount = 0
    var clearRecentCallCount = 0
    var recordUpdateCheckCallCount = 0
    var recordDownloadedUpdateCallCount = 0
    var clearDownloadedUpdateCallCount = 0

    func load() -> NativeHostPreferencesSnapshot {
        snapshot
    }

    func save(_ snapshot: NativeHostPreferencesSnapshot) throws {
        saveCallCount += 1
        self.snapshot = snapshot
    }

    func recordRecentDocument(
        corpusID: String,
        title: String,
        subtitle: String,
        representedPath: String
    ) throws -> NativeHostPreferencesSnapshot {
        recordRecentCallCount += 1
        snapshot.recentDocuments.removeAll { $0.corpusID == corpusID }
        snapshot.recentDocuments.insert(
            RecentDocumentItem(
                corpusID: corpusID,
                title: title,
                subtitle: subtitle,
                representedPath: representedPath,
                lastOpenedAt: "2026-03-26T00:00:00Z"
            ),
            at: 0
        )
        return snapshot
    }

    func clearRecentDocuments() throws -> NativeHostPreferencesSnapshot {
        clearRecentCallCount += 1
        snapshot.recentDocuments = []
        return snapshot
    }

    func recordUpdateCheck(status: String) throws -> NativeHostPreferencesSnapshot {
        recordUpdateCheckCallCount += 1
        snapshot.lastUpdateCheckAt = "2026-03-26T00:00:00Z"
        snapshot.lastUpdateStatus = status
        return snapshot
    }

    func recordDownloadedUpdate(version: String, name: String, path: String) throws -> NativeHostPreferencesSnapshot {
        recordDownloadedUpdateCallCount += 1
        snapshot.downloadedUpdateVersion = version
        snapshot.downloadedUpdateName = name
        snapshot.downloadedUpdatePath = path
        return snapshot
    }

    func clearDownloadedUpdate() throws -> NativeHostPreferencesSnapshot {
        clearDownloadedUpdateCallCount += 1
        snapshot.downloadedUpdateVersion = ""
        snapshot.downloadedUpdateName = ""
        snapshot.downloadedUpdatePath = ""
        return snapshot
    }
}

@MainActor
final class FakeHostActionService: NativeHostActionServicing {
    var openedFilePaths: [String] = []
    var openedExternalURLs: [String] = []
    var copiedClipboardTexts: [String] = []
    var quickLookCallCount = 0
    var lastQuickLookPath: String?
    var shareCallCount = 0
    var lastSharedPaths: [String] = []
    var openDownloadedUpdateAndTerminateCallCount = 0
    var lastInstalledDownloadedUpdatePath: String?
    var revealDownloadedUpdateCallCount = 0
    var lastRevealedDownloadedUpdatePath: String?
    var clearRecentDocumentsCallCount = 0
    var exportedArchivePath: String?
    var exportedArchiveTitle: String?
    var exportedArchivePathToReturn: String? = "/tmp/WordZMac-report.zip"
    var exportedArchivePreferredRoute: NativeWindowRoute?
    var exportedDiagnosticArchivePath: String?
    var exportedPathToReturn: String? = "/tmp/WordZMac-diagnostics.zip"
    var exportedDiagnosticPreferredRoute: NativeWindowRoute?

    func openUserDataDirectory(path: String) async throws {
    }

    func openFile(path: String) async throws {
        openedFilePaths.append(path)
    }

    func openURL(_ value: String) async throws {
        openedExternalURLs.append(value)
    }

    func openFeedback() async throws {
    }

    func openReleaseNotes() async throws {
    }

    func openProjectHome() async throws {
    }

    func quickLook(path: String) async throws {
        quickLookCallCount += 1
        lastQuickLookPath = path
    }

    func share(paths: [String]) async throws {
        shareCallCount += 1
        lastSharedPaths = paths
    }

    func openDownloadedUpdate(path: String) async throws {
    }

    func openDownloadedUpdateAndTerminate(path: String) async throws {
        openDownloadedUpdateAndTerminateCallCount += 1
        lastInstalledDownloadedUpdatePath = path
    }

    func revealDownloadedUpdate(path: String) async throws {
        revealDownloadedUpdateCallCount += 1
        lastRevealedDownloadedUpdatePath = path
    }

    func exportArchiveBundle(
        archivePath: String,
        suggestedName: String,
        title: String,
        preferredRoute: NativePresentationRouteHint?
    ) async throws -> String? {
        exportedArchivePath = archivePath
        exportedArchiveTitle = title
        exportedArchivePreferredRoute = preferredRoute?.nativeWindowRoute
        return exportedArchivePathToReturn
    }

    func exportDiagnosticBundle(
        archivePath: String,
        suggestedName: String,
        preferredRoute: NativePresentationRouteHint?
    ) async throws -> String? {
        exportedDiagnosticArchivePath = archivePath
        exportedDiagnosticPreferredRoute = preferredRoute?.nativeWindowRoute
        return exportedPathToReturn
    }

    func clearRecentDocuments() async throws {
        clearRecentDocumentsCallCount += 1
    }

    func noteRecentDocument(path: String) async {}

    func copyTextToClipboard(_ text: String) {
        copiedClipboardTexts.append(text)
    }
}

final class FakeDiagnosticsBundleService: NativeDiagnosticsBundleServicing {
    var artifactToReturn = NativeDiagnosticsBundleArtifact(
        archiveURL: URL(fileURLWithPath: "/tmp/WordZMac-diagnostics.zip"),
        workingDirectoryURL: URL(fileURLWithPath: "/tmp/WordZMac-diagnostics")
    )
    private(set) var lastPayload: NativeDiagnosticsBundlePayload?
    private(set) var cleanedArtifacts: [NativeDiagnosticsBundleArtifact] = []

    func buildBundle(payload: NativeDiagnosticsBundlePayload) throws -> NativeDiagnosticsBundleArtifact {
        lastPayload = payload
        return artifactToReturn
    }

    func cleanup(_ artifact: NativeDiagnosticsBundleArtifact) {
        cleanedArtifacts.append(artifact)
    }
}

@MainActor
final class FakeAnalysisReportBundleService: AnalysisReportBundleServicing {
    var artifactToReturn = AnalysisReportBundleArtifact(
        workingDirectoryURL: URL(fileURLWithPath: "/tmp/WordZMac-report"),
        bundleDirectoryURL: URL(fileURLWithPath: "/tmp/WordZMac-report/WordZMac-stats-report"),
        archiveURL: URL(fileURLWithPath: "/tmp/WordZMac-report.zip")
    )
    private(set) var lastPayload: AnalysisReportBundlePayload?
    private(set) var cleanedArtifacts: [AnalysisReportBundleArtifact] = []

    func buildBundle(payload: AnalysisReportBundlePayload) throws -> AnalysisReportBundleArtifact {
        lastPayload = payload
        return artifactToReturn
    }

    func cleanup(_ artifact: AnalysisReportBundleArtifact) {
        cleanedArtifacts.append(artifact)
    }
}

@MainActor
final class FakeUpdateService: NativeUpdateServicing {
    var checkCallCount = 0
    var downloadCallCount = 0
    var checkDelayNanoseconds: UInt64 = 0
    var downloadDelayNanoseconds: UInt64 = 0
    var result = NativeUpdateCheckResult(
        currentVersion: "1.1.0",
        latestVersion: "1.1.1",
        releaseURL: "https://github.com/zzwdh/WordZ/releases/tag/v1.1.1",
        statusMessage: "发现新版本 1.1.1，可前往发布页下载安装。",
        updateAvailable: true,
        asset: NativeUpdateAsset(
            name: "WordZ-1.1.1-mac-arm64.dmg",
            downloadURL: "https://example.com/WordZ-1.1.1-mac-arm64.dmg"
        ),
        releaseTitle: "WordZ 1.1.1",
        publishedAt: "2026-03-26T00:00:00Z",
        releaseNotes: ["Native table layout persistence"]
    )
    var downloadResult = NativeDownloadedUpdate(
        version: "1.1.1",
        assetName: "WordZ-1.1.1-mac-arm64.dmg",
        localPath: "/tmp/WordZ-1.1.1-mac-arm64.dmg",
        releaseURL: "https://github.com/zzwdh/WordZ/releases/tag/v1.1.1"
    )
    var error: Error?
    var downloadError: Error?

    func checkForUpdates(currentVersion: String) async throws -> NativeUpdateCheckResult {
        checkCallCount += 1
        if checkDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: checkDelayNanoseconds)
        }
        if let error { throw error }
        return NativeUpdateCheckResult(
            currentVersion: currentVersion,
            latestVersion: result.latestVersion,
            releaseURL: result.releaseURL,
            statusMessage: result.statusMessage,
            updateAvailable: result.updateAvailable,
            asset: result.asset,
            releaseTitle: result.releaseTitle,
            publishedAt: result.publishedAt,
            releaseNotes: result.releaseNotes
        )
    }

    func downloadUpdate(
        _ update: NativeUpdateCheckResult,
        onProgress: @escaping @MainActor (Double) -> Void
    ) async throws -> NativeDownloadedUpdate {
        downloadCallCount += 1
        if downloadDelayNanoseconds > 0 {
            try? await Task.sleep(nanoseconds: downloadDelayNanoseconds)
        }
        if let downloadError { throw downloadError }
        onProgress(0.5)
        onProgress(1)
        return downloadResult
    }
}

@MainActor
final class FakeNotificationService: NativeNotificationServicing {
    private(set) var notifications: [(String, String, String)] = []
    var onNotify: (() -> Void)?

    func notify(title: String, subtitle: String, body: String) async {
        notifications.append((title, subtitle, body))
        onNotify?()
    }
}

@MainActor
final class FakeApplicationActivityInspector: ApplicationActivityInspecting {
    var isApplicationActive: Bool
    var shouldDeliverBackgroundNotifications: Bool

    init(
        isApplicationActive: Bool = false,
        shouldDeliverBackgroundNotifications: Bool? = nil
    ) {
        self.isApplicationActive = isApplicationActive
        self.shouldDeliverBackgroundNotifications = shouldDeliverBackgroundNotifications ?? !isApplicationActive
    }
}

@MainActor
final class CountingRootContentSceneBuilder: RootContentSceneBuilding {
    private(set) var buildCallCount = 0

    func build(
        windowTitle: String,
        activeTab: WorkspaceDetailTab,
        languageMode: AppLanguageMode
    ) -> RootContentSceneModel {
        buildCallCount += 1
        return RootContentSceneBuilder().build(
            windowTitle: windowTitle,
            activeTab: activeTab,
            languageMode: languageMode
        )
    }
}

func makeBootstrapState(
    workspaceSnapshot: WorkspaceSnapshotSummary = makeWorkspaceSnapshot(),
    corpusSets: [LibraryCorpusSetItem] = [],
    corpora: [LibraryCorpusItem]? = nil,
    uiSettings: UISettingsSnapshot = .default
) -> WorkspaceBootstrapState {
    let defaultCorpora: [LibraryCorpusItem] = [
        LibraryCorpusItem(json: [
            "id": "corpus-1",
            "name": "Demo Corpus",
            "folderId": "folder-1",
            "folderName": "Default",
            "sourceType": "txt",
            "representedPath": "/tmp/demo.txt",
            "metadata": [
                "sourceLabel": "教材",
                "yearLabel": "2024",
                "genreLabel": "教学",
                "tags": ["课堂", "基础"]
            ],
            "cleaningStatus": "cleanedWithChanges",
            "cleaningSummary": makeCleaningReportSummary(
                status: .cleanedWithChanges,
                cleanedAt: "2026-04-11T00:00:00Z",
                originalCharacterCount: 180,
                cleanedCharacterCount: 176,
                ruleHits: [
                    LibraryCorpusCleaningRuleHit(id: "space-normalization", count: 2)
                ]
            ).jsonObject
        ]),
        LibraryCorpusItem(json: [
            "id": "corpus-2",
            "name": "Compare Corpus",
            "folderId": "folder-1",
            "folderName": "Default",
            "sourceType": "txt",
            "representedPath": "/tmp/compare.txt",
            "metadata": [
                "sourceLabel": "期刊",
                "yearLabel": "2023",
                "genreLabel": "学术",
                "tags": ["研究", "对比"]
            ]
        ])
    ]
    return WorkspaceBootstrapState(
        appInfo: AppInfoSummary(json: [
            "name": "WordZ",
            "version": "1.1.0",
            "help": ["Docs", "Feedback"],
            "releaseNotes": [],
            "userDataDir": "/tmp/wordz"
        ]),
        librarySnapshot: LibrarySnapshot(
            folders: [
                LibraryFolderItem(json: ["id": "folder-1", "name": "Default"])
            ],
            corpora: corpora ?? defaultCorpora,
            corpusSets: corpusSets
        ),
        workspaceSnapshot: workspaceSnapshot,
        uiSettings: uiSettings
    )
}

func makeWorkspaceSnapshot(
    currentTab: String = "kwic",
    selectedCorpusSetID: String = "",
    corpusNames: [String] = ["Demo Corpus"],
    searchQuery: String = "keyword",
    tokenizeLanguagePreset: TokenizeLanguagePreset = .mixedChineseEnglish,
    tokenizeLemmaStrategy: TokenLemmaStrategy = .normalizedSurface,
    compareReferenceCorpusID: String = "",
    compareSelectedCorpusIDs: [String] = [],
    sentimentSource: SentimentInputSource = .openedCorpus,
    sentimentUnit: SentimentAnalysisUnit = .sentence,
    sentimentContextBasis: SentimentContextBasis = .visibleContext,
    sentimentBackend: SentimentBackendKind = .lexicon,
    sentimentDomainPackID: SentimentDomainPackID = .mixed,
    sentimentRuleProfileID: String = SentimentRuleProfile.default.id,
    sentimentCalibrationProfileID: String = SentimentCalibrationProfile.default.id,
    sentimentChartKind: SentimentChartKind = .distributionBar,
    sentimentThresholdPreset: SentimentThresholdPreset = .conservative,
    sentimentDecisionThreshold: Double = SentimentThresholds.default.decisionThreshold,
    sentimentMinimumEvidence: Double = SentimentThresholds.default.minimumEvidence,
    sentimentNeutralBias: Double = SentimentThresholds.default.neutralBias,
    sentimentRowFilterQuery: String = "",
    sentimentLabelFilter: SentimentLabel? = nil,
    sentimentReviewFilter: SentimentReviewFilter = .all,
    sentimentReviewStatusFilter: SentimentReviewStatusFilter = .all,
    sentimentShowOnlyHardCases: Bool = false,
    sentimentWorkspaceCalibrationProfile: SentimentCalibrationProfile = .workspaceDefault,
    sentimentImportedLexiconBundles: [SentimentUserLexiconBundle] = [],
    sentimentSelectedCorpusIDs: [String] = [],
    sentimentReferenceCorpusID: String = "",
    keywordActiveTab: KeywordSuiteTab = .words,
    keywordSuiteConfiguration: KeywordSuiteConfiguration? = nil,
    keywordTargetCorpusID: String = "",
    keywordReferenceCorpusID: String = "",
    annotationProfile: WorkspaceAnnotationProfile = .surface,
    annotationLexicalClasses: [TokenLexicalClass] = [],
    annotationScripts: [TokenScript] = [],
    keywordLowercased: Bool = true,
    keywordRemovePunctuation: Bool = true,
    keywordMinimumFrequency: String = "2",
    keywordStatistic: KeywordStatisticMethod = .logLikelihood,
    keywordStopwordFilter: StopwordFilterState = .default,
    frequencyNormalizationUnit: FrequencyNormalizationUnit = FrequencyMetricDefinition.default.normalizationUnit,
    frequencyRangeMode: FrequencyRangeMode = FrequencyMetricDefinition.default.rangeMode,
    ngramSize: String = "2",
    topicsMinTopicSize: String = "2",
    topicsKeywordDisplayCount: String = "5",
    topicsIncludeOutliers: Bool = true,
    topicsPageSize: String = "50",
    topicsActiveTopicID: String = "",
    chiSquareA: String = "",
    chiSquareB: String = "",
    chiSquareC: String = "",
    chiSquareD: String = "",
    chiSquareUseYates: Bool = false
) -> WorkspaceSnapshotSummary {
    var keyword: JSONObject = [
        "activeTab": keywordActiveTab.rawValue,
        "targetCorpusID": keywordTargetCorpusID,
        "referenceCorpusID": keywordReferenceCorpusID,
        "lowercased": keywordLowercased,
        "removePunctuation": keywordRemovePunctuation,
        "minimumFrequency": keywordMinimumFrequency,
        "statistic": keywordStatistic.rawValue,
        "stopwordFilter": keywordStopwordFilter.asJSONObject()
    ]
    if let keywordSuiteConfiguration {
        keyword["suiteConfiguration"] = keywordSuiteConfiguration.jsonObject
    }

    return WorkspaceSnapshotSummary(json: [
        "currentTab": currentTab,
        "currentLibraryFolderId": "folder-1",
        "workspace": [
            "selectedCorpusSetID": selectedCorpusSetID,
            "corpusNames": corpusNames
        ],
        "annotation": [
            "profile": annotationProfile.rawValue,
            "lexicalClasses": annotationLexicalClasses.map(\.rawValue),
            "scripts": annotationScripts.map(\.rawValue)
        ],
        "search": [
            "query": searchQuery,
            "options": [
                "words": true,
                "caseSensitive": false,
                "regex": false
            ],
            "stopwordFilter": [
                "enabled": false,
                "mode": "exclude",
                "listText": StopwordFilterState.defaultListText
            ]
        ],
        "tokenize": [
            "languagePreset": tokenizeLanguagePreset.rawValue,
            "lemmaStrategy": tokenizeLemmaStrategy.rawValue
        ],
        "compare": [
            "referenceCorpusID": compareReferenceCorpusID,
            "selectedCorpusIDs": compareSelectedCorpusIDs
        ],
        "sentiment": [
            "source": sentimentSource.rawValue,
            "unit": sentimentUnit.rawValue,
            "contextBasis": sentimentContextBasis.rawValue,
            "backend": sentimentBackend.rawValue,
            "domainPackID": sentimentDomainPackID.rawValue,
            "ruleProfileID": sentimentRuleProfileID,
            "calibrationProfileID": sentimentCalibrationProfileID,
            "chartKind": sentimentChartKind.rawValue,
            "thresholdPreset": sentimentThresholdPreset.rawValue,
            "workspaceCalibrationProfile": sentimentCalibrationProfileJSONObject(sentimentWorkspaceCalibrationProfile) as Any,
            "decisionThreshold": sentimentDecisionThreshold,
            "minimumEvidence": sentimentMinimumEvidence,
            "neutralBias": sentimentNeutralBias,
            "rowFilterQuery": sentimentRowFilterQuery,
            "labelFilter": sentimentLabelFilter?.rawValue as Any,
            "reviewFilter": sentimentReviewFilter.rawValue,
            "reviewStatusFilter": sentimentReviewStatusFilter.rawValue,
            "showOnlyHardCases": sentimentShowOnlyHardCases,
            "userLexiconBundles": sentimentImportedLexiconBundles.compactMap(sentimentLexiconBundleJSONObject),
            "selectedCorpusIDs": sentimentSelectedCorpusIDs,
            "referenceCorpusID": sentimentReferenceCorpusID
        ],
        "keyword": keyword,
        "frequencyMetrics": [
            "normalizationUnit": frequencyNormalizationUnit.rawValue,
            "rangeMode": frequencyRangeMode.rawValue
        ],
        "ngram": ["pageSize": "10", "size": ngramSize],
        "kwic": ["leftWindow": "3", "rightWindow": "4"],
        "collocate": ["leftWindow": "5", "rightWindow": "6", "minFreq": "2"],
        "topics": [
            "minTopicSize": topicsMinTopicSize,
            "keywordDisplayCount": topicsKeywordDisplayCount,
            "includeOutliers": topicsIncludeOutliers,
            "pageSize": topicsPageSize,
            "activeTopicID": topicsActiveTopicID
        ],
        "chiSquare": [
            "a": chiSquareA,
            "b": chiSquareB,
            "c": chiSquareC,
            "d": chiSquareD,
            "useYates": chiSquareUseYates
        ]
    ])
}

func makeSentimentUserLexiconBundle(
    id: String = "teaching-bundle",
    version: String = "1.0",
    author: String = "WordZ Tests",
    notes: String = "Imported for testing",
    entries: [SentimentUserLexiconEntry] = [
        SentimentUserLexiconEntry(
            term: "corpus-savvy",
            score: 1.4,
            category: .corePositive,
            domainTags: [.general],
            matchMode: .either
        )
    ]
) -> SentimentUserLexiconBundle {
    SentimentUserLexiconBundle(
        manifest: SentimentUserLexiconBundleManifest(
            id: id,
            version: version,
            author: author,
            notes: notes
        ),
        entries: entries
    )
}

private func sentimentLexiconBundleJSONObject(
    _ bundle: SentimentUserLexiconBundle
) -> JSONObject? {
    guard let data = try? JSONEncoder().encode(bundle),
          let object = try? JSONSerialization.jsonObject(with: data) as? JSONObject
    else {
        return nil
    }
    return object
}

private func sentimentCalibrationProfileJSONObject(
    _ profile: SentimentCalibrationProfile
) -> JSONObject? {
    guard let data = try? JSONEncoder().encode(profile),
          let object = try? JSONSerialization.jsonObject(with: data) as? JSONObject
    else {
        return nil
    }
    return object
}

func makeOpenedCorpus(displayName: String = "Demo Corpus") -> OpenedCorpus {
    OpenedCorpus(json: [
        "mode": "saved",
        "filePath": "/tmp/demo.txt",
        "displayName": displayName,
        "content": "alpha beta gamma alpha beta",
        "sourceType": "txt"
    ])
}

func makeCorpusInfoSummary(title: String = "Demo Corpus") -> CorpusInfoSummary {
    CorpusInfoSummary(json: [
        "corpusId": "corpus-1",
        "title": title,
        "folderName": "Default",
        "sourceType": "txt",
        "representedPath": "/tmp/demo.txt",
        "detectedEncoding": "UTF-8",
        "importedAt": "2026-04-03T00:00:00Z",
        "tokenCount": 30,
        "typeCount": 12,
        "sentenceCount": 6,
        "paragraphCount": 3,
        "characterCount": 180,
        "ttr": 0.4,
        "sttr": 0.37,
        "metadata": [
            "sourceLabel": "教材",
            "yearLabel": "2024",
            "genreLabel": "教学",
            "tags": ["课堂", "基础"]
        ],
        "cleaningStatus": "cleanedWithChanges",
        "cleaningSummary": makeCleaningReportSummary(
            status: .cleanedWithChanges,
            cleanedAt: "2026-04-11T00:00:00Z",
            originalCharacterCount: 180,
            cleanedCharacterCount: 176,
            ruleHits: [
                LibraryCorpusCleaningRuleHit(id: "space-normalization", count: 2),
                LibraryCorpusCleaningRuleHit(id: "blank-line-collapse", count: 1)
            ]
        ).jsonObject
    ])
}

func makeCleaningReportSummary(
    status: LibraryCorpusCleaningStatus = .cleanedWithChanges,
    cleanedAt: String = "2026-04-11T00:00:00Z",
    originalCharacterCount: Int = 180,
    cleanedCharacterCount: Int = 176,
    ruleHits: [LibraryCorpusCleaningRuleHit] = [
        LibraryCorpusCleaningRuleHit(id: "space-normalization", count: 2)
    ]
) -> LibraryCorpusCleaningReportSummary {
    LibraryCorpusCleaningReportSummary(
        status: status,
        cleanedAt: cleanedAt,
        profileVersion: "v1",
        originalCharacterCount: originalCharacterCount,
        cleanedCharacterCount: cleanedCharacterCount,
        ruleHits: ruleHits
    )
}

func makeStatsResult(rowCount: Int = 3) -> StatsResult {
    let tokenCount = rowCount * 10
    let segmentCount = max(rowCount, 1)
    let rows: [[String: Any]] = (0..<rowCount).map { index in
        let count = rowCount - index
        let range = max(1, rowCount - index)
        return [
            "word": "word-\(index)",
            "count": count,
            "rank": index + 1,
            "normFreq": (Double(count) / Double(max(tokenCount, 1))) * 10_000,
            "range": range,
            "normRange": (Double(range) / Double(segmentCount)) * 100,
            "sentenceRange": range,
            "paragraphRange": range
        ]
    }
    return StatsResult(json: [
        "tokenCount": tokenCount,
        "typeCount": rowCount,
        "ttr": 0.5,
        "sttr": 0.4,
        "sentenceCount": segmentCount,
        "paragraphCount": segmentCount,
        "freqRows": rows
    ])
}

func makeTokenizeResult() -> TokenizeResult {
    TokenizeResult(
        sentences: [
            TokenizedSentence(
                sentenceId: 0,
                text: "Alpha beta gamma.",
                tokens: [
                    TokenizedToken(
                        original: "Alpha",
                        normalized: "alpha",
                        sentenceId: 0,
                        tokenIndex: 0,
                        annotations: TokenLinguisticAnnotations(script: .latin, lemma: "alpha", lexicalClass: .noun)
                    ),
                    TokenizedToken(
                        original: "beta",
                        normalized: "beta",
                        sentenceId: 0,
                        tokenIndex: 1,
                        annotations: TokenLinguisticAnnotations(script: .latin, lemma: "beta", lexicalClass: .noun)
                    ),
                    TokenizedToken(
                        original: "gamma",
                        normalized: "gamma",
                        sentenceId: 0,
                        tokenIndex: 2,
                        annotations: TokenLinguisticAnnotations(script: .latin, lemma: "gamma", lexicalClass: .noun)
                    )
                ]
            ),
            TokenizedSentence(
                sentenceId: 1,
                text: "Delta alpha.",
                tokens: [
                    TokenizedToken(
                        original: "Delta",
                        normalized: "delta",
                        sentenceId: 1,
                        tokenIndex: 0,
                        annotations: TokenLinguisticAnnotations(script: .latin, lemma: "delta", lexicalClass: .noun)
                    ),
                    TokenizedToken(
                        original: "alpha",
                        normalized: "alpha",
                        sentenceId: 1,
                        tokenIndex: 1,
                        annotations: TokenLinguisticAnnotations(script: .latin, lemma: "alpha", lexicalClass: .noun)
                    )
                ]
            )
        ]
    )
}

func makeTopicAnalysisResult() -> TopicAnalysisResult {
    TopicAnalysisResult(
        modelVersion: "wordz-topics-english-1",
        modelProvider: "system-sentence-embedding",
        usesFallbackProvider: false,
        clusters: [
            TopicClusterSummary(
                id: "topic-1",
                index: 1,
                isOutlier: false,
                size: 2,
                keywordCandidates: [
                    TopicKeywordCandidate(term: "security", score: 1.42),
                    TopicKeywordCandidate(term: "hacker", score: 1.17)
                ],
                representativeSegmentIDs: ["paragraph-1"]
            ),
            TopicClusterSummary(
                id: TopicAnalysisResult.outlierTopicID,
                index: 0,
                isOutlier: true,
                size: 1,
                keywordCandidates: [
                    TopicKeywordCandidate(term: "misc", score: 0.75)
                ],
                representativeSegmentIDs: ["paragraph-3"]
            )
        ],
        segments: [
            TopicSegmentRow(
                id: "paragraph-1",
                topicID: "topic-1",
                paragraphIndex: 1,
                text: "Security researchers discussed hacker communities and disclosure norms.",
                similarityScore: 0.91,
                isOutlier: false
            ),
            TopicSegmentRow(
                id: "paragraph-2",
                topicID: "topic-1",
                paragraphIndex: 2,
                text: "Hackers shared exploit mitigation strategies and coordinated fixes.",
                similarityScore: 0.88,
                isOutlier: false
            ),
            TopicSegmentRow(
                id: "paragraph-3",
                topicID: TopicAnalysisResult.outlierTopicID,
                paragraphIndex: 3,
                text: "A short unrelated paragraph about coffee and weather.",
                similarityScore: 0.0,
                isOutlier: true
            )
        ],
        totalSegments: 3,
        clusteredSegments: 2,
        outlierCount: 1,
        warnings: []
    )
}

func makeCompareTopicsResult(focusTerm: String = "alpha") -> TopicAnalysisResult {
    TopicAnalysisResult(
        modelVersion: "wordz-topics-english-1",
        modelProvider: "system-sentence-embedding",
        usesFallbackProvider: false,
        clusters: [
            TopicClusterSummary(
                id: "topic-1",
                index: 1,
                isOutlier: false,
                size: 2,
                keywordCandidates: [
                    TopicKeywordCandidate(term: focusTerm, score: 1.35),
                    TopicKeywordCandidate(term: "contrast", score: 1.08)
                ],
                representativeSegmentIDs: ["compare-topic-reference-1"]
            )
        ],
        segments: [
            TopicSegmentRow(
                id: "compare-topic-reference-1",
                topicID: "topic-1",
                paragraphIndex: 2,
                text: "\(focusTerm) reference framing keeps the contrast visible.",
                similarityScore: 0.94,
                isOutlier: false,
                sourceID: "corpus-2",
                sourceTitle: "Compare Corpus",
                groupID: "reference",
                groupTitle: "Reference",
                sourceParagraphIndex: 1
            ),
            TopicSegmentRow(
                id: "compare-topic-target-1",
                topicID: "topic-1",
                paragraphIndex: 1,
                text: "\(focusTerm) target framing keeps the comparison grounded.",
                similarityScore: 0.82,
                isOutlier: false,
                sourceID: "corpus-1",
                sourceTitle: "Demo Corpus",
                groupID: "target",
                groupTitle: "Target",
                sourceParagraphIndex: 1
            )
        ],
        totalSegments: 2,
        clusteredSegments: 2,
        outlierCount: 0,
        warnings: []
    )
}

func makeNgramResult(rowCount: Int = 3, n: Int = 2) -> NgramResult {
    let rows: [[Any]] = (0..<rowCount).map { index in
        ["phrase-\(index)", rowCount - index]
    }
    return NgramResult(json: [
        "n": n,
        "rows": rows
    ])
}

func makePlotResult(
    query: String = "alpha",
    scope: PlotScopeResolution = .singleCorpus,
    searchOptions: SearchOptionsState = .default,
    rows: [PlotRow] = [
        PlotRow(
            id: "corpus-1",
            corpusId: "corpus-1",
            fileID: 0,
            filePath: "/tmp/demo.txt",
            displayName: "Demo Corpus",
            fileTokens: 120,
            frequency: 3,
            normalizedFrequency: 250,
            hitMarkers: [
                PlotHitMarker(id: "0-0", sentenceId: 0, tokenIndex: 0, normalizedPosition: 0),
                PlotHitMarker(id: "0-4", sentenceId: 0, tokenIndex: 4, normalizedPosition: 0.5),
                PlotHitMarker(id: "1-2", sentenceId: 1, tokenIndex: 2, normalizedPosition: 1)
            ]
        ),
        PlotRow(
            id: "corpus-2",
            corpusId: "corpus-2",
            fileID: 1,
            filePath: "/tmp/compare.txt",
            displayName: "Compare Corpus",
            fileTokens: 80,
            frequency: 1,
            normalizedFrequency: 125,
            hitMarkers: [
                PlotHitMarker(id: "0-1", sentenceId: 0, tokenIndex: 1, normalizedPosition: 0.25)
            ]
        )
    ]
) -> PlotResult {
    PlotResult(
        request: PlotRunRequest(
            entries: rows.map { row in
                PlotCorpusEntry(
                    corpusId: row.corpusId,
                    displayName: row.displayName,
                    filePath: row.filePath,
                    content: ""
                )
            },
            query: query,
            searchOptions: searchOptions,
            scope: scope
        ),
        totalHits: rows.reduce(0) { $0 + $1.frequency },
        totalFilesWithHits: rows.reduce(0) { partial, row in
            partial + (row.frequency > 0 ? 1 : 0)
        },
        totalFiles: rows.count,
        rows: rows
    )
}

func makeClusterResult(rowCount: Int = 3) -> ClusterResult {
    ClusterResult(
        mode: .targetReference,
        targetDocumentCount: 1,
        referenceDocumentCount: 1,
        targetTokenCount: 100,
        referenceTokenCount: 80,
        rows: (0..<rowCount).map { index in
            ClusterRow(
                phrase: "cluster-\(index)",
                n: 3,
                frequency: rowCount - index,
                normalizedFrequency: Double(rowCount - index) * 10,
                range: 1,
                rangePercentage: 100,
                referenceFrequency: max(0, rowCount - index - 1),
                referenceNormalizedFrequency: Double(max(0, rowCount - index - 1)) * 8,
                referenceRange: 1,
                logRatio: Double(index) / 10
            )
        }
    )
}

func makeKWICResult(rowCount: Int = 3) -> KWICResult {
    let rows: [[String: Any]] = (0..<rowCount).map { index in
        [
            "sentenceId": rowCount - index,
            "sentenceTokenIndex": index,
            "left": "left-\(index)",
            "node": "node-\(index)",
            "right": "right-\(index)"
        ]
    }
    return KWICResult(json: ["rows": rows])
}

func makeCollocateResult(rowCount: Int = 3) -> CollocateResult {
    let rows: [[String: Any]] = (0..<rowCount).map { index in
        let row: [String: Any] = [
            "word": "collocate-\(index)",
            "total": rowCount - index,
            "left": index,
            "right": rowCount - index,
            "wordFreq": 10 + index,
            "keywordFreq": 20,
            "rate": Double(rowCount - index) / 10.0,
            "logDice": 8.0 + Double(rowCount - index),
            "mutualInformation": 2.0 + Double(index) / 10.0,
            "tScore": 4.0 + Double(rowCount - index) / 10.0
        ]
        return row
    }
    return CollocateResult(items: rows)
}

func makeCompareResult() -> CompareResult {
    CompareResult(json: [
        "corpora": [
            [
                "corpusId": "corpus-1",
                "corpusName": "Demo Corpus",
                "folderName": "Default",
                "tokenCount": 100,
                "typeCount": 50,
                "ttr": 0.5,
                "sttr": 0.45,
                "topWord": "alpha",
                "topWordCount": 10
            ],
            [
                "corpusId": "corpus-2",
                "corpusName": "Compare Corpus",
                "folderName": "Default",
                "tokenCount": 120,
                "typeCount": 60,
                "ttr": 0.5,
                "sttr": 0.43,
                "topWord": "beta",
                "topWordCount": 12
            ]
        ],
        "rows": [
            [
                "word": "alpha",
                "total": 18,
                "spread": 2,
                "range": 3.2,
                "dominantCorpusName": "Demo Corpus",
                "keyness": 4.21,
                "effectSize": 0.58,
                "pValue": 0.04,
                "referenceNormFreq": 666.7,
                "perCorpus": [
                    ["corpusId": "corpus-1", "corpusName": "Demo Corpus", "folderName": "Default", "count": 10, "tokenCount": 100, "normFreq": 1000.0],
                    ["corpusId": "corpus-2", "corpusName": "Compare Corpus", "folderName": "Default", "count": 8, "tokenCount": 120, "normFreq": 666.7]
                ]
            ],
            [
                "word": "beta",
                "total": 14,
                "spread": 2,
                "range": 2.1,
                "dominantCorpusName": "Compare Corpus",
                "keyness": 3.11,
                "effectSize": 0.44,
                "pValue": 0.08,
                "referenceNormFreq": 500.0,
                "perCorpus": [
                    ["corpusId": "corpus-1", "corpusName": "Demo Corpus", "folderName": "Default", "count": 5, "tokenCount": 100, "normFreq": 500.0],
                    ["corpusId": "corpus-2", "corpusName": "Compare Corpus", "folderName": "Default", "count": 9, "tokenCount": 120, "normFreq": 750.0]
                ]
            ]
        ]
    ])
}

func makeSentimentResult() -> SentimentRunResult {
    let request = SentimentRunRequest(
        source: .openedCorpus,
        unit: .sentence,
        contextBasis: .visibleContext,
        thresholds: .default,
        texts: [
            SentimentInputText(
                id: "corpus-1",
                sourceID: "corpus-1",
                sourceTitle: "Demo Corpus",
                text: "This is good. This is bad."
            )
        ],
        backend: .lexicon
    )
    let rows = [
        SentimentRowResult(
            id: "sentiment-positive",
            sourceID: "corpus-1",
            sourceTitle: "Demo Corpus",
            groupID: "target",
            groupTitle: "Target",
            text: "This is good.",
            positivityScore: 0.63,
            negativityScore: 0.07,
            neutralityScore: 0.30,
            finalLabel: .positive,
            netScore: 1.15,
            evidence: [
                SentimentEvidenceHit(
                    id: "good-hit",
                    surface: "good",
                    lemma: "good",
                    baseScore: 1.4,
                    adjustedScore: 1.4,
                    ruleTags: ["lexicon"],
                    tokenIndex: 2,
                    tokenLength: 1
                )
            ],
            evidenceCount: 1,
            mixedEvidence: false,
            diagnostics: .empty,
            sentenceID: 0,
            tokenIndex: 2
        ),
        SentimentRowResult(
            id: "sentiment-negative",
            sourceID: "corpus-1",
            sourceTitle: "Demo Corpus",
            groupID: "target",
            groupTitle: "Target",
            text: "This is bad.",
            positivityScore: 0.08,
            negativityScore: 0.61,
            neutralityScore: 0.31,
            finalLabel: .negative,
            netScore: -1.10,
            evidence: [
                SentimentEvidenceHit(
                    id: "bad-hit",
                    surface: "bad",
                    lemma: "bad",
                    baseScore: -1.4,
                    adjustedScore: -1.4,
                    ruleTags: ["lexicon"],
                    tokenIndex: 2,
                    tokenLength: 1
                )
            ],
            evidenceCount: 1,
            mixedEvidence: false,
            diagnostics: .empty,
            sentenceID: 1,
            tokenIndex: 2
        )
    ]
    let summary = SentimentAggregateSummary(
        id: "overall",
        title: "Overall",
        totalTexts: 2,
        positiveCount: 1,
        neutralCount: 0,
        negativeCount: 1,
        positiveRatio: 0.5,
        neutralRatio: 0.0,
        negativeRatio: 0.5,
        averagePositivity: 0.355,
        averageNeutrality: 0.305,
        averageNegativity: 0.34,
        averageNetScore: 0.025
    )
    return SentimentRunResult(
        request: request,
        backendKind: .lexicon,
        backendRevision: "lexicon-rules-v3",
        resourceRevision: "sentiment-pack-test-v1",
        supportsEvidenceHits: true,
        rows: rows,
        overallSummary: summary,
        groupSummaries: [
            SentimentAggregateSummary(
                id: "target",
                title: "Target",
                totalTexts: 2,
                positiveCount: 1,
                neutralCount: 0,
                negativeCount: 1,
                positiveRatio: 0.5,
                neutralRatio: 0.0,
                negativeRatio: 0.5,
                averagePositivity: 0.355,
                averageNeutrality: 0.305,
                averageNegativity: 0.34,
                averageNetScore: 0.025
            )
        ],
        lexiconVersion: "test-v1"
    )
}

func makeSentimentReviewSample(
    result: SentimentRunResult = makeSentimentResult(),
    rowID: String = "sentiment-negative",
    decision: SentimentReviewDecision = .overridePositive,
    note: String? = "Reviewed in tests",
    timestamp: String = "2026-04-18T12:00:00Z"
) -> SentimentReviewSample {
    let row = result.rows.first(where: { $0.id == rowID }) ?? result.rows[0]
    return SentimentReviewOverlaySupport.makeReviewSample(
        decision: decision,
        row: row,
        result: result,
        note: note,
        timestamp: timestamp
    )
}

func makeSentimentPresentationResult(
    result: SentimentRunResult = makeSentimentResult(),
    reviewSamples: [SentimentReviewSample] = []
) -> SentimentPresentationResult {
    SentimentReviewOverlaySupport.makePresentationResult(
        rawResult: result,
        reviewSamples: reviewSamples
    )
}

func makeCompareSentimentResult(focusTerm: String = "alpha") -> SentimentRunResult {
    let request = SentimentRunRequest(
        source: .corpusCompare,
        unit: .sentence,
        contextBasis: .fullSentenceWhenAvailable,
        thresholds: .default,
        texts: [
            SentimentInputText(
                id: "target::corpus-1",
                sourceID: "corpus-1",
                sourceTitle: "Demo Corpus",
                text: "\(focusTerm) is good.",
                groupID: "target",
                groupTitle: "Target"
            ),
            SentimentInputText(
                id: "reference::corpus-2",
                sourceID: "corpus-2",
                sourceTitle: "Compare Corpus",
                text: "\(focusTerm) is bad.",
                groupID: "reference",
                groupTitle: "Reference"
            )
        ],
        backend: .lexicon
    )

    let rows = [
        SentimentRowResult(
            id: "target::corpus-1::sentence::0",
            sourceID: "corpus-1",
            sourceTitle: "Demo Corpus",
            groupID: "target",
            groupTitle: "Target",
            text: "\(focusTerm) is good.",
            positivityScore: 0.66,
            negativityScore: 0.08,
            neutralityScore: 0.26,
            finalLabel: .positive,
            netScore: 1.10,
            evidence: [],
            evidenceCount: 0,
            mixedEvidence: false,
            diagnostics: .empty,
            sentenceID: 0,
            tokenIndex: 0
        ),
        SentimentRowResult(
            id: "reference::corpus-2::sentence::0",
            sourceID: "corpus-2",
            sourceTitle: "Compare Corpus",
            groupID: "reference",
            groupTitle: "Reference",
            text: "\(focusTerm) is bad.",
            positivityScore: 0.07,
            negativityScore: 0.68,
            neutralityScore: 0.25,
            finalLabel: .negative,
            netScore: -1.14,
            evidence: [],
            evidenceCount: 0,
            mixedEvidence: false,
            diagnostics: .empty,
            sentenceID: 0,
            tokenIndex: 0
        )
    ]

    return SentimentRunResult(
        request: request,
        backendKind: .lexicon,
        backendRevision: "lexicon-rules-v3",
        resourceRevision: "sentiment-pack-test-v1",
        supportsEvidenceHits: true,
        rows: rows,
        overallSummary: SentimentAggregateSummary(
            id: "overall",
            title: "Overall",
            totalTexts: 2,
            positiveCount: 1,
            neutralCount: 0,
            negativeCount: 1,
            positiveRatio: 0.5,
            neutralRatio: 0.0,
            negativeRatio: 0.5,
            averagePositivity: 0.365,
            averageNeutrality: 0.255,
            averageNegativity: 0.38,
            averageNetScore: -0.02
        ),
        groupSummaries: [
            SentimentAggregateSummary(
                id: "target",
                title: "Target",
                totalTexts: 1,
                positiveCount: 1,
                neutralCount: 0,
                negativeCount: 0,
                positiveRatio: 1.0,
                neutralRatio: 0.0,
                negativeRatio: 0.0,
                averagePositivity: 0.66,
                averageNeutrality: 0.26,
                averageNegativity: 0.08,
                averageNetScore: 1.10
            ),
            SentimentAggregateSummary(
                id: "reference",
                title: "Reference",
                totalTexts: 1,
                positiveCount: 0,
                neutralCount: 0,
                negativeCount: 1,
                positiveRatio: 0.0,
                neutralRatio: 0.0,
                negativeRatio: 1.0,
                averagePositivity: 0.07,
                averageNeutrality: 0.25,
                averageNegativity: 0.68,
                averageNetScore: -1.14
            )
        ],
        lexiconVersion: "test-v1"
    )
}

func makeKeywordResult() -> KeywordResult {
    KeywordResult(json: [
        "statistic": KeywordStatisticMethod.logLikelihood.rawValue,
        "targetCorpus": [
            "corpusId": "corpus-1",
            "corpusName": "Target Corpus",
            "folderName": "Default",
            "tokenCount": 120,
            "typeCount": 45
        ],
        "referenceCorpus": [
            "corpusId": "corpus-2",
            "corpusName": "Reference Corpus",
            "folderName": "Default",
            "tokenCount": 200,
            "typeCount": 60
        ],
        "rows": [
            [
                "word": "alpha",
                "rank": 1,
                "targetFrequency": 12,
                "referenceFrequency": 2,
                "targetNormalizedFrequency": 100_000.0,
                "referenceNormalizedFrequency": 10_000.0,
                "keynessScore": 18.42,
                "logRatio": 3.1,
                "pValue": 0.0001
            ],
            [
                "word": "beta",
                "rank": 2,
                "targetFrequency": 8,
                "referenceFrequency": 1,
                "targetNormalizedFrequency": 66_666.67,
                "referenceNormalizedFrequency": 5_000.0,
                "keynessScore": 11.08,
                "logRatio": 2.7,
                "pValue": 0.0009
            ]
        ]
    ])
}

func makeKeywordSuiteResult() -> KeywordSuiteResult {
    KeywordSuiteResult(
        configuration: KeywordSuiteConfiguration.legacy(
            targetCorpusID: "corpus-1",
            referenceCorpusID: "corpus-2",
            options: KeywordPreprocessingOptions.default
        ),
        focusSummary: KeywordSuiteScopeSummary(
            label: "Target Corpus",
            corpusCount: 1,
            corpusIDs: ["corpus-1"],
            corpusNames: ["Target Corpus"],
            tokenCount: 120,
            typeCount: 45,
            isWordList: false
        ),
        referenceSummary: KeywordSuiteScopeSummary(
            label: "Reference Corpus",
            corpusCount: 1,
            corpusIDs: ["corpus-2"],
            corpusNames: ["Reference Corpus"],
            tokenCount: 200,
            typeCount: 60,
            isWordList: false
        ),
        words: [
            KeywordSuiteRow(
                group: .words,
                item: "alpha",
                direction: .positive,
                focusFrequency: 12,
                referenceFrequency: 2,
                focusNormalizedFrequency: 100_000,
                referenceNormalizedFrequency: 10_000,
                keynessScore: 18.42,
                logRatio: 3.1,
                pValue: 0.0001,
                focusRange: 1,
                referenceRange: 1,
                example: "alpha example",
                focusExampleCorpusID: "corpus-1",
                referenceExampleCorpusID: "corpus-2"
            ),
            KeywordSuiteRow(
                group: .words,
                item: "beta",
                direction: .positive,
                focusFrequency: 8,
                referenceFrequency: 1,
                focusNormalizedFrequency: 66_666.67,
                referenceNormalizedFrequency: 5_000,
                keynessScore: 11.08,
                logRatio: 2.7,
                pValue: 0.0009,
                focusRange: 1,
                referenceRange: 1,
                example: "beta example",
                focusExampleCorpusID: "corpus-1",
                referenceExampleCorpusID: "corpus-2"
            )
        ],
        terms: [
            KeywordSuiteRow(
                group: .terms,
                item: "language model",
                direction: .positive,
                focusFrequency: 5,
                referenceFrequency: 1,
                focusNormalizedFrequency: 41_666.67,
                referenceNormalizedFrequency: 5_000,
                keynessScore: 9.4,
                logRatio: 2.2,
                pValue: 0.001,
                focusRange: 1,
                referenceRange: 1,
                example: "language model example",
                focusExampleCorpusID: "corpus-1",
                referenceExampleCorpusID: "corpus-2"
            )
        ],
        ngrams: [
            KeywordSuiteRow(
                group: .ngrams,
                item: "large language model",
                direction: .positive,
                focusFrequency: 4,
                referenceFrequency: 0,
                focusNormalizedFrequency: 33_333.33,
                referenceNormalizedFrequency: 0,
                keynessScore: 8.1,
                logRatio: 2.9,
                pValue: 0.002,
                focusRange: 1,
                referenceRange: 0,
                example: "large language model example",
                focusExampleCorpusID: "corpus-1",
                referenceExampleCorpusID: nil
            )
        ]
    )
}

func makeChiSquareResult() -> ChiSquareResult {
    ChiSquareResult(json: [
        "observed": [[12, 30], [6, 40]],
        "expected": [[8.6, 33.4], [9.4, 36.6]],
        "rowTotals": [42, 46],
        "colTotals": [18, 70],
        "total": 88,
        "chiSquare": 2.7412,
        "degreesOfFreedom": 1,
        "pValue": 0.0978,
        "significantAt05": false,
        "significantAt01": false,
        "phi": 0.1765,
        "oddsRatio": 2.6667,
        "yatesCorrection": false,
        "warnings": []
    ])
}

func makeLocatorResult(rowCount: Int = 4) -> LocatorResult {
    let rows: [[String: Any]] = (0..<rowCount).map { index in
        [
            "sentenceId": index,
            "text": "sentence-\(index)",
            "leftWords": index == 1 ? "left target" : "",
            "nodeWord": index == 1 ? "node" : "",
            "rightWords": index == 1 ? "right target" : "",
            "status": index == 1 ? "当前定位" : ""
        ]
    }
    return LocatorResult(json: [
        "sentences": rows,
        "rows": rows
    ])
}

func makeConcordanceSavedSet(
    kind: ConcordanceSavedSetKind = .kwic,
    rowCount: Int = 3
) -> ConcordanceSavedSet {
    let rows = (0..<rowCount).map { index in
        ConcordanceSavedSetRow(
            id: "row-\(index)",
            sentenceId: index,
            sentenceTokenIndex: index,
            status: kind == .locator && index == 0 ? "当前定位" : "",
            leftContext: "left-\(index)",
            keyword: kind == .locator ? "node" : "node-\(index)",
            rightContext: "right-\(index)",
            concordanceText: "left-\(index) node-\(index) right-\(index)",
            citationText: "Sentence \(index + 1): node-\(index)",
            fullSentenceText: "sentence-\(index)"
        )
    }
    return ConcordanceSavedSet(
        id: "saved-\(kind.rawValue)-\(rowCount)",
        name: kind == .kwic ? "KWIC Set" : "Locator Set",
        kind: kind,
        corpusID: "corpus-1",
        corpusName: "Demo Corpus",
        query: kind == .kwic ? "node" : "locator-node",
        sourceSentenceId: kind == .locator ? 1 : nil,
        leftWindow: 5,
        rightWindow: 5,
        searchOptions: kind == .kwic ? .default : nil,
        stopwordFilter: kind == .kwic ? .default : nil,
        createdAt: "2026-04-12T00:00:00Z",
        updatedAt: "2026-04-12T00:00:00Z",
        rows: rows
    )
}

func makeEvidenceItem(
    id: String? = nil,
    sourceKind: EvidenceSourceKind = .kwic,
    reviewStatus: EvidenceReviewStatus = .pending,
    sectionTitle: String? = nil,
    claim: String? = nil,
    tags: [String] = [],
    citationFormat: EvidenceCitationFormat = .citationLine,
    citationStyle: EvidenceCitationStyle = .plain,
    corpusMetadata: CorpusMetadataProfile? = nil,
    note: String? = nil
) -> EvidenceItem {
    let savedSetID: String?
    let savedSetName: String?
    let keyword: String
    let query: String
    let searchOptionsSnapshot: SearchOptionsState?
    let stopwordFilterSnapshot: StopwordFilterState?

    switch sourceKind {
    case .kwic:
        savedSetID = "saved-kwic-3"
        savedSetName = "KWIC Set"
        keyword = "node"
        query = "node"
        searchOptionsSnapshot = .default
        stopwordFilterSnapshot = .default
    case .locator:
        savedSetID = nil
        savedSetName = nil
        keyword = "locator-node"
        query = "locator-node"
        searchOptionsSnapshot = nil
        stopwordFilterSnapshot = nil
    case .plot:
        savedSetID = nil
        savedSetName = nil
        keyword = "plot-hit"
        query = "plot-hit"
        searchOptionsSnapshot = nil
        stopwordFilterSnapshot = nil
    case .sentiment:
        savedSetID = nil
        savedSetName = nil
        keyword = "sentiment-hit"
        query = "sentiment-hit"
        searchOptionsSnapshot = nil
        stopwordFilterSnapshot = nil
    case .topics:
        savedSetID = nil
        savedSetName = nil
        keyword = "topic-hit"
        query = "topic-hit"
        searchOptionsSnapshot = nil
        stopwordFilterSnapshot = nil
    }

    return EvidenceItem(
        id: id ?? "evidence-\(sourceKind.rawValue)-\(reviewStatus.rawValue)",
        sourceKind: sourceKind,
        savedSetID: savedSetID,
        savedSetName: savedSetName,
        corpusID: "corpus-1",
        corpusName: "Demo Corpus",
        corpusMetadata: corpusMetadata,
        sentenceId: 2,
        sentenceTokenIndex: 3,
        leftContext: "left context",
        keyword: keyword,
        rightContext: "right context",
        fullSentenceText: "left context node right context",
        citationText: "Sentence 3: left context node right context",
        citationFormat: citationFormat,
        citationStyle: citationStyle,
        query: query,
        leftWindow: 5,
        rightWindow: 5,
        searchOptionsSnapshot: searchOptionsSnapshot,
        stopwordFilterSnapshot: stopwordFilterSnapshot,
        reviewStatus: reviewStatus,
        sectionTitle: sectionTitle,
        claim: claim,
        tags: tags,
        note: note,
        createdAt: "2026-04-13T00:00:00Z",
        updatedAt: "2026-04-13T00:00:00Z"
    )
}

func makeRecycleSnapshot() -> RecycleBinSnapshot {
    RecycleBinSnapshot(json: [
        "entries": [[
            "recycleEntryId": "recycle-1",
            "type": "corpus",
            "deletedAt": "today",
            "name": "Deleted Corpus",
            "originalFolderName": "Default",
            "sourceType": "txt",
            "itemCount": 1
        ]],
        "folderCount": 0,
        "corpusCount": 1,
        "totalCount": 1
    ])
}

func makeLibraryBackupSummary() -> LibraryBackupSummary {
    LibraryBackupSummary(json: [
        "backupDir": "/tmp/wordz-backup",
        "folderCount": 1,
        "corpusCount": 2,
        "librarySchemaVersion": 2,
        "workspaceSchemaVersion": 1,
        "pendingShardMigrationCount": 0,
        "quarantinedCorpusCount": 0,
        "corpusSetCount": 1,
        "recycleEntryCount": 0
    ])
}

func makeLibraryRestoreSummary() -> LibraryRestoreSummary {
    LibraryRestoreSummary(json: [
        "restoredFromDir": "/tmp/wordz-backup",
        "previousLibraryBackupDir": "/tmp/wordz-prev",
        "folderCount": 1,
        "corpusCount": 2,
        "librarySchemaVersion": 2,
        "workspaceSchemaVersion": 1,
        "pendingShardMigrationCount": 0,
        "quarantinedCorpusCount": 0,
        "corpusSetCount": 1,
        "recycleEntryCount": 0
    ])
}

func makeLibraryRepairSummary() -> LibraryRepairSummary {
    LibraryRepairSummary(json: [
        "summary": [
            "repairedManifest": true,
            "repairedFolders": 1,
            "repairedCorpora": 1,
            "recoveredCorpusMeta": 0,
            "quarantinedFolders": 0,
            "quarantinedCorpora": 0,
            "checkedFolders": 1,
            "checkedCorpora": 2
        ],
        "quarantineDir": "/tmp/wordz-quarantine"
    ])
}
