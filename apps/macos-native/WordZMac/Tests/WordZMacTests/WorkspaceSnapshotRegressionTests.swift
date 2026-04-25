import Foundation
import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class WorkspaceSnapshotRegressionTests: XCTestCase {
    func testApplyAnalysisPresetRestoresWorkspaceAnnotationState() async {
        let repository = FakeWorkspaceRepository()
        repository.analysisPresetItems = [
            AnalysisPresetItem(
                id: "preset-annotation",
                name: "Lemma Keyword",
                createdAt: "today",
                updatedAt: "today",
                snapshot: WorkspaceSnapshotSummary(
                    draft: WorkspaceStateDraft(
                        currentTab: WorkspaceDetailTab.keyword.snapshotValue,
                        currentLibraryFolderId: "all",
                        selectedCorpusSetID: "",
                        corpusIds: ["corpus-1"],
                        corpusNames: ["Demo Corpus"],
                        searchQuery: "alpha",
                        searchOptions: .default,
                        stopwordFilter: .default,
                        annotationProfile: .lemmaPreferred,
                        annotationLexicalClasses: [.noun],
                        annotationScripts: [.latin],
                        ngramSize: "2",
                        ngramPageSize: "10",
                        kwicLeftWindow: "5",
                        kwicRightWindow: "5",
                        collocateLeftWindow: "5",
                        collocateRightWindow: "5",
                        collocateMinFreq: "1",
                        topicsMinTopicSize: "2",
                        topicsIncludeOutliers: true,
                        topicsPageSize: "50",
                        topicsActiveTopicID: "",
                        chiSquareA: "",
                        chiSquareB: "",
                        chiSquareC: "",
                        chiSquareD: "",
                        chiSquareUseYates: false
                    )
                )
            )
        ]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        await workspace.applyAnalysisPreset("preset-annotation")
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(workspace.annotationState.profile, .lemmaPreferred)
        XCTAssertEqual(workspace.annotationState.lexicalClasses, [.noun])
        XCTAssertEqual(workspace.annotationState.scripts, [.latin])
        XCTAssertEqual(workspace.tokenize.annotationProfile, .lemmaPreferred)
        XCTAssertEqual(workspace.keyword.selectedLexicalClasses, [.noun])
        XCTAssertEqual(workspace.keyword.selectedScripts, [.latin])
        XCTAssertEqual(repository.savedWorkspaceDrafts.last?.annotationProfile, .lemmaPreferred)
    }

    func testSaveCompareCorpusSetPersistsCompareParticipantsAndRecentSetWithoutChangingSidebarScope() async {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "Compare Scope"
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.compare.selectedCorpusIDs = ["corpus-1"]
        workspace.compare.selectedReferenceSelection = .corpus("corpus-2")
        let selectedCorpusBeforeSave = workspace.sidebar.selectedCorpusID
        let selectedCorpusSetBeforeSave = workspace.sidebar.selectedCorpusSetID

        await workspace.saveCompareCorpusSet(preferredWindowRoute: .mainWorkspace)

        XCTAssertEqual(repository.saveCorpusSetCallCount, 1)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .mainWorkspace)
        XCTAssertEqual(repository.librarySnapshot.corpusSets.last?.name, "Compare Scope")
        XCTAssertEqual(repository.librarySnapshot.corpusSets.last?.corpusIDs, ["corpus-1", "corpus-2"])
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, selectedCorpusBeforeSave)
        XCTAssertEqual(workspace.sidebar.selectedCorpusSetID, selectedCorpusSetBeforeSave)
        XCTAssertEqual(workspace.settings.exportSnapshot().recentCorpusSetIDs, ["set-1"])
        XCTAssertEqual(workspace.library.scene.recentCorpusSets.map(\.id), ["set-1"])
    }

    func testSaveKWICCorpusSetPersistsCurrentCorpusScope() async {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "KWIC Scope"
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "node"
        workspace.kwic.apply(makeKWICResult(rowCount: 3))

        await workspace.saveKWICCorpusSet(preferredWindowRoute: .mainWorkspace)

        XCTAssertEqual(repository.saveCorpusSetCallCount, 1)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .mainWorkspace)
        XCTAssertEqual(repository.librarySnapshot.corpusSets.last?.name, "KWIC Scope")
        XCTAssertEqual(repository.librarySnapshot.corpusSets.last?.corpusIDs, ["corpus-1"])
        XCTAssertEqual(workspace.settings.exportSnapshot().recentCorpusSetIDs, ["set-1"])
    }

    func testSaveLocatorCorpusSetPersistsCurrentCorpusScope() async {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "Locator Scope"
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        let source = LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 2)
        workspace.locator.apply(makeLocatorResult(rowCount: 3), source: source)

        await workspace.saveLocatorCorpusSet(preferredWindowRoute: .mainWorkspace)

        XCTAssertEqual(repository.saveCorpusSetCallCount, 1)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .mainWorkspace)
        XCTAssertEqual(repository.librarySnapshot.corpusSets.last?.name, "Locator Scope")
        XCTAssertEqual(repository.librarySnapshot.corpusSets.last?.corpusIDs, ["corpus-1"])
    }

    func testSaveKWICCurrentHitSetPersistsSelectedRowAndRefreshesSavedSets() async {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "KWIC Current Set"
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "node"
        workspace.kwic.apply(makeKWICResult(rowCount: 3))
        workspace.kwic.selectedRowID = "2-1"

        await workspace.saveKWICCurrentHitSet(preferredWindowRoute: .mainWorkspace)

        XCTAssertEqual(repository.saveConcordanceSavedSetCallCount, 1)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .mainWorkspace)
        XCTAssertEqual(repository.concordanceSavedSets.first?.name, "KWIC Current Set")
        XCTAssertEqual(repository.concordanceSavedSets.first?.kind, .kwic)
        XCTAssertEqual(repository.concordanceSavedSets.first?.rows.map(\.id), ["2-1"])
        XCTAssertEqual(workspace.kwic.savedSets.first?.name, "KWIC Current Set")
        XCTAssertEqual(workspace.kwic.selectedSavedSet?.rows.count, 1)
    }

    func testSaveLocatorVisibleHitSetPersistsVisibleRowsAndRefreshesSavedSets() async {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "Locator Visible Set"
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        let source = LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 2)
        workspace.locator.apply(makeLocatorResult(rowCount: 3), source: source)

        await workspace.saveLocatorVisibleHitSet(preferredWindowRoute: .mainWorkspace)

        XCTAssertEqual(repository.saveConcordanceSavedSetCallCount, 1)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .mainWorkspace)
        XCTAssertEqual(repository.concordanceSavedSets.first?.name, "Locator Visible Set")
        XCTAssertEqual(repository.concordanceSavedSets.first?.kind, .locator)
        XCTAssertEqual(repository.concordanceSavedSets.first?.rows.count, 3)
        XCTAssertEqual(repository.concordanceSavedSets.first?.sourceSentenceId, 1)
        XCTAssertEqual(workspace.locator.savedSets.first?.rows.count, 3)
    }

    func testExportSelectedKWICSavedSetJSONWritesTransferBundle() async throws {
        let dialogService = FakeDialogService()
        let exportURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("kwic-hit-set-export-\(UUID().uuidString).json")
        dialogService.savePathResult = exportURL.path
        defer { try? FileManager.default.removeItem(at: exportURL) }

        let savedSet = makeConcordanceSavedSet(kind: .kwic, rowCount: 2)
        let repository = FakeWorkspaceRepository()
        repository.concordanceSavedSets = [savedSet]
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.kwic.selectedSavedSetID = savedSet.id

        await workspace.exportSelectedKWICSavedSetJSON(preferredWindowRoute: .mainWorkspace)

        let data = try Data(contentsOf: exportURL)
        let bundle = try JSONDecoder().decode(ConcordanceSavedSetTransferBundle.self, from: data)

        XCTAssertEqual(dialogService.savePathPreferredRoute, .mainWorkspace)
        XCTAssertEqual(bundle.version, 1)
        XCTAssertEqual(bundle.sets.map(\.name), ["KWIC Set"])
        XCTAssertEqual(bundle.sets.first?.rows.count, 2)
    }

    func testImportConcordanceSavedSetsJSONMergesSetsWithoutOverwritingExistingNamesOrIDs() async throws {
        let dialogService = FakeDialogService()
        let importURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("concordance-hit-set-import-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: importURL) }

        let existingSet = makeConcordanceSavedSet(kind: .kwic, rowCount: 2)
        let importedSet = ConcordanceSavedSet(
            id: existingSet.id,
            name: existingSet.name,
            kind: .kwic,
            corpusID: existingSet.corpusID,
            corpusName: existingSet.corpusName,
            query: "imported-node",
            sourceSentenceId: nil,
            leftWindow: 3,
            rightWindow: 7,
            searchOptions: .default,
            stopwordFilter: .default,
            createdAt: "2026-04-12T06:00:00Z",
            updatedAt: "2026-04-12T06:00:00Z",
            rows: [ConcordanceSavedSetRow(
                id: "imported-row",
                sentenceId: 7,
                sentenceTokenIndex: 2,
                status: "",
                leftContext: "import-left",
                keyword: "imported-node",
                rightContext: "import-right",
                concordanceText: "import-left imported-node import-right",
                citationText: "Sentence 8: imported-node",
                fullSentenceText: "import sentence"
            )]
        )
        let payload = try ConcordanceSavedSetTransferSupport.exportData(sets: [importedSet])
        try payload.write(to: importURL, options: .atomic)
        dialogService.openPathResult = importURL.path

        let repository = FakeWorkspaceRepository()
        repository.concordanceSavedSets = [existingSet]
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        await workspace.importConcordanceSavedSetsJSON(preferredWindowRoute: .mainWorkspace)

        XCTAssertEqual(dialogService.openPathPreferredRoute, .mainWorkspace)
        XCTAssertEqual(repository.concordanceSavedSets.count, 2)
        XCTAssertEqual(Set(repository.concordanceSavedSets.map(\.id)).count, 2)
        XCTAssertEqual(Set(repository.concordanceSavedSets.map(\.name)).count, 2)
        XCTAssertEqual(workspace.kwic.savedSets.count, 2)
    }

    func testLoadSelectedKWICSavedSetRehydratesLiveResultWithoutRunningEngine() async {
        let repository = FakeWorkspaceRepository()
        let savedSet = makeConcordanceSavedSet(kind: .kwic, rowCount: 2)
        repository.concordanceSavedSets = [savedSet]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.selectedTab = .stats
        workspace.kwic.selectedSavedSetID = savedSet.id

        await workspace.loadSelectedKWICSavedSet()

        XCTAssertEqual(repository.runKWICCallCount, 0)
        XCTAssertEqual(workspace.selectedTab, .kwic)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .kwic)
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, savedSet.corpusID)
        XCTAssertEqual(workspace.kwic.keyword, savedSet.query)
        XCTAssertEqual(workspace.kwic.result?.rows.count, savedSet.rows.count)
        XCTAssertEqual(workspace.kwic.selectedSavedSetID, savedSet.id)
        XCTAssertEqual(workspace.locator.currentSource?.sentenceId, savedSet.rows.first?.sentenceId)
        XCTAssertEqual(workspace.locator.currentSource?.nodeIndex, savedSet.rows.first?.sentenceTokenIndex)
    }

    func testLoadSelectedLocatorSavedSetRehydratesLiveResultWithoutRunningEngine() async {
        let repository = FakeWorkspaceRepository()
        let savedSet = makeConcordanceSavedSet(kind: .locator, rowCount: 3)
        repository.concordanceSavedSets = [savedSet]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.selectedTab = .stats
        workspace.locator.selectedSavedSetID = savedSet.id

        await workspace.loadSelectedLocatorSavedSet()

        XCTAssertEqual(repository.runLocatorCallCount, 0)
        XCTAssertEqual(workspace.selectedTab, .locator)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .locator)
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, savedSet.corpusID)
        XCTAssertEqual(workspace.locator.result?.rows.count, savedSet.rows.count)
        XCTAssertEqual(workspace.locator.currentSource?.sentenceId, savedSet.sourceSentenceId)
        XCTAssertEqual(workspace.locator.currentSource?.keyword, savedSet.query)
        XCTAssertEqual(workspace.locator.selectedSavedSetID, savedSet.id)
    }

    func testSaveRefinedKWICSavedSetPersistsFilteredSubset() async {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "KWIC Set · 精炼"
        let savedSet = makeConcordanceSavedSet(kind: .kwic, rowCount: 3)
        repository.concordanceSavedSets = [savedSet]
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.kwic.selectedSavedSetID = savedSet.id
        workspace.kwic.savedSetFilterQuery = "node-1"
        workspace.kwic.savedSetNotesDraft = "teaching note"

        await workspace.saveRefinedKWICSavedSet(preferredWindowRoute: .mainWorkspace)

        XCTAssertEqual(dialogService.promptTextPreferredRoute, .mainWorkspace)
        XCTAssertEqual(repository.concordanceSavedSets.count, 2)
        XCTAssertEqual(repository.concordanceSavedSets.first?.name, "KWIC Set · 精炼")
        XCTAssertEqual(repository.concordanceSavedSets.first?.rows.map(\.id), ["row-1"])
        XCTAssertEqual(repository.concordanceSavedSets.first?.notes, "teaching note")
    }

    func testSaveSelectedLocatorSavedSetNotesPersistsUpdatedNotes() async {
        let repository = FakeWorkspaceRepository()
        var savedSet = makeConcordanceSavedSet(kind: .locator, rowCount: 2)
        savedSet.notes = "old"
        repository.concordanceSavedSets = [savedSet]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.locator.selectedSavedSetID = savedSet.id
        workspace.locator.savedSetNotesDraft = "updated notes"

        await workspace.saveSelectedLocatorSavedSetNotes()

        XCTAssertEqual(repository.concordanceSavedSets.first?.id, savedSet.id)
        XCTAssertEqual(repository.concordanceSavedSets.first?.notes, "updated notes")
        XCTAssertEqual(workspace.locator.savedSets.first?.notes, "updated notes")
    }

    func testLoadSelectedKWICSavedSetUsesFilteredSubsetWhenRefinementQueryIsActive() async {
        let repository = FakeWorkspaceRepository()
        let savedSet = makeConcordanceSavedSet(kind: .kwic, rowCount: 3)
        repository.concordanceSavedSets = [savedSet]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.kwic.selectedSavedSetID = savedSet.id
        workspace.kwic.savedSetFilterQuery = "node-2"

        await workspace.loadSelectedKWICSavedSet()

        XCTAssertEqual(repository.runKWICCallCount, 0)
        XCTAssertEqual(workspace.kwic.result?.rows.map(\.id), ["row-2"])
    }

    func testCaptureCurrentKWICEvidenceItemPersistsSavedSetProvenance() async {
        let repository = FakeWorkspaceRepository()
        let savedSet = makeConcordanceSavedSet(kind: .kwic, rowCount: 3)
        repository.concordanceSavedSets = [savedSet]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.kwic.selectedSavedSetID = savedSet.id
        await workspace.loadSelectedKWICSavedSet()
        workspace.kwic.selectedRowID = "row-1"

        await workspace.captureCurrentKWICEvidenceItem()

        XCTAssertEqual(repository.evidenceItems.count, 1)
        XCTAssertEqual(repository.evidenceItems.first?.sourceKind, .kwic)
        XCTAssertEqual(repository.evidenceItems.first?.savedSetID, savedSet.id)
        XCTAssertEqual(repository.evidenceItems.first?.savedSetName, savedSet.name)
        XCTAssertEqual(repository.evidenceItems.first?.fullSentenceText, "sentence-1")
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItem?.savedSetID, savedSet.id)
    }

    func testRestoreSavedWorkspaceReappliesSavedQueryState() async {
        let repository = FakeWorkspaceRepository(
            bootstrapState: makeBootstrapState(
                workspaceSnapshot: makeWorkspaceSnapshot(
                    currentTab: "chi-square",
                    searchQuery: "cloud-1*",
                    topicsMinTopicSize: "4",
                    topicsKeywordDisplayCount: "8",
                    topicsIncludeOutliers: false,
                    topicsPageSize: "25",
                    topicsActiveTopicID: "topic-2",
                    chiSquareA: "10",
                    chiSquareB: "20",
                    chiSquareC: "6",
                    chiSquareD: "14",
                    chiSquareUseYates: true
                )
            )
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = ""
        workspace.word.query = ""
        workspace.topics.minTopicSize = "2"
        workspace.topics.keywordDisplayCount = "5"
        workspace.chiSquare.a = ""

        await workspace.restoreSavedWorkspace()

        XCTAssertEqual(workspace.selectedTab, .chiSquare)
        XCTAssertEqual(workspace.word.query, "cloud-1*")
        XCTAssertEqual(workspace.topics.minTopicSize, "4")
        XCTAssertEqual(workspace.topics.keywordDisplayCount, "8")
        XCTAssertFalse(workspace.topics.includeOutliers)
        XCTAssertEqual(workspace.chiSquare.a, "10")
        XCTAssertEqual(workspace.chiSquare.d, "14")
        XCTAssertTrue(workspace.chiSquare.useYates)
    }

    func testSaveCurrentAnalysisPresetPersistsAndReloadsPresetList() async {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "Compare Focus"
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.selectedTab = .compare
        workspace.compare.query = "rose"
        await workspace.saveCurrentAnalysisPreset(preferredWindowRoute: .mainWorkspace)

        XCTAssertEqual(repository.saveAnalysisPresetCallCount, 1)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .mainWorkspace)
        XCTAssertEqual(workspace.analysisPresets.first?.name, "Compare Focus")
        XCTAssertEqual(workspace.analysisPresets.first?.activeTab, .compare)
        XCTAssertEqual(workspace.settings.scene.supportStatus, "已保存分析预设：Compare Focus")
    }

    func testDeleteAnalysisPresetForwardsPreferredRouteToConfirmDialog() async {
        let repository = FakeWorkspaceRepository()
        repository.analysisPresetItems = [
            AnalysisPresetItem(
                id: "preset-1",
                name: "Compare Focus",
                createdAt: "today",
                updatedAt: "today",
                snapshot: WorkspaceSnapshotSummary(draft: .empty)
            )
        ]
        let dialogService = FakeDialogService()
        dialogService.confirmResult = true
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        await workspace.deleteAnalysisPreset("preset-1", preferredWindowRoute: .mainWorkspace)

        XCTAssertEqual(dialogService.confirmPreferredRoute, .mainWorkspace)
        XCTAssertEqual(repository.deleteAnalysisPresetCallCount, 1)
    }

    func testApplyAnalysisPresetRebuildsWorkspaceInputsAndPersistsDraft() async {
        let repository = FakeWorkspaceRepository()
        repository.analysisPresetItems = [
            AnalysisPresetItem(
                id: "preset-1",
                name: "Topic Drilldown",
                createdAt: "today",
                updatedAt: "today",
                snapshot: WorkspaceSnapshotSummary(
                    draft: WorkspaceStateDraft(
                        currentTab: WorkspaceDetailTab.topics.snapshotValue,
                        currentLibraryFolderId: "all",
                        selectedCorpusSetID: "",
                        corpusIds: ["corpus-1"],
                        corpusNames: ["Demo Corpus"],
                        searchQuery: "climate",
                        searchOptions: .default,
                        stopwordFilter: .default,
                        ngramSize: "2",
                        ngramPageSize: "10",
                        kwicLeftWindow: "5",
                        kwicRightWindow: "5",
                        collocateLeftWindow: "5",
                        collocateRightWindow: "5",
                        collocateMinFreq: "1",
                        topicsMinTopicSize: "6",
                        topicsKeywordDisplayCount: "9",
                        topicsIncludeOutliers: false,
                        topicsPageSize: "25",
                        topicsActiveTopicID: "topic-1",
                        chiSquareA: "",
                        chiSquareB: "",
                        chiSquareC: "",
                        chiSquareD: "",
                        chiSquareUseYates: false
                    )
                )
            )
        ]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        await workspace.applyAnalysisPreset("preset-1")
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(workspace.selectedTab, .topics)
        XCTAssertEqual(workspace.topics.minTopicSize, "6")
        XCTAssertEqual(workspace.topics.keywordDisplayCount, "9")
        XCTAssertFalse(workspace.topics.includeOutliers)
        XCTAssertEqual(workspace.topics.query, "climate")
        XCTAssertEqual(repository.savedWorkspaceDrafts.last?.currentTab, WorkspaceDetailTab.topics.snapshotValue)
    }

    func testResearchWorkflowComputedStateReflectsPresetAndBundleAvailability() async {
        let repository = FakeWorkspaceRepository()
        repository.analysisPresetItems = [
            AnalysisPresetItem(
                id: "preset-1",
                name: "KWIC Citation",
                createdAt: "2026-04-08T00:00:00Z",
                updatedAt: "2026-04-08T00:00:00Z",
                snapshot: WorkspaceSnapshotSummary(
                    draft: WorkspaceStateDraft(
                        currentTab: WorkspaceDetailTab.kwic.snapshotValue,
                        currentLibraryFolderId: "all",
                        selectedCorpusSetID: "",
                        corpusIds: ["corpus-1"],
                        corpusNames: ["Demo Corpus"],
                        searchQuery: "rose",
                        searchOptions: .default,
                        stopwordFilter: .default,
                        ngramSize: "2",
                        ngramPageSize: "10",
                        kwicLeftWindow: "5",
                        kwicRightWindow: "5",
                        collocateLeftWindow: "5",
                        collocateRightWindow: "5",
                        collocateMinFreq: "1",
                        topicsMinTopicSize: "4",
                        topicsIncludeOutliers: true,
                        topicsPageSize: "20",
                        topicsActiveTopicID: "",
                        chiSquareA: "",
                        chiSquareB: "",
                        chiSquareC: "",
                        chiSquareD: "",
                        chiSquareUseYates: false
                    )
                )
            )
        ]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "rose"
        await workspace.runKWIC()

        XCTAssertEqual(workspace.analysisPresets.first?.name, "KWIC Citation")
        XCTAssertTrue(workspace.canExportCurrentReportBundle)
    }

    func testSaveCurrentAnalysisPresetCapturesAnnotationStateAndTopicControls() async throws {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "Topic Annotation Drilldown"
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.selectedTab = .topics
        workspace.topics.query = "climate"
        workspace.topics.minTopicSize = "6"
        workspace.topics.keywordDisplayCount = "9"
        workspace.topics.includeOutliers = false
        workspace.setAnnotationProfile(.lemmaPreferred)
        workspace.toggleAnnotationScript(.latin)
        workspace.toggleAnnotationLexicalClass(.noun)

        await workspace.saveCurrentAnalysisPreset(preferredWindowRoute: .mainWorkspace)

        let savedPreset = try XCTUnwrap(repository.analysisPresetItems.first)
        XCTAssertEqual(savedPreset.name, "Topic Annotation Drilldown")
        XCTAssertEqual(savedPreset.snapshot.currentTab, WorkspaceDetailTab.topics.snapshotValue)
        XCTAssertEqual(savedPreset.snapshot.searchQuery, "climate")
        XCTAssertEqual(savedPreset.snapshot.topicsMinTopicSize, "6")
        XCTAssertEqual(savedPreset.snapshot.annotationProfile, .lemmaPreferred)
        XCTAssertEqual(savedPreset.snapshot.annotationScripts, [.latin])
        XCTAssertEqual(savedPreset.snapshot.annotationLexicalClasses, [.noun])
    }
}
