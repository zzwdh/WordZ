import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class WorkspaceActionDispatcherTests: XCTestCase {
    func testDispatcherRefreshActionRunsWorkspaceRefreshFlow() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleToolbarAction(.refresh)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.loadBootstrapStateCallCount, 1)
        XCTAssertEqual(workspace.sceneGraph.context.appName, "WordZ")
    }

    func testDispatcherStatsLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        workspace.stats.apply(makeStatsResult(rowCount: 5))
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.stats.table.isVisible("count"))

        dispatcher.handleStatsAction(.toggleColumn(.count))

        XCTAssertFalse(workspace.sceneGraph.stats.table.isVisible("count"))
    }

    func testDispatcherCompareLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        workspace.sidebar.applyBootstrap(repository.bootstrapState)
        workspace.compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.compare.apply(makeCompareResult())
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertFalse(workspace.sceneGraph.compare.table.isVisible("distribution"))

        dispatcher.handleCompareAction(.toggleColumn(.distribution))

        XCTAssertTrue(workspace.sceneGraph.compare.table.isVisible("distribution"))
    }

    func testDispatcherSentimentRunActionLaunchesWorkspaceRun() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        workspace.sentiment.handle(.changeSource(.pastedText))
        workspace.sentiment.handle(.changeManualText("This is good."))
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleSentimentAction(.run)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runSentimentCallCount, 1)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .sentiment)
        XCTAssertTrue(workspace.sceneGraph.sentiment.hasResult)
    }

    func testDispatcherSentimentLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        workspace.sentiment.apply(makeSentimentResult())
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.sentiment.table.isVisible(SentimentColumnKey.source.rawValue))

        dispatcher.handleSentimentAction(.toggleColumn(.source))

        XCTAssertFalse(workspace.sceneGraph.sentiment.table.isVisible(SentimentColumnKey.source.rawValue))
    }

    func testDispatcherSentimentImportBundleUsesPreferredRouteAndLoadsBundle() async throws {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dispatcher-sentiment-bundle-\(UUID().uuidString).json")
        let bundleJSON = """
        {
          "manifest": {
            "id": "dispatcher-pack",
            "version": "1.0"
          },
          "entries": [
            { "term": "corpus-savvy", "score": 1.2 }
          ]
        }
        """
        try bundleJSON.write(to: bundleURL, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        dialogService.openPathResult = bundleURL.path

        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )
        await workspace.initializeIfNeeded()
        let dispatcher = WorkspaceActionDispatcher(
            workspace: workspace,
            preferredWindowRoute: .mainWorkspace
        )

        dispatcher.handleSentimentAction(.importUserLexiconBundle)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(dialogService.openPathPreferredRoute, .mainWorkspace)
        XCTAssertEqual(workspace.sentiment.importedLexiconBundles.map(\.id), ["dispatcher-pack"])
        XCTAssertEqual(workspace.sentiment.selectedRuleProfile.importedBundleIDs, ["dispatcher-pack"])
    }

    func testDispatcherCompareOpenKWICActionLaunchesWorkspaceRun() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        workspace.compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.compare.selectedCorpusIDs = ["corpus-1", "corpus-2"]
        workspace.compare.apply(makeCompareResult())
        workspace.compare.selectedRowID = "alpha"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleCompareAction(.openKWIC)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runKWICCallCount, 1)
        XCTAssertEqual(workspace.kwic.keyword, "alpha")
        XCTAssertEqual(workspace.sceneGraph.activeTab, .kwic)
    }

    func testDispatcherCompareOpenSentimentActionLaunchesWorkspaceRun() async throws {
        let referenceSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "Reference Set",
            "corpusIds": ["corpus-2"],
            "corpusNames": ["Compare Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let repository = FakeWorkspaceRepository(
            bootstrapState: makeBootstrapState(corpusSets: [referenceSet]),
            sentimentResult: makeCompareSentimentResult()
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        workspace.compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.compare.selectedCorpusIDs = ["corpus-1"]
        workspace.compare.selectedReferenceSelection = .corpusSet("set-1")
        workspace.compare.apply(makeCompareResult())
        workspace.compare.selectedRowID = "alpha"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleCompareAction(.openSentiment)
        try? await Task.sleep(nanoseconds: 50_000_000)

        let request = try XCTUnwrap(repository.lastSentimentRequest)
        XCTAssertEqual(repository.runSentimentCallCount, 1)
        XCTAssertEqual(request.source, .corpusCompare)
        XCTAssertEqual(
            request.texts
                .filter { $0.groupID == "reference" }
                .compactMap(\.sourceID),
            ["corpus-2"]
        )
        XCTAssertEqual(workspace.sentiment.source, .corpusCompare)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .sentiment)
    }

    func testDispatcherCompareOpenTopicsActionLaunchesWorkspaceRun() async throws {
        let referenceSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "Reference Set",
            "corpusIds": ["corpus-2"],
            "corpusNames": ["Compare Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let repository = FakeWorkspaceRepository(
            bootstrapState: makeBootstrapState(corpusSets: [referenceSet]),
            openedCorporaByID: [
                "corpus-1": OpenedCorpus(json: [
                    "mode": "saved",
                    "filePath": "/tmp/compare-target-topics.txt",
                    "displayName": "Demo Corpus",
                    "content": "alpha target framing keeps the comparison grounded.",
                    "sourceType": "txt"
                ]),
                "corpus-2": OpenedCorpus(json: [
                    "mode": "saved",
                    "filePath": "/tmp/compare-reference-topics.txt",
                    "displayName": "Compare Corpus",
                    "content": "alpha reference framing keeps the contrast visible.",
                    "sourceType": "txt"
                ])
            ],
            topicsResult: makeCompareTopicsResult()
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        workspace.compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.compare.selectedCorpusIDs = ["corpus-1"]
        workspace.compare.selectedReferenceSelection = .corpusSet("set-1")
        workspace.compare.apply(makeCompareResult())
        workspace.compare.selectedRowID = "alpha"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleCompareAction(.openTopics)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runTopicsCallCount, 1)
        XCTAssertEqual(repository.lastRunTopicsOptions?.searchQuery, "alpha")
        XCTAssertEqual(workspace.topics.compareDrilldownContext?.focusTerm, "alpha")
        XCTAssertEqual(workspace.sceneGraph.activeTab, .topics)
        XCTAssertTrue(workspace.topics.scene?.crossAnalysisSummary?.contains("alpha") == true)
    }

    func testDispatcherCompareSaveCorpusSetActionUsesPreferredRoute() async {
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
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace, preferredWindowRoute: .mainWorkspace)

        dispatcher.handleCompareAction(.saveCorpusSet)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.saveCorpusSetCallCount, 1)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .mainWorkspace)
    }

    func testDispatcherTopicsOpenSentimentActionLaunchesWorkspaceRun() async {
        let fixture = makeTopicsDispatcherFixture()
        let repository = FakeWorkspaceRepository(
            openedCorpus: fixture.openedCorpus,
            topicsResult: fixture.topicsResult,
            sentimentResult: fixture.sentimentResult
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        workspace.topics.query = ""
        workspace.topics.apply(fixture.topicsResult)
        workspace.selectedTab = .topics
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleTopicsAction(.openSentiment(.visibleTopics))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runSentimentCallCount, 1)
        XCTAssertEqual(workspace.sentiment.source, .topicSegments)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .sentiment)
    }

    func testDispatcherTopicsOpenKWICActionLaunchesWorkspaceRun() async {
        let referenceOpenedCorpus = OpenedCorpus(json: [
            "mode": "saved",
            "filePath": "/tmp/compare-reference-topics.txt",
            "displayName": "Compare Corpus",
            "content": "alpha reference framing keeps the contrast visible.",
            "sourceType": "txt"
        ])
        let repository = FakeWorkspaceRepository(
            openedCorporaByID: [
                "corpus-2": referenceOpenedCorpus
            ],
            topicsResult: makeCompareTopicsResult()
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        workspace.topics.query = "alpha"
        workspace.topics.apply(makeCompareTopicsResult())
        workspace.topics.selectedClusterID = "topic-1"
        workspace.topics.selectedRowID = "compare-topic-reference-1"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleTopicsAction(.openKWIC)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runKWICCallCount, 1)
        XCTAssertEqual(workspace.kwic.keyword, "alpha")
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "corpus-2")
        XCTAssertEqual(workspace.sceneGraph.activeTab, .kwic)
    }

    func testDispatcherTopicsLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        workspace.topics.apply(makeTopicAnalysisResult())
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.topics.table.isVisible(TopicsColumnKey.score.rawValue))

        dispatcher.handleTopicsAction(.toggleColumn(.score))

        XCTAssertFalse(workspace.sceneGraph.topics.table.isVisible(TopicsColumnKey.score.rawValue))
    }

    func testDispatcherTokenizeLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        workspace.tokenize.apply(makeTokenizeResult())
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.tokenize.table.isVisible(TokenizeColumnKey.normalized.rawValue))

        dispatcher.handleTokenizeAction(.toggleColumn(.normalized))

        XCTAssertFalse(workspace.sceneGraph.tokenize.table.isVisible(TokenizeColumnKey.normalized.rawValue))
    }

    func testDispatcherChiSquareResetResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        workspace.chiSquare.apply(makeChiSquareResult())
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.chiSquare.hasResult)

        dispatcher.handleChiSquareAction(.reset)

        XCTAssertFalse(workspace.sceneGraph.chiSquare.hasResult)
    }

    func testDispatcherKWICLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        workspace.kwic.keyword = "node"
        workspace.kwic.apply(makeKWICResult(rowCount: 5))
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.kwic.table.isVisible("leftContext"))

        dispatcher.handleKWICAction(.toggleColumn(.leftContext))

        XCTAssertFalse(workspace.sceneGraph.kwic.table.isVisible("leftContext"))
    }

    func testDispatcherKeywordLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        workspace.keyword.apply(makeKeywordSuiteResult())
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.keyword.table.isVisible("referenceRange"))

        dispatcher.handleKeywordAction(.toggleColumn(.referenceRange))

        XCTAssertFalse(workspace.sceneGraph.keyword.table.isVisible("referenceRange"))
    }

    func testDispatcherKeywordWorkflowActionRoutesToCompareDistribution() async {
        let referenceSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "Reference Set",
            "corpusIds": ["corpus-2"],
            "corpusNames": ["Compare Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let repository = FakeWorkspaceRepository(
            bootstrapState: makeBootstrapState(corpusSets: [referenceSet])
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        workspace.keyword.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.keyword.focusSelectionKind = .singleCorpus
        workspace.keyword.selectedFocusCorpusID = "corpus-1"
        workspace.keyword.referenceSourceKind = .namedCorpusSet
        workspace.keyword.selectedReferenceCorpusSetID = "set-1"
        workspace.keyword.apply(makeKeywordSuiteResult())
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleKeywordAction(.openCompareDistribution)

        XCTAssertEqual(workspace.selectedTab, .compare)
        XCTAssertEqual(workspace.compare.query, "alpha")
        XCTAssertEqual(workspace.compare.selectedReferenceSelection, .corpusSet("set-1"))
    }

    func testDispatcherKwicActivationRunsLocatorFromSelectedRow() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "node"
        workspace.kwic.apply(makeKWICResult(rowCount: 3))
        workspace.syncLocatorSourceFromKWIC()
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleKWICAction(.activateRow("1-2"))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runLocatorCallCount, 1)
        XCTAssertEqual(repository.lastRunLocatorSentenceId, 1)
        XCTAssertEqual(repository.lastRunLocatorNodeIndex, 2)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .locator)
    }

    func testDispatcherNgramLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        workspace.ngram.apply(makeNgramResult(rowCount: 5))
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.ngram.table.isVisible("count"))

        dispatcher.handleNgramAction(.toggleColumn(.count))

        XCTAssertFalse(workspace.sceneGraph.ngram.table.isVisible("count"))
    }

    func testDispatcherCollocateLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        workspace.collocate.keyword = "node"
        workspace.collocate.apply(makeCollocateResult(rowCount: 5))
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.collocate.table.isVisible("rate"))

        dispatcher.handleCollocateAction(.toggleColumn(.rate))

        XCTAssertFalse(workspace.sceneGraph.collocate.table.isVisible("rate"))
    }

    func testDispatcherCollocateOpenKWICActionLaunchesWorkspaceRun() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        workspace.collocate.keyword = "node"
        workspace.collocate.apply(makeCollocateResult(rowCount: 3))
        workspace.collocate.selectedRowID = "collocate-1"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleCollocateAction(.openKWIC)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runKWICCallCount, 1)
        XCTAssertEqual(workspace.kwic.keyword, "collocate-1")
        XCTAssertEqual(workspace.sceneGraph.activeTab, .kwic)
    }

    func testDispatcherKWICSaveCorpusSetActionUsesPreferredRoute() async {
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
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace, preferredWindowRoute: .mainWorkspace)

        dispatcher.handleKWICAction(.saveCorpusSet)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.saveCorpusSetCallCount, 1)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .mainWorkspace)
    }

    func testDispatcherKWICSaveCurrentHitSetUsesPreferredRoute() async {
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
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace, preferredWindowRoute: .mainWorkspace)

        dispatcher.handleKWICAction(.saveCurrentHitSet)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.saveConcordanceSavedSetCallCount, 1)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .mainWorkspace)
        XCTAssertEqual(repository.concordanceSavedSets.first?.rows.map(\.id), ["2-1"])
    }

    func testDispatcherLocatorSaveCorpusSetActionUsesPreferredRoute() async {
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
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace, preferredWindowRoute: .mainWorkspace)

        dispatcher.handleLocatorAction(.saveCorpusSet)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.saveCorpusSetCallCount, 1)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .mainWorkspace)
    }

    func testDispatcherLocatorExportSelectedSavedSetJSONUsesPreferredRoute() async throws {
        let repository = FakeWorkspaceRepository()
        repository.concordanceSavedSets = [makeConcordanceSavedSet(kind: .locator, rowCount: 2)]
        let dialogService = FakeDialogService()
        let exportURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("locator-hit-set-export-\(UUID().uuidString).json")
        dialogService.savePathResult = exportURL.path
        defer { try? FileManager.default.removeItem(at: exportURL) }
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )
        await workspace.initializeIfNeeded()
        workspace.locator.selectedSavedSetID = repository.concordanceSavedSets.first?.id
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace, preferredWindowRoute: .mainWorkspace)

        dispatcher.handleLocatorAction(.exportSelectedSavedSetJSON)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(dialogService.savePathPreferredRoute, .mainWorkspace)
        XCTAssertTrue(FileManager.default.fileExists(atPath: exportURL.path))
    }

    func testDispatcherKWICImportSavedSetsJSONUsesPreferredRoute() async throws {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        let importURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("dispatcher-hit-set-import-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: importURL) }
        let payload = try ConcordanceSavedSetTransferSupport.exportData(
            sets: [makeConcordanceSavedSet(kind: .kwic, rowCount: 1)]
        )
        try payload.write(to: importURL, options: .atomic)
        dialogService.openPathResult = importURL.path
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )
        await workspace.initializeIfNeeded()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace, preferredWindowRoute: .mainWorkspace)

        dispatcher.handleKWICAction(.importSavedSetsJSON)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(dialogService.openPathPreferredRoute, .mainWorkspace)
        XCTAssertEqual(repository.saveConcordanceSavedSetCallCount, 1)
    }

    func testDispatcherKWICLoadSelectedSavedSetRehydratesSceneGraph() async {
        let repository = FakeWorkspaceRepository()
        let savedSet = makeConcordanceSavedSet(kind: .kwic, rowCount: 2)
        repository.concordanceSavedSets = [savedSet]
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        workspace.selectedTab = .stats
        workspace.kwic.selectedSavedSetID = savedSet.id
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleKWICAction(.loadSelectedSavedSet)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(workspace.sceneGraph.activeTab, .kwic)
        XCTAssertEqual(workspace.kwic.result?.rows.count, 2)
    }

    func testDispatcherKWICSaveFilteredSavedSetUsesPreferredRoute() async {
        let repository = FakeWorkspaceRepository()
        let savedSet = makeConcordanceSavedSet(kind: .kwic, rowCount: 2)
        repository.concordanceSavedSets = [savedSet]
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "KWIC Refined"
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )
        await workspace.initializeIfNeeded()
        workspace.kwic.selectedSavedSetID = savedSet.id
        workspace.kwic.savedSetFilterQuery = "node-1"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace, preferredWindowRoute: .mainWorkspace)

        dispatcher.handleKWICAction(.saveFilteredSavedSet)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(dialogService.promptTextPreferredRoute, .mainWorkspace)
        XCTAssertEqual(repository.concordanceSavedSets.first?.name, "KWIC Refined")
        XCTAssertEqual(repository.concordanceSavedSets.first?.rows.map(\.id), ["row-1"])
    }

    func testDispatcherKWICAddCurrentRowToEvidenceWorkbenchPersistsItem() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "node"
        workspace.kwic.apply(makeKWICResult(rowCount: 3))
        workspace.kwic.selectedRowID = "1-2"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleKWICAction(.addCurrentRowToEvidenceWorkbench)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.evidenceItems.count, 1)
        XCTAssertEqual(repository.evidenceItems.first?.sourceKind, .kwic)
    }

    func testDispatcherLocatorSaveSelectedEvidenceNoteUpdatesRepository() async {
        let repository = FakeWorkspaceRepository()
        repository.evidenceItems = [makeEvidenceItem(sourceKind: .locator, reviewStatus: .pending)]
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.selectedItemID = repository.evidenceItems.first?.id
        workspace.evidenceWorkbench.noteDraft = "dispatcher note"
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleLocatorAction(.saveSelectedEvidenceNote)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.evidenceItems.first?.note, "dispatcher note")
    }

    func testDispatcherLocatorLocalActionResyncsSceneGraph() {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        workspace.kwic.keyword = "node"
        workspace.kwic.apply(makeKWICResult(rowCount: 5))
        let source = workspace.kwic.primaryLocatorSource ?? LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 2)
        workspace.locator.apply(makeLocatorResult(rowCount: 5), source: source)
        workspace.syncSceneGraph()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        XCTAssertTrue(workspace.sceneGraph.locator.table.isVisible("status"))

        dispatcher.handleLocatorAction(.toggleColumn(.status))

        XCTAssertFalse(workspace.sceneGraph.locator.table.isVisible("status"))
    }

    func testDispatcherLibrarySelectionActionsSyncSidebarAndOpenFlow() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleLibraryAction(.selectRecycleEntry("recycle-1"))
        XCTAssertNil(workspace.sidebar.selectedCorpusID)
        XCTAssertEqual(workspace.library.scene.selectedRecycleEntryID, "recycle-1")

        dispatcher.handleLibraryAction(.selectCorpus("corpus-2"))
        dispatcher.handleLibraryAction(.openSelectedCorpus)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "corpus-2")
        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
    }

    func testDispatcherPersistsRecentCorpusSetSelection() async {
        let savedSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "教学语料集",
            "corpusIds": ["corpus-1"],
            "corpusNames": ["Demo Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let repository = FakeWorkspaceRepository()
        repository.bootstrapState = makeBootstrapState(corpusSets: [savedSet])
        repository.librarySnapshot = repository.bootstrapState.librarySnapshot
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleLibraryAction(.selectCorpusSet("set-1"))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.savedUISettings.last?.recentCorpusSetIDs, ["set-1"])
        XCTAssertEqual(workspace.settings.exportSnapshot().recentCorpusSetIDs, ["set-1"])
        XCTAssertEqual(workspace.sidebar.recentCorpusSetIDs, ["set-1"])
        XCTAssertEqual(workspace.library.scene.recentCorpusSets.map(\.id), ["set-1"])
    }

    func testDispatcherLibraryQuickLookActionUsesSelectedCorpus() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions
        )
        await workspace.initializeIfNeeded()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleLibraryAction(.quickLookSelectedCorpus)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(hostActions.quickLookCallCount, 1)
        XCTAssertEqual(hostActions.lastQuickLookPath, "/tmp/demo.txt")
    }

    func testDispatcherToolbarShareActionUsesCurrentContent() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let previewDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-dispatch-share-\(UUID().uuidString)", isDirectory: true)
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            quickLookPreviewFileService: QuickLookPreviewFileService(rootDirectory: previewDirectory)
        )
        await workspace.initializeIfNeeded()
        await workspace.runStats()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleToolbarAction(.shareCurrentContent)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(hostActions.shareCallCount, 1)
        XCTAssertEqual(hostActions.lastSharedPaths.count, 1)
    }

    func testDispatcherSettingsSavePersistsSnapshot() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)
        workspace.settings.showWelcomeScreen = false
        workspace.settings.restoreWorkspace = false

        dispatcher.handleSettingsAction(.save)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.savedUISettings.count, 1)
        XCTAssertEqual(repository.savedUISettings.first?.showWelcomeScreen, false)
        XCTAssertEqual(repository.savedUISettings.first?.restoreWorkspace, false)
    }

    func testLibraryDispatcherForwardsPreferredRouteToDialogService() async {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "新文件夹"
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )
        await workspace.initializeIfNeeded()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace, preferredWindowRoute: .library)

        dispatcher.handleLibraryAction(.createFolder)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(dialogService.promptTextPreferredRoute, .library)
        XCTAssertEqual(repository.createFolderCallCount, 1)
    }

    func testSettingsDispatcherForwardsPreferredRouteToDiagnosticsExport() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let diagnosticsBundleService = FakeDiagnosticsBundleService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostActionService: hostActions,
            diagnosticsBundleService: diagnosticsBundleService
        )
        await workspace.initializeIfNeeded()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace, preferredWindowRoute: .settings)

        dispatcher.handleSettingsAction(.exportDiagnostics)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(hostActions.exportedDiagnosticPreferredRoute, .settings)
        XCTAssertNotNil(diagnosticsBundleService.lastPayload)
    }

    func testDispatcherLibraryInfoActionBuildsCorpusInfoSheet() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleLibraryAction(.showSelectedCorpusInfo)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.loadCorpusInfoCallCount, 1)
        XCTAssertEqual(repository.openSavedCorpusCallCount, 0)
        XCTAssertEqual(repository.runStatsCallCount, 0)
        XCTAssertEqual(workspace.library.corpusInfoSheet?.title, "Demo Corpus")
    }

    func testDispatcherSidebarCorpusInfoActionSelectsCorpusAndShowsInfo() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleSidebarAction(.showCorpusInfoSelected("corpus-2"))
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "corpus-2")
        XCTAssertEqual(workspace.library.scene.selectedCorpusID, "corpus-2")
        XCTAssertEqual(repository.loadCorpusInfoCallCount, 1)
        XCTAssertEqual(workspace.library.corpusInfoSheet?.title, "Demo Corpus")
    }

    func testDispatcherLibraryEditMetadataActionPresentsEditorSheet() async {
        let repository = FakeWorkspaceRepository()
        repository.bootstrapState = makeBootstrapState(
            uiSettings: UISettingsSnapshot(
                showWelcomeScreen: true,
                restoreWorkspace: true,
                debugLogging: false,
                recentMetadataSourceLabels: ["播客", "教材"]
            )
        )
        repository.librarySnapshot = repository.bootstrapState.librarySnapshot
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleLibraryAction(.selectCorpus("corpus-2"))
        dispatcher.handleLibraryAction(.editSelectedCorpusMetadata)

        XCTAssertEqual(workspace.library.metadataEditorSheet?.id, "corpus-2")
        XCTAssertEqual(workspace.library.metadataEditorSheet?.genreLabel, "学术")
        XCTAssertEqual(workspace.library.metadataEditorSheet?.sourcePresetLabels, MetadataSourcePresetSupport.builtInSourceLabels)
        XCTAssertEqual(workspace.library.metadataEditorSheet?.recentSourceLabels, ["播客"])
        XCTAssertEqual(workspace.library.metadataEditorSheet?.quickYearLabels.count, 5)
    }

    func testDispatcherLibraryCleanActionRunsCleaningFlowAndRefreshesSelection() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        await workspace.initializeIfNeeded()
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        dispatcher.handleLibraryAction(.selectCorpus("corpus-1"))
        dispatcher.handleLibraryAction(.cleanSelectedCorpus)
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(repository.cleanCorporaCallCount, 1)
        XCTAssertEqual(workspace.library.selectedCorpus?.id, "corpus-1")
        XCTAssertEqual(workspace.library.selectedCorpus?.cleaningStatus, .cleanedWithChanges)
        XCTAssertTrue(workspace.library.scene.statusMessage.contains("清洗"))
    }
}

private func makeTopicsDispatcherFixture() -> (
    openedCorpus: OpenedCorpus,
    topicsResult: TopicAnalysisResult,
    sentimentResult: SentimentRunResult
) {
    let paragraphs = [
        "Security researchers discussed hacker communities and disclosure norms.",
        "Hackers shared exploit mitigation strategies and coordinated fixes.",
        "A short unrelated paragraph about coffee and weather."
    ]
    let documentText = paragraphs.joined(separator: "\n\n")
    let openedCorpus = OpenedCorpus(json: [
        "mode": "saved",
        "filePath": "/tmp/topics-dispatcher.txt",
        "displayName": "Topics Dispatcher Corpus",
        "content": documentText,
        "sourceType": "txt"
    ])
    let topicsResult = TopicAnalysisResult(
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
                    TopicKeywordCandidate(term: "coffee", score: 0.75)
                ],
                representativeSegmentIDs: ["paragraph-3"]
            )
        ],
        segments: [
            TopicSegmentRow(
                id: "paragraph-1",
                topicID: "topic-1",
                paragraphIndex: 1,
                text: paragraphs[0],
                similarityScore: 0.91,
                isOutlier: false
            ),
            TopicSegmentRow(
                id: "paragraph-2",
                topicID: "topic-1",
                paragraphIndex: 2,
                text: paragraphs[1],
                similarityScore: 0.88,
                isOutlier: false
            ),
            TopicSegmentRow(
                id: "paragraph-3",
                topicID: TopicAnalysisResult.outlierTopicID,
                paragraphIndex: 3,
                text: paragraphs[2],
                similarityScore: 0,
                isOutlier: true
            )
        ],
        totalSegments: 3,
        clusteredSegments: 2,
        outlierCount: 1,
        warnings: []
    )
    let sentimentResult = SentimentRunResult(
        request: SentimentRunRequest(
            source: .topicSegments,
            unit: .sourceSentence,
            contextBasis: .fullSentenceWhenAvailable,
            thresholds: .default,
            texts: [
                SentimentInputText(
                    id: "paragraph-1::sentence::0",
                    sourceID: "corpus-1",
                    sourceTitle: openedCorpus.displayName,
                    text: paragraphs[0],
                    sentenceID: 0,
                    tokenIndex: 0,
                    groupID: "topic-1",
                    groupTitle: "Topic 1",
                    documentText: documentText
                ),
                SentimentInputText(
                    id: "paragraph-2::sentence::1",
                    sourceID: "corpus-1",
                    sourceTitle: openedCorpus.displayName,
                    text: paragraphs[1],
                    sentenceID: 1,
                    tokenIndex: 0,
                    groupID: "topic-1",
                    groupTitle: "Topic 1",
                    documentText: documentText
                ),
                SentimentInputText(
                    id: "paragraph-3::sentence::2",
                    sourceID: "corpus-1",
                    sourceTitle: openedCorpus.displayName,
                    text: paragraphs[2],
                    sentenceID: 2,
                    tokenIndex: 0,
                    groupID: TopicAnalysisResult.outlierTopicID,
                    groupTitle: "Outlier Topic",
                    documentText: documentText
                )
            ],
            backend: .lexicon
        ),
        backendKind: .lexicon,
        backendRevision: "lexicon-v1",
        resourceRevision: "resource-v1",
        supportsEvidenceHits: true,
        rows: [],
        overallSummary: SentimentAggregateSummary(
            id: "overall",
            title: "Overall",
            totalTexts: 0,
            positiveCount: 0,
            neutralCount: 0,
            negativeCount: 0,
            positiveRatio: 0,
            neutralRatio: 0,
            negativeRatio: 0,
            averagePositivity: 0,
            averageNeutrality: 0,
            averageNegativity: 0,
            averageNetScore: 0
        ),
        groupSummaries: [],
        lexiconVersion: "lexicon-v1"
    )
    return (openedCorpus, topicsResult, sentimentResult)
}
