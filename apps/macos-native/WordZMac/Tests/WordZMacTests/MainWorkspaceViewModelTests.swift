import XCTest
@testable import WordZWorkspaceCore

import WordZHost
import WordZShared
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

    func testInitializeIfNeededReportsWhetherInitializationRan() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        let firstInitialize = await workspace.initializeIfNeeded()
        let listLibraryCallCountAfterFirstInitialize = repository.listLibraryCallCount
        let secondInitialize = await workspace.initializeIfNeeded()

        XCTAssertTrue(firstInitialize)
        XCTAssertFalse(secondInitialize)
        XCTAssertEqual(repository.loadBootstrapStateCallCount, 1)
        XCTAssertEqual(repository.listLibraryCallCount, listLibraryCallCountAfterFirstInitialize)
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

    func testSharedLexicalSearchSyncsBetweenKWICAndWordOnTabSwitch() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()

        workspace.selectedTab = .kwic
        workspace.kwic.keyword = "abstract"
        workspace.selectedTab = .word

        XCTAssertEqual(workspace.word.query, "abstract")

        workspace.word.query = "method"
        workspace.selectedTab = .kwic

        XCTAssertEqual(workspace.kwic.keyword, "method")
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

    func testStatsRunUsesSelectedCorpusSetDatabase() async {
        let corpusSet = LibraryCorpusSetItem(json: [
            "id": "set-1",
            "name": "Merged Set",
            "corpusIds": ["corpus-1", "corpus-2"],
            "corpusNames": ["Demo Corpus", "Compare Corpus"],
            "metadataFilter": [:],
            "createdAt": "today",
            "updatedAt": "today"
        ])
        let repository = FakeWorkspaceRepository(
            bootstrapState: makeBootstrapState(corpusSets: [corpusSet])
        )
        repository.openedCorpusSetsByID["set-1"] = OpenedCorpus(json: [
            "mode": "corpus-set",
            "filePath": "/tmp/set-1.db",
            "displayName": "Merged Set",
            "content": "alpha beta gamma",
            "sourceType": "db"
        ])
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.sidebar.applyCorpusSet(corpusSet)
        workspace.library.selectCorpusSet("set-1")
        workspace.sidebar.selectedCorpusID = workspace.library.selectedCorpusID
        let openedCorpusCountBefore = repository.openSavedCorpusCallCount

        await workspace.runStats()

        XCTAssertEqual(repository.openSavedCorpusSetCallCount, 1)
        XCTAssertEqual(repository.openSavedCorpusCallCount, openedCorpusCountBefore)
        XCTAssertEqual(repository.lastRunStatsText, "alpha beta gamma")
        XCTAssertEqual(workspace.sidebar.scene.targetCorpus.summary, "Merged Set")
        XCTAssertEqual(workspace.sidebar.scene.targetCorpus.detail, "2 条语料 · 语料集")
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

    func testWorkspaceAnnotationStateSyncsAcrossPagesAndShell() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.setAnnotationProfile(.lemmaPreferred)
        workspace.toggleAnnotationScript(.latin)
        workspace.toggleAnnotationLexicalClass(.verb)

        let expectedState = WorkspaceAnnotationState(
            profile: .lemmaPreferred,
            lexicalClasses: [.verb],
            scripts: [.latin]
        )

        XCTAssertEqual(workspace.annotationState, expectedState)
        XCTAssertEqual(workspace.tokenize.annotationProfile, .lemmaPreferred)
        XCTAssertEqual(workspace.keyword.annotationProfile, .lemmaPreferred)
        XCTAssertEqual(workspace.keyword.selectedScripts, [.latin])
        XCTAssertEqual(workspace.keyword.selectedLexicalClasses, [.verb])
        XCTAssertEqual(workspace.word.annotationState, expectedState)
        XCTAssertEqual(workspace.kwic.annotationState, expectedState)
        XCTAssertEqual(workspace.topics.annotationState, expectedState)
        XCTAssertEqual(workspace.compare.annotationState, expectedState)
        XCTAssertEqual(workspace.sentiment.annotationState, expectedState)
        XCTAssertEqual(
            workspace.shell.scene.annotationSummary,
            workspace.annotationSummary(in: WordZLocalization.shared.effectiveMode)
        )
    }

    func testWorkspaceAnnotationStateDescribesFilterImpact() {
        let defaultState = WorkspaceAnnotationState.default
        let filteredState = WorkspaceAnnotationState(
            profile: .lemmaPreferred,
            lexicalClasses: [.verb, .noun],
            scripts: [.latin]
        )

        XCTAssertFalse(defaultState.hasActiveFilters)
        XCTAssertEqual(defaultState.activeFilterCount, 0)
        XCTAssertEqual(defaultState.filterSummary(in: .english), "Scripts: All · Classes: All")
        XCTAssertEqual(defaultState.impactSummary(in: .english), "All scripts and lexical classes are currently included.")

        XCTAssertTrue(filteredState.hasActiveFilters)
        XCTAssertEqual(filteredState.activeFilterCount, 3)
        XCTAssertEqual(filteredState.filterSummary(in: .english), "Scripts: Latin · Classes: Noun, Verb")
        XCTAssertTrue(filteredState.impactSummary(in: .english).contains("before candidate generation"))
        XCTAssertTrue(filteredState.emptyResultHint(in: .english).contains("too narrow"))
    }

    func testSourceReaderExportIncludesAnnotationSummaryAndTokenAnnotations() async throws {
        let repository = FakeWorkspaceRepository(
            tokenizeResult: makeTokenizeResult(),
            kwicResult: KWICResult(rows: [
                KWICRow(id: "1-1", left: "Delta", node: "alpha", right: "", sentenceId: 1, sentenceTokenIndex: 1)
            ])
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.setAnnotationProfile(.lemmaPreferred)
        workspace.toggleAnnotationScript(.latin)
        workspace.toggleAnnotationLexicalClass(.noun)
        workspace.kwic.keyword = "alpha"
        await workspace.runKWIC()
        workspace.kwic.selectedRowID = "1-1"

        let opened = await workspace.openCurrentSourceReader()
        let export = try XCTUnwrap(workspace.sourceReader.currentReadingExportDocument)
        let annotationItems = try XCTUnwrap(workspace.sourceReader.scene?.selection?.annotationItems)

        XCTAssertTrue(opened)
        XCTAssertEqual(annotationItems.map(\.id), ["lemma", "lexical-class", "script"])
        XCTAssertEqual(annotationItems.first?.value, "alpha")
        XCTAssertTrue(export.text.contains("Source Text"))
        XCTAssertTrue(export.text.contains("Corpus: Demo Corpus"))
        XCTAssertTrue(export.text.contains("Annotation: \(workspace.annotationState.summary(in: .system))"))
        XCTAssertTrue(export.text.contains("Full Source Sentence"))
        XCTAssertTrue(export.text.contains("Delta alpha."))
    }

    func testQuickLookSourceReaderContentBuildsDBTextPreviewBeforeOriginalFile() async throws {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-source-reader-quicklook-\(UUID().uuidString)", isDirectory: true)
        let sourceURL = rootURL.appendingPathComponent("original.txt")
        let previewURL = rootURL.appendingPathComponent("preview", isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        try "This is the external original file.".write(to: sourceURL, atomically: true, encoding: .utf8)
        let repository = FakeWorkspaceRepository(
            corpusInfoResult: CorpusInfoSummary(json: [
                "corpusId": "corpus-1",
                "title": "Demo Corpus",
                "folderName": "Default",
                "sourceType": "txt",
                "representedPath": sourceURL.path,
                "detectedEncoding": "UTF-8",
                "importedAt": "2026-04-03T00:00:00Z",
                "fileCount": 1,
                "tokenCount": 30,
                "typeCount": 12,
                "sentenceCount": 6,
                "paragraphCount": 3,
                "characterCount": 180
            ]),
            tokenizeResult: makeTokenizeResult(),
            kwicResult: KWICResult(rows: [
                KWICRow(id: "1-1", left: "Delta", node: "alpha", right: "", sentenceId: 1, sentenceTokenIndex: 1)
            ])
        )
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostActionService: hostActions,
            quickLookPreviewFileService: QuickLookPreviewFileService(rootDirectory: previewURL)
        )

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "alpha"
        await workspace.runKWIC()
        workspace.kwic.selectedRowID = "1-1"
        let opened = await workspace.openCurrentSourceReader()
        XCTAssertTrue(opened)

        await workspace.quickLookSourceReaderContent()

        XCTAssertEqual(hostActions.quickLookCallCount, 1)
        let previewPath = try XCTUnwrap(hostActions.lastQuickLookPath)
        XCTAssertNotEqual(previewPath, sourceURL.path)
        XCTAssertTrue(previewPath.hasSuffix(".txt"))
        let previewText = try String(contentsOfFile: previewPath, encoding: .utf8)
        XCTAssertTrue(previewText.contains("Source Text"))
        XCTAssertTrue(previewText.contains("Corpus: Demo Corpus"))
        XCTAssertTrue(previewText.contains("Full Source Sentence"))
        XCTAssertEqual(workspace.settings.scene.supportStatus, "已打开来源文本预览。")
    }

    func testCopySourceReaderCitationUsesCurrentCitation() async {
        let repository = FakeWorkspaceRepository(
            tokenizeResult: makeTokenizeResult(),
            kwicResult: KWICResult(rows: [
                KWICRow(id: "1-1", left: "Delta", node: "alpha", right: "", sentenceId: 1, sentenceTokenIndex: 1)
            ])
        )
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostActionService: hostActions
        )

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "alpha"
        await workspace.runKWIC()
        workspace.kwic.selectedRowID = "1-1"
        _ = await workspace.openCurrentSourceReader()

        workspace.copySourceReaderCitation()

        XCTAssertEqual(hostActions.copiedClipboardTexts.last, workspace.sourceReader.currentCitationText)
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
        XCTAssertTrue(text.contains("方向: Positive") || text.contains("方向: 正关键词"))
        XCTAssertTrue(text.contains("示例: alpha example"))
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
        XCTAssertEqual(
            workspace.shell.scene.toolbar.items.first(where: { $0.action == .copyCurrentResult })?.isEnabled,
            false
        )

        await workspace.runStats()

        XCTAssertEqual(workspace.sidebar.scene.results?.title, workspace.sceneGraph.stats.title)
        XCTAssertEqual(workspace.sidebar.scene.results?.subtitle, workspace.sceneGraph.stats.status)
        XCTAssertEqual(
            workspace.shell.scene.toolbar.items.first(where: { $0.action == .exportCurrent })?.isEnabled,
            true
        )
        XCTAssertEqual(
            workspace.shell.scene.toolbar.items.first(where: { $0.action == .copyCurrentResult })?.isEnabled,
            true
        )
        XCTAssertTrue(workspace.commandContext(for: .mainWorkspace).canCopyCurrentResult)
    }

    func testCurrentResultArtifactIsNilForEmptyResultAndExportsStatsTables() async throws {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        XCTAssertNil(workspace.currentResultArtifact)

        await workspace.runStats()

        let artifact = try XCTUnwrap(workspace.currentResultArtifact)
        XCTAssertEqual(artifact.sourceTab, .stats)
        XCTAssertEqual(artifact.title, workspace.sceneGraph.stats.title)
        XCTAssertNotNil(artifact.exportSnapshot)
        XCTAssertNil(artifact.textDocument)
        XCTAssertTrue(artifact.supports(.copy))
        XCTAssertTrue(artifact.supports(.preview))
        XCTAssertTrue(artifact.supports(.export))
        XCTAssertTrue(artifact.supports(.share))
        XCTAssertFalse(artifact.supports(.openSourceReader))
        XCTAssertEqual(
            artifact.actionDescriptors(in: .english).map(\.action),
            [.copy, .preview, .export, .share]
        )
        XCTAssertEqual(artifact.actionDescriptors(in: .english).first?.title, "Copy Table")
    }

    func testCurrentResultArtifactPrefersTokenizeTextDocument() async throws {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.tokenize.apply(makeWorkspaceSnapshot(currentTab: "tokenize", searchQuery: ""))
        workspace.tokenize.apply(makeTokenizeResult())
        workspace.selectedTab = .tokenize
        workspace.syncSceneGraph()

        let artifact = try XCTUnwrap(workspace.currentResultArtifact)
        XCTAssertEqual(artifact.sourceTab, .tokenize)
        XCTAssertNil(artifact.exportSnapshot)
        XCTAssertTrue(try XCTUnwrap(artifact.textDocument).text.contains("alpha beta gamma"))
        XCTAssertTrue(artifact.supports(.copy))
        XCTAssertTrue(workspace.hasExportableCurrentContent(in: workspace.sceneGraph, selectedTab: .tokenize))
    }

    func testCopyCurrentResultArtifactCopiesTSVForExcelPaste() async throws {
        let repository = FakeWorkspaceRepository()
        let hostActions = FakeHostActionService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostActionService: hostActions
        )

        await workspace.initializeIfNeeded()
        await workspace.runStats()

        let handled = await workspace.performResultArtifactAction(.copy)

        XCTAssertTrue(handled)
        let payload = try XCTUnwrap(hostActions.copiedClipboardTexts.last)
        XCTAssertTrue(payload.contains("\t"))
        XCTAssertTrue(payload.contains("word-0"))
        XCTAssertTrue(workspace.settings.scene.supportStatus.contains("Excel"))
    }

    func testExportCurrentUsesCurrentResultArtifactForTokenizeText() async throws {
        let repository = FakeWorkspaceRepository()
        let dialogService = FakeDialogService()
        let exportURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("wordz-tokenize-artifact-\(UUID().uuidString).txt")
        dialogService.savePathResult = exportURL.path
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.tokenize.apply(makeWorkspaceSnapshot(currentTab: "tokenize", searchQuery: ""))
        workspace.tokenize.apply(makeTokenizeResult())
        workspace.selectedTab = .tokenize
        workspace.syncSceneGraph()
        await workspace.exportCurrent(preferredWindowRoute: .mainWorkspace)

        let contents = try String(contentsOf: exportURL, encoding: .utf8)
        XCTAssertEqual(contents, "alpha beta gamma\ndelta alpha\n")
        XCTAssertEqual(dialogService.savePathPreferredRoute, .mainWorkspace)
    }

    func testCurrentResultArtifactExposesReaderCapabilityForKWIC() async throws {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "alpha"
        await workspace.runKWIC()

        let artifact = try XCTUnwrap(workspace.currentResultArtifact)
        XCTAssertEqual(artifact.sourceTab, .kwic)
        XCTAssertTrue(artifact.supports(.openSourceReader))
        XCTAssertEqual(
            artifact.actionDescriptors(in: .english).map(\.action),
            [.copy, .preview, .export, .share, .openSourceReader]
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
        XCTAssertEqual(workspace.settings.scene.recentDocuments.first?.subtitle, "Demo Corpus.db · Default")
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
        XCTAssertEqual(workspace.library.corpusInfoSheet?.fileCountText, "\(repository.corpusInfoResult.fileCount)")
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

    func testCheckForUpdatesDoesNotCallServiceWhenAPIIsDisabled() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        hostPreferences.snapshot.apiAccessEnabled = false
        let updateService = FakeUpdateService()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences,
            updateService: updateService
        )

        await workspace.initializeIfNeeded()
        await workspace.checkForUpdatesNow()

        XCTAssertEqual(updateService.checkCallCount, 0)
        XCTAssertEqual(hostPreferences.recordUpdateCheckCallCount, 0)
        XCTAssertTrue(workspace.settings.scene.updateSummary.contains("联网 API 已关闭"))
        XCTAssertNil(workspace.issueBanner)
    }

    func testAPICredentialActionsUseCredentialStoreWithoutPersistingSecretInPreferences() async {
        let repository = FakeWorkspaceRepository()
        let credentialStore = InMemoryAPICredentialStore()
        let hostPreferences = InMemoryHostPreferencesStore()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences,
            apiCredentialStore: credentialStore
        )

        await workspace.initializeIfNeeded()
        workspace.settings.apiCredentialDraft = "  token-123  "
        await workspace.saveAPICredential()

        XCTAssertEqual(credentialStore.saveCallCount, 1)
        XCTAssertEqual(credentialStore.credential, "token-123")
        XCTAssertTrue(workspace.settings.scene.apiCredentialConfigured)
        XCTAssertTrue(workspace.settings.apiCredentialDraft.isEmpty)
        XCTAssertNil(hostPreferences.snapshot.lastUpdateStatus.range(of: "token-123"))

        await workspace.clearAPICredential()

        XCTAssertEqual(credentialStore.clearCallCount, 1)
        XCTAssertFalse(workspace.settings.scene.apiCredentialConfigured)
    }

    func testAPIConnectionCheckUsesSavedCredentialAndUpdatesSettingsScene() async {
        let repository = FakeWorkspaceRepository()
        let credentialStore = InMemoryAPICredentialStore()
        credentialStore.credential = "token-abc"
        let connectionTester = FakeAPIConnectionTester()
        connectionTester.result = NativeAPIConnectionTestResult(
            statusCode: 200,
            durationMilliseconds: 64,
            attemptCount: 1,
            endpointHost: "api.example.test"
        )
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            apiCredentialStore: credentialStore,
            apiConnectionTester: connectionTester
        )

        await workspace.initializeIfNeeded()
        workspace.settings.apiRequestTimeoutSeconds = 15
        workspace.settings.apiMaxConcurrentRequests = 3
        await workspace.testAPIConnection()

        XCTAssertEqual(connectionTester.testCallCount, 1)
        XCTAssertEqual(connectionTester.lastCredential, "token-abc")
        XCTAssertEqual(connectionTester.lastTimeoutSeconds, 15)
        XCTAssertEqual(connectionTester.lastMaxConcurrentRequests, 3)
        XCTAssertTrue(workspace.settings.scene.apiCredentialStatus.contains("API 连接正常"))
        XCTAssertTrue(workspace.settings.scene.apiCredentialStatus.contains("api.example.test"))
        XCTAssertFalse(workspace.settings.scene.apiCredentialStatus.contains("token-abc"))
        XCTAssertNil(workspace.issueBanner)
    }

    func testAPIConnectionCheckDoesNotRunWhenAPIIsDisabled() async {
        let repository = FakeWorkspaceRepository()
        let hostPreferences = InMemoryHostPreferencesStore()
        hostPreferences.snapshot.apiAccessEnabled = false
        let connectionTester = FakeAPIConnectionTester()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: hostPreferences,
            apiConnectionTester: connectionTester
        )

        await workspace.initializeIfNeeded()
        await workspace.testAPIConnection()

        XCTAssertEqual(connectionTester.testCallCount, 0)
        XCTAssertTrue(workspace.settings.scene.apiCredentialStatus.contains("联网 API 已关闭"))
        XCTAssertNil(workspace.issueBanner)
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
        XCTAssertTrue(diagnosticsBundleService.lastPayload?.reportText.contains("Analysis Runtime") == true)
        XCTAssertTrue(diagnosticsBundleService.lastPayload?.reportText.contains("后台任务摘要") == true || diagnosticsBundleService.lastPayload?.reportText.contains("Background Task Summary") == true)
        XCTAssertFalse(diagnosticsBundleService.lastPayload?.reportText.contains("/tmp/WordZ-1.2.0-mac-arm64.dmg") == true)
        XCTAssertEqual(diagnosticsBundleService.lastPayload?.hostPreferences.recentDocuments.first?.representedPath, "<redacted>/demo.txt")
        XCTAssertEqual(diagnosticsBundleService.lastPayload?.hostPreferences.downloadedUpdatePath, "<redacted>/WordZ-1.2.0-mac-arm64.dmg")
        XCTAssertEqual(diagnosticsBundleService.lastPayload?.generatedFiles.map(\.relativePath), [
            "persisted/workspace-snapshot.json",
            "persisted/ui-settings.json",
            "persisted/native-host-preferences.json",
            "storage-snapshot.json"
        ])
        XCTAssertEqual(hostActions.exportedDiagnosticArchivePath, "/tmp/WordZMac-diagnostics.zip")
        XCTAssertEqual(hostActions.exportedDiagnosticPreferredRoute, .settings)
        XCTAssertEqual(workspace.settings.scene.supportStatus, "已导出诊断信息到 /tmp/WordZMac-diagnostics.zip")
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
        XCTAssertEqual(notificationService.notifications.last?.0, "导出诊断信息")
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
        XCTAssertTrue(reportBundleService.lastPayload?.reportText.contains("WordZ Analysis Materials Bundle") == true)
        XCTAssertNotNil(reportBundleService.lastPayload?.tableSnapshot)
        XCTAssertTrue(reportBundleService.lastPayload?.textDocuments.contains(where: { $0.relativePath == "reading/source-reader-current.txt" }) == true)
        XCTAssertEqual(hostActions.exportedArchivePath, "/tmp/WordZMac-report.zip")
        XCTAssertEqual(hostActions.exportedArchiveTitle, "导出分析材料包")
        XCTAssertEqual(hostActions.exportedArchivePreferredRoute, .mainWorkspace)
        XCTAssertEqual(workspace.settings.scene.supportStatus, "已导出分析材料包到 /tmp/WordZMac-report.zip")
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

    func testQuickLookCurrentContentBuildsTextPreviewWhenOpenedCorpusPathIsDatabase() async throws {
        let repository = FakeWorkspaceRepository(openedCorpus: OpenedCorpus(json: [
            "mode": "saved",
            "filePath": "/tmp/demo.db",
            "displayName": "Demo Corpus",
            "content": "alpha beta gamma alpha beta",
            "sourceType": "txt"
        ]))
        let hostActions = FakeHostActionService()
        let previewDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-current-corpus-preview-\(UUID().uuidString)", isDirectory: true)
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            quickLookPreviewFileService: QuickLookPreviewFileService(rootDirectory: previewDirectory)
        )

        await workspace.initializeIfNeeded()
        await workspace.openSelectedCorpus()
        await workspace.quickLookCurrentCorpus()

        XCTAssertEqual(hostActions.quickLookCallCount, 1)
        let previewPath = try XCTUnwrap(hostActions.lastQuickLookPath)
        XCTAssertNotEqual(previewPath, "/tmp/demo.db")
        XCTAssertTrue(previewPath.hasSuffix(".txt"))
        let previewText = try String(contentsOfFile: previewPath, encoding: .utf8)
        XCTAssertTrue(previewText.contains("Corpus Text") || previewText.contains("语料文本"))
        XCTAssertTrue(previewText.contains("Demo Corpus"))
        XCTAssertTrue(previewText.contains("alpha beta gamma alpha beta"))
    }

    func testQuickLookSelectedCorpusKeepsReadableLibraryPathBeforeOpenedDatabasePreview() async throws {
        let textCorpus = LibraryCorpusItem(json: [
            "id": "corpus-text",
            "name": "Readable Corpus",
            "folderId": "folder-1",
            "folderName": "Default",
            "sourceType": "txt",
            "representedPath": "/tmp/readable.txt",
            "metadata": [:]
        ])
        let bootstrapState = makeBootstrapState(corpora: [textCorpus])
        let repository = FakeWorkspaceRepository(bootstrapState: bootstrapState)
        let hostActions = FakeHostActionService()
        let sessionStore = WorkspaceSessionStore()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            sessionStore: sessionStore
        )

        await workspace.initializeIfNeeded()
        sessionStore.setOpenedCorpus(OpenedCorpus(json: [
            "mode": "saved",
            "filePath": "/tmp/internal.db",
            "displayName": "Readable Corpus",
            "content": "opened database text",
            "sourceType": "txt"
        ]), sourceID: "corpus-text")

        await workspace.quickLookSelectedCorpus()

        XCTAssertEqual(hostActions.quickLookCallCount, 1)
        XCTAssertEqual(hostActions.lastQuickLookPath, "/tmp/readable.txt")
        XCTAssertEqual(repository.openSavedCorpusCallCount, 0)
    }

    func testQuickLookSelectedCorpusBuildsTextPreviewWhenLibraryPathIsDatabase() async throws {
        let databaseCorpus = LibraryCorpusItem(json: [
            "id": "corpus-db",
            "name": "DB Backed Corpus",
            "folderId": "folder-1",
            "folderName": "Default",
            "sourceType": "txt",
            "representedPath": "/tmp/demo.db",
            "metadata": [:]
        ])
        let bootstrapState = makeBootstrapState(corpora: [databaseCorpus])
        let repository = FakeWorkspaceRepository(
            bootstrapState: bootstrapState,
            openedCorporaByID: [
                "corpus-db": OpenedCorpus(json: [
                    "mode": "saved",
                    "filePath": "/tmp/demo.db",
                    "displayName": "DB Backed Corpus",
                    "content": "library quicklook text",
                    "sourceType": "txt"
                ])
            ]
        )
        let hostActions = FakeHostActionService()
        let previewDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("wordz-selected-corpus-preview-\(UUID().uuidString)", isDirectory: true)
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            hostActionService: hostActions,
            quickLookPreviewFileService: QuickLookPreviewFileService(rootDirectory: previewDirectory)
        )

        await workspace.initializeIfNeeded()
        await workspace.quickLookSelectedCorpus()

        XCTAssertEqual(hostActions.quickLookCallCount, 1)
        let previewPath = try XCTUnwrap(hostActions.lastQuickLookPath)
        XCTAssertNotEqual(previewPath, "/tmp/demo.db")
        XCTAssertTrue(previewPath.hasSuffix(".txt"))
        let previewText = try String(contentsOfFile: previewPath, encoding: .utf8)
        XCTAssertTrue(previewText.contains("DB Backed Corpus"))
        XCTAssertTrue(previewText.contains("library quicklook text"))
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

    func testConfirmImportPreflightCreatesNamedMergedDBCorpus() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            hostPreferencesStore: InMemoryHostPreferencesStore(),
            updateService: FakeUpdateService()
        )

        await workspace.initializeIfNeeded()
        workspace.library.presentImportPreflight(
            paths: ["/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt"],
            preserveHierarchy: true
        )

        await workspace.handleLibraryAction(
            .confirmImportPreflight(
                paths: ["/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt"],
                corpusName: "dbA"
            )
        )
        try? await Task.sleep(nanoseconds: 80_000_000)

        XCTAssertEqual(repository.importMergedCorpusPathsCallCount, 1)
        XCTAssertEqual(repository.importCorpusPathsCallCount, 0)
        XCTAssertEqual(repository.lastMergedImportPaths, ["/tmp/a.txt", "/tmp/b.txt", "/tmp/c.txt"])
        XCTAssertEqual(repository.lastMergedImportName, "dbA")
        XCTAssertEqual(repository.openSavedCorpusCallCount, 1)
        XCTAssertEqual(workspace.sidebar.selectedCorpusID, "merged-1")
        XCTAssertNil(workspace.library.importPreflightSheet)
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
