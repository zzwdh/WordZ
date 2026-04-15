import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class MainWorkspaceViewModelTests: XCTestCase {
    func testInitializeIfNeededBootstrapsSceneGraph() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore()
        )

        await workspace.initializeIfNeeded()

        XCTAssertEqual(workspace.sceneGraph.context.appName, "WordZ")
        XCTAssertEqual(workspace.sceneGraph.activeTab, .kwic)
        XCTAssertEqual(workspace.sceneGraph.sidebar.currentCorpus?.title, "Demo Corpus")
        XCTAssertEqual(workspace.sceneGraph.settings.workspaceSummary, "工作区：Demo Corpus ｜ 当前语料：Demo Corpus")
        XCTAssertFalse(workspace.isWelcomePresented)
    }

    func testRunAnalysisFlowsUpdateSceneGraphResultNodes() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.ngram.query = "phrase"
        workspace.kwic.keyword = "node"
        workspace.collocate.keyword = "node"
        workspace.compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.chiSquare.a = "10"
        workspace.chiSquare.b = "20"
        workspace.chiSquare.c = "6"
        workspace.chiSquare.d = "14"

        await workspace.runStats()
        XCTAssertTrue(workspace.sceneGraph.stats.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .stats)

        await workspace.runTokenize()
        XCTAssertTrue(workspace.sceneGraph.tokenize.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .tokenize)

        await workspace.runCompare()
        XCTAssertTrue(workspace.sceneGraph.compare.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .compare)

        await workspace.runChiSquare()
        XCTAssertTrue(workspace.sceneGraph.chiSquare.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .chiSquare)

        await workspace.runNgram()
        XCTAssertTrue(workspace.sceneGraph.ngram.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .ngram)

        await workspace.runKWIC()
        XCTAssertTrue(workspace.sceneGraph.kwic.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .kwic)

        await workspace.runCollocate()
        XCTAssertTrue(workspace.sceneGraph.collocate.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .collocate)

        await workspace.runLocator()
        XCTAssertTrue(workspace.sceneGraph.locator.hasResult)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .locator)
    }

    func testAnalyzeCompareSelectionInKeywordSuiteExcludesFixedReferenceCorpusFromFocus() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.compare.selectedCorpusIDs = ["corpus-1", "corpus-2"]
        workspace.compare.selectedReferenceSelection = .corpus("corpus-2")

        workspace.analyzeCompareSelectionInKeywordSuite()

        XCTAssertEqual(workspace.selectedTab, .keyword)
        XCTAssertEqual(workspace.keyword.activeTab, .words)
        XCTAssertEqual(workspace.keyword.focusSelectionKind, .singleCorpus)
        XCTAssertEqual(workspace.keyword.selectedFocusCorpusID, "corpus-1")
        XCTAssertEqual(workspace.keyword.orderedFocusCorpusIDs, ["corpus-1"])
        XCTAssertEqual(workspace.keyword.referenceSourceKind, .singleCorpus)
        XCTAssertEqual(workspace.keyword.selectedReferenceCorpusID, "corpus-2")
        XCTAssertTrue(workspace.keyword.canRun)
    }

    func testAnalyzeCompareSelectionInKeywordSuitePreservesSingleFocusCorpusForReferenceSetBridge() async {
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
        workspace.compare.selectedCorpusIDs = ["corpus-1"]
        workspace.compare.selectedReferenceSelection = .corpusSet("set-1")

        workspace.analyzeCompareSelectionInKeywordSuite()

        XCTAssertEqual(workspace.selectedTab, .keyword)
        XCTAssertEqual(workspace.keyword.focusSelectionKind, .singleCorpus)
        XCTAssertEqual(workspace.keyword.selectedFocusCorpusID, "corpus-1")
        XCTAssertEqual(workspace.keyword.referenceSourceKind, .namedCorpusSet)
        XCTAssertEqual(workspace.keyword.selectedReferenceCorpusSetID, "set-1")
    }

    func testOpenKeywordKWICUsesSelectedKeywordRowFocusScope() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.keyword.apply(makeKeywordSuiteResult())

        let openedCorpusCountBefore = repository.openSavedCorpusCallCount
        let kwicRunCountBefore = repository.runKWICCallCount

        await workspace.openKeywordKWIC(scope: .focus)

        XCTAssertEqual(repository.openSavedCorpusCallCount, openedCorpusCountBefore + 1)
        XCTAssertEqual(repository.runKWICCallCount, kwicRunCountBefore + 1)
        XCTAssertEqual(workspace.kwic.keyword, "alpha")
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "corpus-1")
        XCTAssertEqual(workspace.selectedTab, .kwic)
        XCTAssertTrue(workspace.sceneGraph.kwic.hasResult)
    }

    func testOpenCompareKWICUsesDominantCorpusAndRunsKWIC() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.compare.selectedCorpusIDs = ["corpus-1", "corpus-2"]
        workspace.compare.apply(makeCompareResult())
        workspace.compare.selectedRowID = "alpha"

        let kwicRunCountBefore = repository.runKWICCallCount

        await workspace.openCompareKWIC()

        XCTAssertEqual(repository.runKWICCallCount, kwicRunCountBefore + 1)
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "corpus-1")
        XCTAssertEqual(workspace.kwic.keyword, "alpha")
        XCTAssertEqual(workspace.selectedTab, .kwic)
        XCTAssertTrue(workspace.sceneGraph.kwic.hasResult)
    }

    func testOpenCompareCollocateUsesHighestNormFreqTargetCorpusWhenReferenceIsFixed() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.compare.syncLibrarySnapshot(repository.bootstrapState.librarySnapshot)
        workspace.compare.selectedCorpusIDs = ["corpus-1", "corpus-2"]
        workspace.compare.selectedReferenceSelection = .corpus("corpus-2")
        workspace.compare.apply(makeCompareResult())
        workspace.compare.selectedRowID = "alpha"

        let collocateRunCountBefore = repository.runCollocateCallCount

        await workspace.openCompareCollocate()

        XCTAssertEqual(repository.runCollocateCallCount, collocateRunCountBefore + 1)
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "corpus-1")
        XCTAssertEqual(workspace.collocate.keyword, "alpha")
        XCTAssertEqual(workspace.selectedTab, .collocate)
        XCTAssertTrue(workspace.sceneGraph.collocate.hasResult)
    }

    func testOpenCollocateKWICReusesCurrentCorpusAndRunsKWIC() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.collocate.keyword = "node"
        workspace.collocate.apply(makeCollocateResult(rowCount: 3))
        workspace.collocate.selectedRowID = "collocate-1"

        let kwicRunCountBefore = repository.runKWICCallCount

        await workspace.openCollocateKWIC()

        XCTAssertEqual(repository.runKWICCallCount, kwicRunCountBefore + 1)
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "corpus-1")
        XCTAssertEqual(workspace.kwic.keyword, "collocate-1")
        XCTAssertEqual(workspace.selectedTab, .kwic)
        XCTAssertTrue(workspace.sceneGraph.kwic.hasResult)
    }

    func testOpenCurrentSourceReaderFromKWICLoadsSelectedSentenceContext() async {
        let repository = FakeWorkspaceRepository(
            tokenizeResult: makeTokenizeResult(),
            kwicResult: KWICResult(rows: [
                KWICRow(id: "0-0", left: "", node: "Alpha", right: "beta gamma", sentenceId: 0, sentenceTokenIndex: 0),
                KWICRow(id: "1-1", left: "Delta", node: "alpha", right: "", sentenceId: 1, sentenceTokenIndex: 1)
            ])
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "alpha"
        await workspace.runKWIC()
        workspace.kwic.selectedRowID = "1-1"

        let opened = await workspace.openCurrentSourceReader()

        XCTAssertTrue(opened)
        XCTAssertEqual(workspace.sourceReader.launchContext?.origin, .kwic)
        XCTAssertEqual(workspace.sourceReader.scene?.selectedHitID, "1-1")
        XCTAssertEqual(workspace.sourceReader.scene?.selection?.hit.fullSentenceText, "Delta alpha.")
        XCTAssertTrue(workspace.sourceReader.scene?.originSummary.contains("KWIC") == true)
    }

    func testOpenCurrentSourceReaderFromLocatorLoadsSentenceContext() async {
        let repository = FakeWorkspaceRepository(
            tokenizeResult: makeTokenizeResult(),
            locatorResult: LocatorResult(json: [
                "sentences": [
                    [
                        "sentenceId": 0,
                        "text": "Alpha beta gamma.",
                        "leftWords": "",
                        "nodeWord": "Alpha",
                        "rightWords": "beta gamma",
                        "status": "当前定位"
                    ],
                    [
                        "sentenceId": 1,
                        "text": "Delta alpha.",
                        "leftWords": "Delta",
                        "nodeWord": "alpha",
                        "rightWords": "",
                        "status": ""
                    ]
                ],
                "rows": [
                    [
                        "sentenceId": 0,
                        "text": "Alpha beta gamma.",
                        "leftWords": "",
                        "nodeWord": "Alpha",
                        "rightWords": "beta gamma",
                        "status": "当前定位"
                    ],
                    [
                        "sentenceId": 1,
                        "text": "Delta alpha.",
                        "leftWords": "Delta",
                        "nodeWord": "alpha",
                        "rightWords": "",
                        "status": ""
                    ]
                ]
            ])
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.locator.apply(
            repository.locatorResult,
            source: LocatorSource(keyword: "alpha", sentenceId: 1, nodeIndex: 1)
        )
        workspace.locator.selectedRowID = "1"

        let opened = await workspace.openCurrentSourceReader()

        XCTAssertTrue(opened)
        XCTAssertEqual(workspace.sourceReader.launchContext?.origin, .locator)
        XCTAssertEqual(workspace.sourceReader.scene?.selectedHitID, "1")
        XCTAssertEqual(workspace.sourceReader.scene?.selection?.hit.fullSentenceText, "Delta alpha.")
    }

    func testOpenCurrentSourceReaderFromPlotUsesSelectedMarker() async {
        let repository = FakeWorkspaceRepository(
            tokenizeResult: makeTokenizeResult(),
            plotResult: makePlotResult(
                rows: [
                    PlotRow(
                        id: "corpus-1",
                        corpusId: "corpus-1",
                        fileID: 0,
                        filePath: "/tmp/demo.txt",
                        displayName: "Demo Corpus",
                        fileTokens: 5,
                        frequency: 2,
                        normalizedFrequency: 400,
                        hitMarkers: [
                            PlotHitMarker(id: "0-0", sentenceId: 0, tokenIndex: 0, normalizedPosition: 0),
                            PlotHitMarker(id: "1-1", sentenceId: 1, tokenIndex: 1, normalizedPosition: 1)
                        ]
                    )
                ]
            )
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.plot.query = "alpha"
        await workspace.runPlot()
        workspace.plot.handle(PlotPageAction.selectMarker(rowID: "corpus-1", markerID: "1-1"))

        let opened = await workspace.openCurrentSourceReader()

        XCTAssertTrue(opened)
        XCTAssertEqual(workspace.sourceReader.launchContext?.origin, .plot)
        XCTAssertEqual(workspace.sourceReader.scene?.selectedHitID, "1-1")
        XCTAssertEqual(workspace.sourceReader.scene?.selection?.hit.fullSentenceText, "Delta alpha.")
    }

    func testOpenCurrentSourceReaderFromPlotFallsBackToFirstMarker() async {
        let repository = FakeWorkspaceRepository(
            tokenizeResult: makeTokenizeResult(),
            plotResult: makePlotResult(
                rows: [
                    PlotRow(
                        id: "corpus-1",
                        corpusId: "corpus-1",
                        fileID: 0,
                        filePath: "/tmp/demo.txt",
                        displayName: "Demo Corpus",
                        fileTokens: 5,
                        frequency: 2,
                        normalizedFrequency: 400,
                        hitMarkers: [
                            PlotHitMarker(id: "0-0", sentenceId: 0, tokenIndex: 0, normalizedPosition: 0),
                            PlotHitMarker(id: "1-1", sentenceId: 1, tokenIndex: 1, normalizedPosition: 1)
                        ]
                    )
                ]
            )
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.plot.query = "alpha"
        await workspace.runPlot()
        workspace.plot.handle(PlotPageAction.selectRow("corpus-1"))

        let opened = await workspace.openCurrentSourceReader()

        XCTAssertTrue(opened)
        XCTAssertEqual(workspace.sourceReader.scene?.selectedHitID, "0-0")
        XCTAssertEqual(workspace.sourceReader.scene?.selection?.hit.fullSentenceText, "Alpha beta gamma.")
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

    func testCaptureLocatorEvidenceItemCanUpdateReviewStatusAndNote() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        let source = LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 2)
        workspace.locator.apply(makeLocatorResult(rowCount: 2), source: source)
        workspace.locator.selectedRowID = "1"

        await workspace.captureCurrentLocatorEvidenceItem()
        let itemID = try? XCTUnwrap(repository.evidenceItems.first?.id)
        XCTAssertEqual(repository.evidenceItems.first?.sourceKind, .locator)

        if let itemID {
            await workspace.updateEvidenceReviewStatus(itemID: itemID, reviewStatus: .keep)
            workspace.evidenceWorkbench.noteDraft = "reviewed sentence"
            await workspace.saveSelectedEvidenceNote()
        }

        XCTAssertEqual(repository.evidenceItems.first?.reviewStatus, .keep)
        XCTAssertEqual(repository.evidenceItems.first?.note, "reviewed sentence")
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItem?.note, "reviewed sentence")
    }

    func testEvidenceWorkbenchSelectionFallsBackToVisibleItemWhenFilterExcludesUpdatedRow() async {
        let repository = FakeWorkspaceRepository()
        let first = makeEvidenceItem(sourceKind: .kwic, reviewStatus: .pending)
        let second = EvidenceItem(
            id: "evidence-pending-2",
            sourceKind: .locator,
            savedSetID: nil,
            savedSetName: nil,
            corpusID: "corpus-2",
            corpusName: "Locator Corpus",
            sentenceId: 3,
            sentenceTokenIndex: 4,
            leftContext: "left",
            keyword: "second",
            rightContext: "right",
            fullSentenceText: "left second right",
            citationText: "Sentence 4: left second right",
            query: "second",
            leftWindow: 5,
            rightWindow: 5,
            searchOptionsSnapshot: nil,
            stopwordFilterSnapshot: nil,
            reviewStatus: .pending,
            note: nil,
            createdAt: "2026-04-14T00:00:00Z",
            updatedAt: "2026-04-14T00:00:00Z"
        )
        repository.evidenceItems = [first, second]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.reviewFilter = .pending
        workspace.evidenceWorkbench.selectedItemID = first.id

        await workspace.updateEvidenceReviewStatus(itemID: first.id, reviewStatus: .keep)

        XCTAssertEqual(repository.evidenceItems.first?.reviewStatus, .keep)
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItemID, second.id)
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItem?.id, second.id)
    }

    func testExportEvidenceArtifactsWriteMarkdownAndJSON() async throws {
        let dialogService = FakeDialogService()
        let markdownURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("evidence-packet-\(UUID().uuidString).md")
        let jsonURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("evidence-bundle-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: markdownURL)
            try? FileManager.default.removeItem(at: jsonURL)
        }

        let repository = FakeWorkspaceRepository()
        repository.evidenceItems = [
            EvidenceItem(
                id: "keep-item",
                sourceKind: .kwic,
                savedSetID: "saved-kwic-3",
                savedSetName: "KWIC Set",
                corpusID: "corpus-1",
                corpusName: "Demo Corpus",
                sentenceId: 1,
                sentenceTokenIndex: 2,
                leftContext: "left",
                keyword: "keep-only",
                rightContext: "right",
                fullSentenceText: "left keep-only right",
                citationText: "Sentence 2: left keep-only right",
                query: "keep-only",
                leftWindow: 5,
                rightWindow: 5,
                searchOptionsSnapshot: .default,
                stopwordFilterSnapshot: .default,
                reviewStatus: .keep,
                note: nil,
                createdAt: "2026-04-13T00:00:00Z",
                updatedAt: "2026-04-13T00:00:00Z"
            ),
            EvidenceItem(
                id: "pending-item",
                sourceKind: .locator,
                savedSetID: nil,
                savedSetName: nil,
                corpusID: "corpus-2",
                corpusName: "Locator Corpus",
                sentenceId: 3,
                sentenceTokenIndex: 4,
                leftContext: "left",
                keyword: "pending-only",
                rightContext: "right",
                fullSentenceText: "left pending-only right",
                citationText: "Sentence 4: left pending-only right",
                query: "pending-only",
                leftWindow: 5,
                rightWindow: 5,
                searchOptionsSnapshot: nil,
                stopwordFilterSnapshot: nil,
                reviewStatus: .pending,
                note: nil,
                createdAt: "2026-04-13T00:00:00Z",
                updatedAt: "2026-04-13T00:00:00Z"
            )
        ]
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()

        dialogService.savePathResult = markdownURL.path
        await workspace.exportEvidencePacketMarkdown(preferredWindowRoute: .mainWorkspace)

        let markdownText = try String(contentsOf: markdownURL, encoding: .utf8)
        XCTAssertTrue(markdownText.contains("keep-only"))
        XCTAssertFalse(markdownText.contains("pending-only"))

        dialogService.savePathResult = jsonURL.path
        await workspace.exportEvidenceJSON(preferredWindowRoute: .mainWorkspace)

        let jsonData = try Data(contentsOf: jsonURL)
        let bundle = try JSONDecoder().decode(EvidenceTransferBundle.self, from: jsonData)
        XCTAssertEqual(bundle.version, 1)
        XCTAssertEqual(bundle.items.count, 2)
        XCTAssertEqual(dialogService.savePathPreferredRoute, .mainWorkspace)
    }

    func testExportSelectedKeywordSavedListJSONWritesTransferBundle() async throws {
        let dialogService = FakeDialogService()
        let exportURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("keyword-suite-export-\(UUID().uuidString).json")
        dialogService.savePathResult = exportURL.path

        let savedList = KeywordSavedList(
            id: "list-1",
            name: "Teaching Set",
            group: .words,
            createdAt: "2026-04-11T00:00:00Z",
            updatedAt: "2026-04-11T00:00:00Z",
            focusLabel: "Focus",
            referenceLabel: "Reference",
            configuration: makeKeywordSuiteResult().configuration,
            rows: makeKeywordSuiteResult().words
        )
        let repository = FakeWorkspaceRepository()
        repository.keywordSavedLists = [savedList]
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.keyword.activeTab = .lists
        workspace.keyword.selectedSavedListID = savedList.id

        await workspace.exportSelectedKeywordSavedListJSON()

        let data = try Data(contentsOf: exportURL)
        let decoder = JSONDecoder()
        let bundle = try decoder.decode(KeywordSavedListTransferBundle.self, from: data)

        XCTAssertEqual(bundle.version, 1)
        XCTAssertEqual(bundle.lists.map(\.name), ["Teaching Set"])
        XCTAssertEqual(bundle.lists.first?.rows.count, savedList.rows.count)
    }

    func testExportSelectedKeywordSavedListJSONPreservesImportedReferenceMetadata() async throws {
        let dialogService = FakeDialogService()
        let exportURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("keyword-suite-export-metadata-\(UUID().uuidString).json")
        dialogService.savePathResult = exportURL.path
        defer { try? FileManager.default.removeItem(at: exportURL) }

        var configuration = makeKeywordSuiteResult().configuration
        configuration.referenceSource = KeywordReferenceSource(
            kind: .importedWordList,
            importedListText: "alpha\t2\nbeta\t1",
            importedListSourceName: "teaching.tsv",
            importedListImportedAt: "2026-04-12T09:30:00Z"
        )
        let savedList = KeywordSavedList(
            id: "list-1",
            name: "Imported Teaching Set",
            group: .words,
            createdAt: "2026-04-11T00:00:00Z",
            updatedAt: "2026-04-11T00:00:00Z",
            focusLabel: "Focus",
            referenceLabel: "Imported",
            configuration: configuration,
            rows: makeKeywordSuiteResult().words
        )
        let repository = FakeWorkspaceRepository()
        repository.keywordSavedLists = [savedList]
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.keyword.activeTab = .lists
        workspace.keyword.selectedSavedListID = savedList.id

        await workspace.exportSelectedKeywordSavedListJSON()

        let data = try Data(contentsOf: exportURL)
        let bundle = try JSONDecoder().decode(KeywordSavedListTransferBundle.self, from: data)

        XCTAssertEqual(bundle.lists.first?.configuration.referenceSource.importedListSourceName, "teaching.tsv")
        XCTAssertEqual(bundle.lists.first?.configuration.referenceSource.importedListImportedAt, "2026-04-12T09:30:00Z")
    }

    func testImportKeywordSavedListsJSONMergesListsWithoutOverwritingExistingIDs() async throws {
        let dialogService = FakeDialogService()
        let importURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("keyword-suite-import-\(UUID().uuidString).json")

        let existingList = KeywordSavedList(
            id: "shared-id",
            name: "Existing",
            group: .words,
            createdAt: "2026-04-11T00:00:00Z",
            updatedAt: "2026-04-11T00:00:00Z",
            focusLabel: "Focus A",
            referenceLabel: "Reference A",
            configuration: makeKeywordSuiteResult().configuration,
            rows: makeKeywordSuiteResult().words
        )
        let importedList = KeywordSavedList(
            id: "shared-id",
            name: "Imported",
            group: .terms,
            createdAt: "2026-04-12T00:00:00Z",
            updatedAt: "2026-04-12T00:00:00Z",
            focusLabel: "Focus B",
            referenceLabel: "Reference B",
            configuration: makeKeywordSuiteResult().configuration,
            rows: makeKeywordSuiteResult().terms
        )
        let payload = try KeywordSavedListTransferSupport.exportData(lists: [importedList])
        try payload.write(to: importURL, options: .atomic)
        dialogService.openPathResult = importURL.path

        let repository = FakeWorkspaceRepository()
        repository.keywordSavedLists = [existingList]
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        await workspace.importKeywordSavedListsJSON()

        XCTAssertEqual(repository.keywordSavedLists.count, 2)
        XCTAssertEqual(Set(repository.keywordSavedLists.map(\.name)), Set(["Existing", "Imported"]))
        XCTAssertEqual(Set(repository.keywordSavedLists.map(\.id)).count, 2)
        XCTAssertEqual(workspace.keyword.savedLists.count, 2)
    }

    func testExportKeywordRowContextWritesTextDocument() async throws {
        let dialogService = FakeDialogService()
        let exportURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("keyword-row-context-\(UUID().uuidString).txt")
        dialogService.savePathResult = exportURL.path

        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.keyword.apply(makeKeywordSuiteResult())

        await workspace.exportKeywordRowContext()

        let text = try String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertTrue(text.contains("alpha"))
        XCTAssertTrue(text.contains("Direction: Positive") || text.contains("Direction: 正关键词"))
        XCTAssertTrue(text.contains("Example: alpha example"))
    }

    func testImportKeywordReferenceWordListLoadsEditableTextAndMetadata() async throws {
        let dialogService = FakeDialogService()
        let importURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("keyword-reference-wordlist-\(UUID().uuidString).tsv")
        try "alpha\t2\n\nbeta\t0\nomega".write(to: importURL, atomically: true, encoding: .utf8)
        dialogService.openPathResult = importURL.path
        defer { try? FileManager.default.removeItem(at: importURL) }

        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.keyword.referenceSourceKind = .importedWordList

        await workspace.importKeywordReferenceWordList()

        XCTAssertEqual(workspace.keyword.referenceSourceKind, .importedWordList)
        XCTAssertEqual(workspace.keyword.importedReferenceListText, "alpha\t2\n\nbeta\t0\nomega")
        XCTAssertEqual(workspace.keyword.importedReferenceListSourceName, importURL.lastPathComponent)
        XCTAssertEqual(workspace.keyword.importedReferenceParseResult.acceptedLineCount, 2)
        XCTAssertEqual(workspace.keyword.importedReferenceParseResult.rejectedLineCount, 2)
        XCTAssertTrue(workspace.keyword.canResolveReferenceSelection)
    }

    func testOpenCompareDistributionFromKeywordPreservesQueryAndReferenceSelection() async {
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

        workspace.openCompareDistributionFromKeyword()

        XCTAssertEqual(workspace.selectedTab, .compare)
        XCTAssertEqual(workspace.compare.query, "alpha")
        XCTAssertEqual(workspace.compare.selectedReferenceSelection, .corpusSet("set-1"))
        XCTAssertEqual(workspace.compare.selectedCorpusIDs, Set(["corpus-1", "corpus-2"]))
    }

    func testResultContentSyncRefreshesSidebarSummaryAndExportAvailabilityFromUpdatedGraph() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        XCTAssertNil(workspace.sidebar.scene.results)
        XCTAssertEqual(
            workspace.shell.scene.toolbar.items.first(where: { $0.action == .exportCurrent })?.isEnabled,
            false
        )

        await workspace.runStats()

        XCTAssertEqual(workspace.sidebar.scene.results?.title, workspace.sceneGraph.stats.title)
        XCTAssertEqual(workspace.sidebar.scene.results?.subtitle, workspace.sceneGraph.stats.status)
        XCTAssertEqual(
            workspace.shell.scene.toolbar.items.first(where: { $0.action == .exportCurrent })?.isEnabled,
            true
        )
    }

    func testSettingsSceneSyncDoesNotHijackMainWorkspaceTab() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.selectedTab = .word
        workspace.settings.debugLogging = true
        workspace.syncSceneGraph(source: .settings)

        XCTAssertEqual(workspace.sceneGraph.activeTab, .word)
        XCTAssertTrue(workspace.settings.debugLogging)
    }

    func testOpenSelectedCorpusUpdatesSidebarAndPersistsWorkspace() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences
        )

        await workspace.initializeIfNeeded()
        await workspace.openSelectedCorpus()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
        XCTAssertEqual(workspace.sceneGraph.sidebar.currentCorpus?.title, "Demo Corpus")
        XCTAssertFalse(repository.savedWorkspaceDrafts.isEmpty)
        XCTAssertEqual(hostPreferences.recordRecentCallCount, 1)
        XCTAssertEqual(workspace.settings.scene.recentDocuments.first?.corpusID, "corpus-1")
    }

    func testOpenRecentDocumentPreparesSelectionWithoutExtraWorkspaceSave() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        let savedDraftCountBeforeOpen = repository.savedWorkspaceDrafts.count

        await workspace.openRecentDocument("corpus-2")
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
        XCTAssertEqual(repository.savedWorkspaceDrafts.count, savedDraftCountBeforeOpen + 1)
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "corpus-2")
        XCTAssertEqual(workspace.sceneGraph.sidebar.currentCorpus?.title, "Compare Corpus")
    }

    func testNewWorkspaceResetsSelectionAndSavesEmptyWorkspace() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        await workspace.newWorkspace()

        XCTAssertEqual(workspace.selectedTab, .stats)
        XCTAssertNil(workspace.sidebar.selectedCorpusID)
        XCTAssertTrue(repository.savedWorkspaceDrafts.contains(where: { draft in
            draft.currentTab == WorkspaceDetailTab.stats.snapshotValue && draft.corpusIds.isEmpty
        }))
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

    func testSaveSettingsPersistsCurrentSnapshot() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        workspace.settings.showWelcomeScreen = false
        workspace.settings.debugLogging = true

        await workspace.saveSettings()

        XCTAssertEqual(repository.savedUISettings.count, 1)
        XCTAssertEqual(repository.savedUISettings.first?.showWelcomeScreen, false)
        XCTAssertEqual(repository.savedUISettings.first?.debugLogging, true)
    }

    func testShowSelectedCorpusInfoBuildsLibraryInfoSheet() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        await workspace.handleLibraryAction(.showSelectedCorpusInfo)

        XCTAssertEqual(repository.loadCorpusInfoCallCount, 1)
        XCTAssertEqual(repository.openSavedCorpusCallCount, 0)
        XCTAssertEqual(repository.runStatsCallCount, 0)
        XCTAssertEqual(workspace.library.corpusInfoSheet?.title, "Demo Corpus")
        XCTAssertEqual(workspace.library.corpusInfoSheet?.tokenCountText, "\(repository.corpusInfoResult.tokenCount)")
        XCTAssertEqual(workspace.library.corpusInfoSheet?.typeCountText, "\(repository.corpusInfoResult.typeCount)")
        XCTAssertEqual(workspace.library.corpusInfoSheet?.encodingText, "UTF-8")
        XCTAssertEqual(workspace.library.corpusInfoSheet?.genreText, "教学")
        XCTAssertEqual(workspace.library.corpusInfoSheet?.tagsText, "课堂, 基础")
    }

    func testPerformTaskActionOpenFileUsesHostActionService() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostActionService: hostActions
        )

        await workspace.performTaskAction(.openFile(path: "/tmp/report.csv"))

        XCTAssertEqual(hostActions.openedFilePaths, ["/tmp/report.csv"])
    }

    func testPerformTaskActionOpenURLUsesHostActionService() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostActionService: hostActions
        )

        await workspace.performTaskAction(.openURL("https://example.com/release"))

        XCTAssertEqual(hostActions.openedExternalURLs, ["https://example.com/release"])
    }

    func testShutdownStopsRepository() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.shutdown()

        XCTAssertTrue(repository.stopCalled)
    }

    func testCheckForUpdatesUsesHostServicesAndUpdatesSettingsScene() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        let hostActions = FakeHostActionService()
        let updateService = FakeUpdateService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences,
            hostActionService: hostActions,
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()

        XCTAssertEqual(updateService.checkCallCount, 1)
        XCTAssertEqual(hostPreferences.recordUpdateCheckCallCount, 1)
        XCTAssertTrue(workspace.settings.scene.updateSummary.contains("发现新版本"))
        XCTAssertEqual(workspace.settings.scene.latestReleaseTitle, "WordZ 1.1.1")
        XCTAssertEqual(workspace.settings.scene.latestAssetName, "WordZ-1.1.1-mac-arm64.dmg")
        XCTAssertEqual(workspace.settings.scene.latestReleaseNotes, ["Native table layout persistence"])
    }

    func testCheckForUpdatesEmitsCompletionNotification() async {
        let repository = FakeWorkspaceRepository()
        let notificationService = FakeNotificationService()
        let notified = expectation(description: "update completion notification")
        notificationService.onNotify = { notified.fulfill() }
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: FakeUpdateService(),
            notificationService: notificationService
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()
        await fulfillment(of: [notified], timeout: 1)

        XCTAssertEqual(notificationService.notifications.count, 1)
        XCTAssertEqual(notificationService.notifications.last?.0, "检查更新")
        XCTAssertEqual(notificationService.notifications.last?.1, "已完成")
        XCTAssertTrue(notificationService.notifications.last?.2.contains("发现新版本") == true)
    }

    func testCheckForUpdatesSkipsNotificationWhenApplicationIsActiveOutsideTests() async {
        let repository = FakeWorkspaceRepository()
        let notificationService = FakeNotificationService()
        let applicationActivityInspector = FakeApplicationActivityInspector(
            isApplicationActive: true,
            shouldDeliverBackgroundNotifications: false
        )
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: FakeUpdateService(),
            notificationService: notificationService,
            applicationActivityInspector: applicationActivityInspector
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()

        XCTAssertTrue(notificationService.notifications.isEmpty)
    }

    func testConcurrentCheckForUpdatesSharesSingleInFlightRequest() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        updateService.checkDelayNanoseconds = 80_000_000
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await workspace.checkForUpdatesNow() }
            group.addTask { await workspace.checkForUpdatesNow() }
            await group.waitForAll()
        }

        XCTAssertEqual(updateService.checkCallCount, 1)
    }

    func testLaunchTriggeredUpdateCheckCanRunWithoutCancellingPendingLaunchTask() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: updateService
        )

        workspace.launchUpdateCheckTask = Task { }
        await workspace.checkForUpdatesNow(cancelPendingLaunchTask: false)

        XCTAssertEqual(updateService.checkCallCount, 1)
        XCTAssertNil(workspace.issueBanner)
        XCTAssertTrue(workspace.settings.scene.updateSummary.contains("发现新版本"))
    }

    func testLaunchTriggeredUpdateCheckPostsShowUpdateWindowWhenUpdateIsAvailable() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: updateService
        )

        let presented = expectation(description: "show update window")
        let token = NotificationCenter.default.addObserver(
            forName: .wordZMacCommandTriggered,
            object: nil,
            queue: nil
        ) { notification in
            if NativeAppCommandCenter.parse(notification) == .showUpdateWindow {
                presented.fulfill()
            }
        }
        defer { NotificationCenter.default.removeObserver(token) }

        await workspace.checkForUpdatesNow(trigger: .launch)

        await fulfillment(of: [presented], timeout: 1)
        XCTAssertNil(workspace.issueBanner)
    }

    func testLaunchTriggeredUpdateFailureDoesNotProduceIssueBanner() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        updateService.error = NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "offline"])
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            updateService: updateService
        )

        await workspace.checkForUpdatesNow(trigger: .launch)

        XCTAssertNil(workspace.issueBanner)
        XCTAssertEqual(workspace.settings.scene.supportStatus, "offline")
    }

    func testUpdateFailureEmitsFailureNotification() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        updateService.error = NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "offline"])
        let notificationService = FakeNotificationService()
        let notified = expectation(description: "update failure notification")
        notificationService.onNotify = { notified.fulfill() }
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: updateService,
            notificationService: notificationService
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()
        await fulfillment(of: [notified], timeout: 1)

        XCTAssertEqual(notificationService.notifications.count, 1)
        XCTAssertEqual(notificationService.notifications.last?.0, "检查更新")
        XCTAssertEqual(notificationService.notifications.last?.1, "失败")
        XCTAssertEqual(notificationService.notifications.last?.2, "offline")
    }

    func testAutoDownloadReusesCheckedResultWithoutSecondCheck() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        workspace.settings.autoDownloadUpdates = true
        await workspace.checkForUpdatesNow()

        XCTAssertEqual(updateService.checkCallCount, 1)
        XCTAssertEqual(updateService.downloadCallCount, 1)
        XCTAssertEqual(workspace.settings.scene.downloadedUpdateName, "WordZ-1.1.1-mac-arm64.dmg")
    }

    func testInstallLatestUpdateAndRestartHandsOffDownloadedInstaller() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        hostPreferences.snapshot.downloadedUpdateName = "WordZ-1.1.1-mac-arm64.dmg"
        hostPreferences.snapshot.downloadedUpdatePath = "/tmp/WordZ-1.1.1-mac-arm64.dmg"
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences,
            hostActionService: hostActions
        )

        await workspace.installLatestUpdateAndRestart()

        XCTAssertEqual(hostActions.openDownloadedUpdateAndTerminateCallCount, 1)
        XCTAssertEqual(hostActions.lastInstalledDownloadedUpdatePath, "/tmp/WordZ-1.1.1-mac-arm64.dmg")
    }

    func testDisableAutomaticUpdateDownloadsAndInstallPersistsPreferences() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences
        )

        workspace.settings.autoDownloadUpdates = true
        workspace.settings.autoInstallDownloadedUpdates = true

        await workspace.disableAutomaticUpdateDownloadsAndInstall()

        XCTAssertFalse(workspace.settings.autoDownloadUpdates)
        XCTAssertFalse(workspace.settings.autoInstallDownloadedUpdates)
        XCTAssertEqual(hostPreferences.saveCallCount, 1)
        XCTAssertFalse(hostPreferences.snapshot.autoDownloadUpdates)
        XCTAssertFalse(hostPreferences.snapshot.autoInstallDownloadedUpdates)
    }

    func testExportDiagnosticsWritesReportThroughHostActionService() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        hostPreferences.snapshot.recentDocuments = [
            RecentDocumentItem(
                corpusID: "corpus-1",
                title: "Demo Corpus",
                subtitle: "Default",
                representedPath: "/tmp/demo.txt",
                lastOpenedAt: "2026-04-03T00:00:00Z"
            )
        ]
        hostPreferences.snapshot.downloadedUpdatePath = "/tmp/WordZ-1.2.0-mac-arm64.dmg"
        let hostActions = FakeHostActionService()
        let diagnosticsBundleService = FakeDiagnosticsBundleService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences,
            hostActionService: hostActions,
            diagnosticsBundleService: diagnosticsBundleService
        )

        await workspace.initializeIfNeeded()
        await workspace.exportDiagnostics(preferredWindowRoute: .settings)

        XCTAssertNotNil(diagnosticsBundleService.lastPayload)
        XCTAssertTrue(diagnosticsBundleService.lastPayload?.reportText.contains("WordZMac Diagnostics") == true)
        XCTAssertTrue(diagnosticsBundleService.lastPayload?.reportText.contains("Bundle ID") == true || diagnosticsBundleService.lastPayload?.reportText.contains("Bundle Identifier") == true)
        XCTAssertTrue(diagnosticsBundleService.lastPayload?.reportText.contains("引擎入口") == true || diagnosticsBundleService.lastPayload?.reportText.contains("Engine Entry") == true)
        XCTAssertTrue(diagnosticsBundleService.lastPayload?.reportText.contains("后台任务摘要") == true || diagnosticsBundleService.lastPayload?.reportText.contains("Task Center Summary") == true)
        XCTAssertFalse(diagnosticsBundleService.lastPayload?.reportText.contains("/tmp/WordZ-1.2.0-mac-arm64.dmg") == true)
        XCTAssertEqual(diagnosticsBundleService.lastPayload?.hostPreferences.recentDocuments.first?.representedPath, "<redacted>/demo.txt")
        XCTAssertEqual(diagnosticsBundleService.lastPayload?.hostPreferences.downloadedUpdatePath, "<redacted>/WordZ-1.2.0-mac-arm64.dmg")
        XCTAssertEqual(diagnosticsBundleService.lastPayload?.generatedFiles.map(\.relativePath), [
            "persisted/workspace-state.json",
            "persisted/ui-settings.json",
            "persisted/native-host-preferences.json"
        ])
        XCTAssertEqual(hostActions.exportedDiagnosticArchivePath, "/tmp/WordZMac-diagnostics.zip")
        XCTAssertEqual(hostActions.exportedDiagnosticPreferredRoute, .settings)
        XCTAssertEqual(workspace.settings.scene.supportStatus, "已导出诊断包到 /tmp/WordZMac-diagnostics.zip")
    }

    func testExportDiagnosticsEmitsCompletionNotification() async {
        let repository = FakeWorkspaceRepository()
        let notificationService = FakeNotificationService()
        let notified = expectation(description: "diagnostics completion notification")
        notificationService.onNotify = { notified.fulfill() }
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: FakeHostActionService(),
            notificationService: notificationService,
            diagnosticsBundleService: FakeDiagnosticsBundleService()
        )

        await workspace.initializeIfNeeded()
        await workspace.exportDiagnostics()
        await fulfillment(of: [notified], timeout: 1)

        XCTAssertEqual(notificationService.notifications.count, 1)
        XCTAssertEqual(notificationService.notifications.last?.0, "导出诊断包")
        XCTAssertEqual(notificationService.notifications.last?.1, "已完成")
        XCTAssertEqual(notificationService.notifications.last?.2, "/tmp/WordZMac-diagnostics.zip")
    }

    func testExportDiagnosticsStillEmitsNotificationDuringTestsEvenWhenApplicationIsActive() async {
        let repository = FakeWorkspaceRepository()
        let notificationService = FakeNotificationService()
        let applicationActivityInspector = FakeApplicationActivityInspector(
            isApplicationActive: true,
            shouldDeliverBackgroundNotifications: true
        )
        let notified = expectation(description: "diagnostics completion notification")
        notificationService.onNotify = { notified.fulfill() }
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: FakeHostActionService(),
            notificationService: notificationService,
            applicationActivityInspector: applicationActivityInspector,
            diagnosticsBundleService: FakeDiagnosticsBundleService()
        )

        await workspace.initializeIfNeeded()
        await workspace.exportDiagnostics()
        await fulfillment(of: [notified], timeout: 1)

        XCTAssertEqual(notificationService.notifications.count, 1)
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

    func testExportCurrentReportBundleUsesArchiveExportAndTaskCenter() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let reportBundleService = FakeAnalysisReportBundleService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostActionService: hostActions,
            reportBundleService: reportBundleService
        )

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "alpha"
        await workspace.runKWIC()
        _ = await workspace.openCurrentSourceReader()
        await workspace.exportCurrentReportBundle(preferredWindowRoute: .mainWorkspace)

        XCTAssertNotNil(reportBundleService.lastPayload)
        XCTAssertTrue(reportBundleService.lastPayload?.reportText.contains("WordZ Report Bundle") == true)
        XCTAssertNotNil(reportBundleService.lastPayload?.tableSnapshot)
        XCTAssertTrue(reportBundleService.lastPayload?.textDocuments.contains(where: { $0.relativePath == "reading/source-reader-current.txt" }) == true)
        XCTAssertEqual(hostActions.exportedArchivePath, "/tmp/WordZMac-report.zip")
        XCTAssertEqual(hostActions.exportedArchiveTitle, "导出研究报告包")
        XCTAssertEqual(hostActions.exportedArchivePreferredRoute, .mainWorkspace)
        XCTAssertEqual(workspace.settings.scene.supportStatus, "已导出研究报告包到 /tmp/WordZMac-report.zip")
    }

    func testQuickLookCurrentContentUsesSelectedCorpusPathWhenNoResultSceneIsActive() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions
        )

        await workspace.initializeIfNeeded()
        await workspace.quickLookCurrentCorpus()

        XCTAssertEqual(hostActions.quickLookCallCount, 1)
        XCTAssertEqual(hostActions.lastQuickLookPath, "/tmp/demo.txt")
    }

    func testQuickLookCurrentContentBuildsTemporaryCSVForResultScene() async throws {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let previewDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-quicklook-\(UUID().uuidString)", isDirectory: true)
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            quickLookPreviewFileService: QuickLookPreviewFileService(rootDirectory: previewDirectory)
        )

        await workspace.initializeIfNeeded()
        await workspace.runStats()
        await workspace.quickLookCurrentCorpus()

        XCTAssertEqual(hostActions.quickLookCallCount, 1)
        let previewPath = try XCTUnwrap(hostActions.lastQuickLookPath)
        XCTAssertTrue(previewPath.hasSuffix(".csv"))
        let contents = try String(contentsOfFile: previewPath, encoding: .utf8)
        XCTAssertTrue(contents.contains("word-0"))
    }

    func testQuickLookCurrentContentBuildsTemporaryCSVForChiSquareScene() async throws {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let previewDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-chi-square-quicklook-\(UUID().uuidString)", isDirectory: true)
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            quickLookPreviewFileService: QuickLookPreviewFileService(rootDirectory: previewDirectory)
        )

        await workspace.initializeIfNeeded()
        workspace.chiSquare.a = "10"
        workspace.chiSquare.b = "20"
        workspace.chiSquare.c = "6"
        workspace.chiSquare.d = "14"
        await workspace.runChiSquare()
        await workspace.quickLookCurrentCorpus()

        XCTAssertEqual(hostActions.quickLookCallCount, 1)
        let previewPath = try XCTUnwrap(hostActions.lastQuickLookPath)
        XCTAssertTrue(previewPath.hasSuffix(".csv"))
        let contents = try String(contentsOfFile: previewPath, encoding: .utf8)
        XCTAssertTrue(contents.contains("section"))
        XCTAssertTrue(contents.contains("summary"))
    }

    func testShareCurrentContentBuildsTemporaryCSVForResultScene() async throws {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let previewDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-share-\(UUID().uuidString)", isDirectory: true)
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            quickLookPreviewFileService: QuickLookPreviewFileService(rootDirectory: previewDirectory)
        )

        await workspace.initializeIfNeeded()
        await workspace.runStats()
        await workspace.shareCurrentContent()

        XCTAssertEqual(hostActions.shareCallCount, 1)
        let sharedPath = try XCTUnwrap(hostActions.lastSharedPaths.first)
        XCTAssertTrue(sharedPath.hasSuffix(".csv"))
        XCTAssertTrue(try String(contentsOfFile: sharedPath, encoding: .utf8).contains("word-0"))
    }

    func testShareCurrentContentBuildsTemporaryCSVForChiSquareScene() async throws {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let previewDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-chi-square-share-\(UUID().uuidString)", isDirectory: true)
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            quickLookPreviewFileService: QuickLookPreviewFileService(rootDirectory: previewDirectory)
        )

        await workspace.initializeIfNeeded()
        workspace.chiSquare.a = "10"
        workspace.chiSquare.b = "20"
        workspace.chiSquare.c = "6"
        workspace.chiSquare.d = "14"
        await workspace.runChiSquare()
        await workspace.shareCurrentContent()

        XCTAssertEqual(hostActions.shareCallCount, 1)
        let sharedPath = try XCTUnwrap(hostActions.lastSharedPaths.first)
        XCTAssertTrue(sharedPath.hasSuffix(".csv"))
        XCTAssertTrue(try String(contentsOfFile: sharedPath, encoding: .utf8).contains("effect-summary"))
    }

    func testShareSelectedCorpusUsesSelectedCorpusPath() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions
        )

        await workspace.initializeIfNeeded()
        await workspace.shareSelectedCorpus()

        XCTAssertEqual(hostActions.shareCallCount, 1)
        XCTAssertEqual(hostActions.lastSharedPaths, ["/tmp/demo.txt"])
    }

    func testIssueBannerAppearsWhenBootstrapFails() async {
        let repository = FakeWorkspaceRepository()
        repository.startError = NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "boom"])
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()

        XCTAssertEqual(workspace.issueBanner?.title, "本地引擎启动失败")
        XCTAssertEqual(workspace.issueBanner?.message, "boom")
        XCTAssertEqual(workspace.issueBanner?.recoveryAction, .refreshWorkspace)
    }

    func testUpdateFailureProducesRetryableIssueBanner() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        updateService.error = NSError(domain: "Test", code: 2, userInfo: [NSLocalizedDescriptionKey: "offline"])
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()

        XCTAssertEqual(workspace.issueBanner?.title, "更新检查失败")
        XCTAssertTrue(workspace.issueBanner?.message.contains("offline") == true)
        XCTAssertEqual(workspace.issueBanner?.recoveryAction, .checkForUpdates)
    }

    func testCancelledUpdateCheckDoesNotProduceIssueBanner() async {
        let repository = FakeWorkspaceRepository()
        let updateService = FakeUpdateService()
        updateService.error = CancellationError()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()

        XCTAssertNil(workspace.issueBanner)
        XCTAssertEqual(workspace.settings.scene.supportStatus, "已取消检查更新。")
    }

    func testHandleExternalPathsImportsAndOpensFirstImportedCorpus() async {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            updateService: FakeUpdateService()
        )

        await workspace.initializeIfNeeded()
        await workspace.handleExternalPaths(["/tmp/a.txt", "/tmp/b.txt"])
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(repository.importCorpusPathsCallCount, 1)
        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "imported-1")
        XCTAssertFalse(workspace.isWelcomePresented)
    }

    func testClearRecentDocumentsClearsStoreAndHostRecentItems() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        hostPreferences.snapshot.recentDocuments = [
            RecentDocumentItem(
                corpusID: "corpus-1",
                title: "Demo Corpus",
                subtitle: "Default",
                representedPath: "/tmp/demo.txt",
                lastOpenedAt: "2026-03-26T00:00:00Z"
            )
        ]
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences,
            hostActionService: hostActions,
            updateService: FakeUpdateService()
        )

        await workspace.initializeIfNeeded()
        await workspace.clearRecentDocuments()

        XCTAssertEqual(hostPreferences.clearRecentCallCount, 1)
        XCTAssertEqual(hostActions.clearRecentDocumentsCallCount, 1)
        XCTAssertTrue(workspace.settings.scene.recentDocuments.isEmpty)
    }

    func testRevealDownloadedUpdateUsesHostActionService() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        let hostActions = FakeHostActionService()
        let updateService = FakeUpdateService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences,
            hostActionService: hostActions,
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()
        await workspace.downloadLatestUpdate()
        await workspace.revealDownloadedUpdate()

        XCTAssertEqual(hostActions.revealDownloadedUpdateCallCount, 1)
        XCTAssertEqual(hostActions.lastRevealedDownloadedUpdatePath, "/tmp/WordZ-1.1.1-mac-arm64.dmg")
    }
}
