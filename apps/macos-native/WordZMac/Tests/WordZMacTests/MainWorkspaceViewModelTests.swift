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
        XCTAssertTrue(export.text.contains("Annotation: \(workspace.annotationState.summary(in: .system))"))
        XCTAssertTrue(export.text.contains("Full Sentence"))
        XCTAssertTrue(export.text.contains("Delta alpha."))
    }

    func testCaptureCurrentSourceReaderEvidenceItemPersistsDossierDraft() async {
        let repository = FakeWorkspaceRepository(
            tokenizeResult: makeTokenizeResult(),
            kwicResult: KWICResult(rows: [
                KWICRow(id: "1-1", left: "Delta", node: "alpha", right: "", sentenceId: 1, sentenceTokenIndex: 1)
            ])
        )
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.kwic.keyword = "alpha"
        await workspace.runKWIC()
        workspace.kwic.selectedRowID = "1-1"
        _ = await workspace.openCurrentSourceReader()

        workspace.sourceReader.captureSectionTitle = "Section A"
        workspace.sourceReader.captureClaim = "Alpha illustrates the target pattern."
        workspace.sourceReader.captureTagsText = "teaching, alpha, teaching"
        workspace.sourceReader.captureNote = "Use for the introduction."

        await workspace.captureCurrentSourceReaderEvidenceItem()

        XCTAssertEqual(repository.evidenceItems.first?.sectionTitle, "Section A")
        XCTAssertEqual(repository.evidenceItems.first?.claim, "Alpha illustrates the target pattern.")
        XCTAssertEqual(repository.evidenceItems.first?.tags, ["teaching", "alpha"])
        XCTAssertEqual(repository.evidenceItems.first?.note, "Use for the introduction.")
    }

    func testCaptureCurrentSourceReaderEvidenceItemFromPlotPersistsPlotSource() async {
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
        _ = await workspace.openCurrentSourceReader()

        workspace.sourceReader.captureSectionTitle = "Plot Section"
        await workspace.captureCurrentSourceReaderEvidenceItem()

        XCTAssertEqual(repository.evidenceItems.first?.sourceKind, .plot)
        XCTAssertEqual(repository.evidenceItems.first?.sentenceId, 1)
        XCTAssertEqual(repository.evidenceItems.first?.sectionTitle, "Plot Section")
        XCTAssertEqual(repository.evidenceItems.first?.keyword, "alpha")
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
            workspace.evidenceWorkbench.citationFormatDraft = .fullSentence
            workspace.evidenceWorkbench.citationStyleDraft = .apa
            workspace.evidenceWorkbench.noteDraft = "reviewed sentence"
            await workspace.saveSelectedEvidenceNote()
        }

        XCTAssertEqual(repository.evidenceItems.first?.reviewStatus, .keep)
        XCTAssertEqual(repository.evidenceItems.first?.citationFormat, .fullSentence)
        XCTAssertEqual(repository.evidenceItems.first?.citationStyle, .apa)
        XCTAssertEqual(repository.evidenceItems.first?.note, "reviewed sentence")
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItem?.citationFormat, .fullSentence)
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItem?.citationStyle, .apa)
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

    func testMoveSelectedEvidenceItemPersistsManualDossierOrder() async {
        let repository = FakeWorkspaceRepository()
        let first = makeEvidenceItem(
            id: "evidence-keep-1",
            sourceKind: .kwic,
            reviewStatus: .keep,
            sectionTitle: "Section A"
        )
        let hidden = makeEvidenceItem(
            id: "evidence-pending-1",
            sourceKind: .locator,
            reviewStatus: .pending,
            sectionTitle: "Section Hidden"
        )
        let second = makeEvidenceItem(
            id: "evidence-keep-2",
            sourceKind: .topics,
            reviewStatus: .keep,
            sectionTitle: "Section B"
        )
        repository.evidenceItems = [first, hidden, second]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.reviewFilter = .keep
        workspace.evidenceWorkbench.selectedItemID = first.id

        await workspace.moveSelectedEvidenceItem(.down)

        XCTAssertEqual(repository.replaceEvidenceItemsCallCount, 1)
        XCTAssertEqual(repository.evidenceItems.map(\.id), [second.id, hidden.id, first.id])
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItemID, first.id)
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItem?.id, first.id)
    }

    func testMoveSelectedEvidenceGroupPersistsManualSectionOrder() async {
        let repository = FakeWorkspaceRepository()
        let first = makeEvidenceItem(
            id: "evidence-section-a-1",
            sourceKind: .kwic,
            reviewStatus: .keep,
            sectionTitle: "Section A"
        )
        let hidden = makeEvidenceItem(
            id: "evidence-section-hidden-1",
            sourceKind: .locator,
            reviewStatus: .pending,
            sectionTitle: "Section Hidden"
        )
        let second = makeEvidenceItem(
            id: "evidence-section-b-1",
            sourceKind: .topics,
            reviewStatus: .keep,
            sectionTitle: "Section B"
        )
        let third = makeEvidenceItem(
            id: "evidence-section-b-2",
            sourceKind: .plot,
            reviewStatus: .keep,
            sectionTitle: "Section B"
        )
        repository.evidenceItems = [first, hidden, second, third]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.reviewFilter = .keep
        workspace.evidenceWorkbench.groupingMode = .section
        workspace.evidenceWorkbench.selectedItemID = second.id

        await workspace.moveSelectedEvidenceGroup(.up)

        XCTAssertEqual(repository.replaceEvidenceItemsCallCount, 1)
        XCTAssertEqual(repository.evidenceItems.map(\.id), [second.id, hidden.id, third.id, first.id])
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItemID, second.id)
        XCTAssertEqual(workspace.evidenceWorkbench.selectedGroup(in: .system)?.title, "Section B")
    }

    func testMoveEvidenceGroupUsesStableSidebarGroupIDAndPreservesExistingSelection() async throws {
        let repository = FakeWorkspaceRepository()
        let unsectioned = makeEvidenceItem(
            id: "evidence-unsectioned-1",
            sourceKind: .kwic,
            reviewStatus: .keep,
            sectionTitle: nil
        )
        let selected = makeEvidenceItem(
            id: "evidence-section-b-1",
            sourceKind: .topics,
            reviewStatus: .keep,
            sectionTitle: "Section B"
        )
        repository.evidenceItems = [unsectioned, selected]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.reviewFilter = .keep
        workspace.evidenceWorkbench.groupingMode = .section
        workspace.evidenceWorkbench.selectedItemID = selected.id
        let englishGroupID = try XCTUnwrap(
            workspace.evidenceWorkbench.groupedItems(in: .english).first?.id
        )

        await workspace.moveEvidenceGroup(englishGroupID, direction: .down)

        XCTAssertEqual(repository.replaceEvidenceItemsCallCount, 1)
        XCTAssertEqual(repository.evidenceItems.map(\.id), [selected.id, unsectioned.id])
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItemID, selected.id)
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItem?.id, selected.id)
    }

    func testMoveEvidenceGroupToDropTargetPersistsDraggedOrderingAndSelection() async {
        let repository = FakeWorkspaceRepository()
        let first = makeEvidenceItem(
            id: "evidence-section-a-1",
            sourceKind: .kwic,
            reviewStatus: .keep,
            sectionTitle: "Section A"
        )
        let hidden = makeEvidenceItem(
            id: "evidence-section-hidden-1",
            sourceKind: .locator,
            reviewStatus: .pending,
            sectionTitle: "Section Hidden"
        )
        let selected = makeEvidenceItem(
            id: "evidence-section-b-1",
            sourceKind: .topics,
            reviewStatus: .keep,
            sectionTitle: "Section B"
        )
        let target = makeEvidenceItem(
            id: "evidence-section-c-1",
            sourceKind: .plot,
            reviewStatus: .keep,
            sectionTitle: "Section C"
        )
        repository.evidenceItems = [first, hidden, selected, target]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.reviewFilter = .keep
        workspace.evidenceWorkbench.groupingMode = .section
        workspace.evidenceWorkbench.selectedItemID = selected.id

        await workspace.moveEvidenceGroup(
            "section:Section A",
            to: "section:Section C",
            placement: .after
        )

        XCTAssertEqual(repository.replaceEvidenceItemsCallCount, 1)
        XCTAssertEqual(repository.evidenceItems.map(\.id), [selected.id, hidden.id, target.id, first.id])
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItemID, selected.id)
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItem?.id, selected.id)
    }

    func testAssignEvidenceItemToSectionGroupPersistsMetadataAndSelection() async throws {
        let repository = FakeWorkspaceRepository()
        let dragged = makeEvidenceItem(
            id: "evidence-unsectioned-1",
            sourceKind: .kwic,
            reviewStatus: .keep,
            sectionTitle: nil
        )
        let hidden = makeEvidenceItem(
            id: "evidence-section-hidden-1",
            sourceKind: .locator,
            reviewStatus: .pending,
            sectionTitle: "Section Hidden"
        )
        let selected = makeEvidenceItem(
            id: "evidence-section-b-1",
            sourceKind: .topics,
            reviewStatus: .keep,
            sectionTitle: "Section B"
        )
        let target = makeEvidenceItem(
            id: "evidence-section-c-1",
            sourceKind: .plot,
            reviewStatus: .keep,
            sectionTitle: "Section C"
        )
        repository.evidenceItems = [dragged, hidden, selected, target]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.reviewFilter = .keep
        workspace.evidenceWorkbench.groupingMode = .section
        workspace.evidenceWorkbench.selectedItemID = selected.id

        await workspace.assignEvidenceItem(
            dragged.id,
            to: "section:Section C"
        )

        XCTAssertEqual(repository.replaceEvidenceItemsCallCount, 1)
        XCTAssertEqual(repository.evidenceItems.map(\.id), [selected.id, hidden.id, target.id, dragged.id])
        XCTAssertEqual(
            repository.evidenceItems.first(where: { $0.id == dragged.id })?.sectionTitle,
            "Section C"
        )
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItemID, selected.id)
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItem?.id, selected.id)
    }

    func testAssignEvidenceItemToUnclaimedGroupClearsClaim() async throws {
        let repository = FakeWorkspaceRepository()
        let dragged = makeEvidenceItem(
            id: "evidence-claim-a-1",
            sourceKind: .kwic,
            reviewStatus: .keep,
            claim: "Claim A"
        )
        let target = makeEvidenceItem(
            id: "evidence-unclaimed-1",
            sourceKind: .topics,
            reviewStatus: .keep,
            claim: nil
        )
        repository.evidenceItems = [dragged, target]
        let workspace = makeMainWorkspaceViewModel(repository: repository)

        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.reviewFilter = .keep
        workspace.evidenceWorkbench.groupingMode = .claim
        workspace.evidenceWorkbench.selectedItemID = dragged.id

        await workspace.assignEvidenceItem(
            dragged.id,
            to: "claim:__unclaimed__"
        )

        XCTAssertEqual(repository.replaceEvidenceItemsCallCount, 1)
        XCTAssertNil(repository.evidenceItems.last?.claim)
        XCTAssertEqual(repository.evidenceItems.map(\.id), [target.id, dragged.id])
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItemID, dragged.id)
    }

    func testCreateGroupAndAssignEvidenceItemPersistsNewSectionAndPromptRoute() async throws {
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "Section Z"

        let repository = FakeWorkspaceRepository()
        let dragged = makeEvidenceItem(
            id: "evidence-unsectioned-1",
            sourceKind: .kwic,
            reviewStatus: .keep,
            sectionTitle: nil
        )
        let hidden = makeEvidenceItem(
            id: "evidence-section-hidden-1",
            sourceKind: .locator,
            reviewStatus: .pending,
            sectionTitle: "Section Hidden"
        )
        let selected = makeEvidenceItem(
            id: "evidence-section-b-1",
            sourceKind: .topics,
            reviewStatus: .keep,
            sectionTitle: "Section B"
        )
        repository.evidenceItems = [dragged, hidden, selected]
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.reviewFilter = .keep
        workspace.evidenceWorkbench.groupingMode = .section
        workspace.evidenceWorkbench.selectedItemID = selected.id

        await workspace.createGroupAndAssignEvidenceItem(
            dragged.id,
            preferredWindowRoute: .evidenceWorkbench
        )

        XCTAssertEqual(repository.replaceEvidenceItemsCallCount, 1)
        XCTAssertEqual(repository.evidenceItems.map(\.id), [selected.id, hidden.id, dragged.id])
        XCTAssertEqual(
            repository.evidenceItems.last?.sectionTitle,
            "Section Z"
        )
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItemID, selected.id)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .evidenceWorkbench)
    }

    func testRenameSelectedEvidenceGroupPersistsAcrossHiddenItemsAndPromptRoute() async throws {
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "Methods"

        let repository = FakeWorkspaceRepository()
        let visible = makeEvidenceItem(
            id: "evidence-section-a-1",
            sourceKind: .kwic,
            reviewStatus: .keep,
            sectionTitle: "Section A"
        )
        let hidden = makeEvidenceItem(
            id: "evidence-section-a-2",
            sourceKind: .locator,
            reviewStatus: .pending,
            sectionTitle: "Section A"
        )
        let target = makeEvidenceItem(
            id: "evidence-section-b-1",
            sourceKind: .topics,
            reviewStatus: .keep,
            sectionTitle: "Section B"
        )
        repository.evidenceItems = [visible, hidden, target]
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.reviewFilter = .keep
        workspace.evidenceWorkbench.groupingMode = .section
        workspace.evidenceWorkbench.selectedItemID = visible.id

        await workspace.renameSelectedEvidenceGroup(
            preferredWindowRoute: .evidenceWorkbench
        )

        XCTAssertEqual(repository.replaceEvidenceItemsCallCount, 1)
        XCTAssertEqual(repository.evidenceItems.map(\.id), [visible.id, hidden.id, target.id])
        XCTAssertEqual(repository.evidenceItems[0].sectionTitle, "Methods")
        XCTAssertEqual(repository.evidenceItems[1].sectionTitle, "Methods")
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItemID, visible.id)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .evidenceWorkbench)
    }

    func testMergeSelectedEvidenceGroupPersistsTargetPositionAndPromptRoute() async throws {
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "Section C"

        let repository = FakeWorkspaceRepository()
        let source = makeEvidenceItem(
            id: "evidence-section-a-1",
            sourceKind: .kwic,
            reviewStatus: .keep,
            sectionTitle: "Section A"
        )
        let hiddenSource = makeEvidenceItem(
            id: "evidence-section-a-2",
            sourceKind: .locator,
            reviewStatus: .pending,
            sectionTitle: "Section A"
        )
        let target = makeEvidenceItem(
            id: "evidence-section-c-1",
            sourceKind: .plot,
            reviewStatus: .keep,
            sectionTitle: "Section C"
        )
        let trailing = makeEvidenceItem(
            id: "evidence-section-d-1",
            sourceKind: .topics,
            reviewStatus: .keep,
            sectionTitle: "Section D"
        )
        repository.evidenceItems = [source, hiddenSource, target, trailing]
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.reviewFilter = .keep
        workspace.evidenceWorkbench.groupingMode = .section
        workspace.evidenceWorkbench.selectedItemID = source.id

        await workspace.mergeSelectedEvidenceGroup(
            preferredWindowRoute: .evidenceWorkbench
        )

        XCTAssertEqual(repository.replaceEvidenceItemsCallCount, 1)
        XCTAssertEqual(repository.evidenceItems.map(\.id), [target.id, source.id, hiddenSource.id, trailing.id])
        XCTAssertEqual(repository.evidenceItems[1].sectionTitle, "Section C")
        XCTAssertEqual(repository.evidenceItems[2].sectionTitle, "Section C")
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItemID, source.id)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .evidenceWorkbench)
    }

    func testSplitSelectedEvidenceGroupPersistsSuffixAndPromptRoute() async throws {
        let dialogService = FakeDialogService()
        dialogService.promptTextResult = "Findings"

        let repository = FakeWorkspaceRepository()
        let lead = makeEvidenceItem(
            id: "evidence-section-a-1",
            sourceKind: .kwic,
            reviewStatus: .keep,
            sectionTitle: "Section A"
        )
        let interleaved = makeEvidenceItem(
            id: "evidence-section-b-1",
            sourceKind: .locator,
            reviewStatus: .pending,
            sectionTitle: "Section B"
        )
        let selected = makeEvidenceItem(
            id: "evidence-section-a-2",
            sourceKind: .plot,
            reviewStatus: .keep,
            sectionTitle: "Section A"
        )
        let hiddenSuffix = makeEvidenceItem(
            id: "evidence-section-a-3",
            sourceKind: .locator,
            reviewStatus: .pending,
            sectionTitle: "Section A"
        )
        let trailing = makeEvidenceItem(
            id: "evidence-section-c-1",
            sourceKind: .topics,
            reviewStatus: .keep,
            sectionTitle: "Section C"
        )
        repository.evidenceItems = [lead, interleaved, selected, hiddenSuffix, trailing]
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.reviewFilter = .keep
        workspace.evidenceWorkbench.groupingMode = .section
        workspace.evidenceWorkbench.selectedItemID = selected.id

        await workspace.splitSelectedEvidenceGroup(
            preferredWindowRoute: .evidenceWorkbench
        )

        XCTAssertEqual(repository.replaceEvidenceItemsCallCount, 1)
        XCTAssertEqual(repository.evidenceItems.map(\.id), [lead.id, selected.id, hiddenSuffix.id, interleaved.id, trailing.id])
        XCTAssertEqual(repository.evidenceItems[0].sectionTitle, "Section A")
        XCTAssertEqual(repository.evidenceItems[1].sectionTitle, "Findings")
        XCTAssertEqual(repository.evidenceItems[2].sectionTitle, "Findings")
        XCTAssertEqual(workspace.evidenceWorkbench.selectedItemID, selected.id)
        XCTAssertEqual(dialogService.promptTextPreferredRoute, .evidenceWorkbench)
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

    func testExportEvidenceArtifactsRespectCurrentWorkbenchFilters() async throws {
        let dialogService = FakeDialogService()
        let markdownURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("filtered-evidence-packet-\(UUID().uuidString).md")
        let jsonURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("filtered-evidence-bundle-\(UUID().uuidString).json")
        defer {
            try? FileManager.default.removeItem(at: markdownURL)
            try? FileManager.default.removeItem(at: jsonURL)
        }

        let matching = makeEvidenceItem(
            id: "matching-keep",
            sourceKind: .kwic,
            reviewStatus: .keep,
            tags: ["export", "alpha"],
            corpusMetadata: CorpusMetadataProfile(sourceLabel: "Research Archive")
        )
        let hiddenByTag = makeEvidenceItem(
            id: "hidden-by-tag",
            sourceKind: .kwic,
            reviewStatus: .keep,
            tags: ["beta"],
            corpusMetadata: CorpusMetadataProfile(sourceLabel: "Research Archive")
        )
        let hiddenByReview = makeEvidenceItem(
            id: "hidden-by-review",
            sourceKind: .locator,
            reviewStatus: .pending,
            tags: ["export", "alpha"],
            corpusMetadata: CorpusMetadataProfile(sourceLabel: "Research Archive")
        )
        let repository = FakeWorkspaceRepository()
        repository.evidenceItems = [matching, hiddenByTag, hiddenByReview]
        let workspace = makeMainWorkspaceViewModel(
            repository: repository,
            dialogService: dialogService
        )

        await workspace.initializeIfNeeded()
        workspace.evidenceWorkbench.reviewFilter = .keep
        workspace.evidenceWorkbench.tagFilterQuery = "export"
        workspace.evidenceWorkbench.corpusFilterQuery = "archive"

        dialogService.savePathResult = markdownURL.path
        await workspace.exportEvidencePacketMarkdown(preferredWindowRoute: .mainWorkspace)

        let markdownText = try String(contentsOf: markdownURL, encoding: .utf8)
        XCTAssertTrue(markdownText.contains("node"))
        XCTAssertFalse(markdownText.contains("locator-node"))
        XCTAssertFalse(markdownText.contains("beta"))

        dialogService.savePathResult = jsonURL.path
        await workspace.exportEvidenceJSON(preferredWindowRoute: .mainWorkspace)

        let jsonData = try Data(contentsOf: jsonURL)
        let bundle = try JSONDecoder().decode(EvidenceTransferBundle.self, from: jsonData)
        XCTAssertEqual(bundle.items.map(\.id), ["matching-keep"])
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
            "persisted/workspace-snapshot.json",
            "persisted/ui-settings.json",
            "persisted/native-host-preferences.json",
            "storage-snapshot.json"
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

    func testExportCurrentReportBundleUsesArchiveExportAndTaskCenter() async {
        let repository = FakeWorkspaceRepository()
        repository.evidenceItems = [
            makeEvidenceItem(
                sourceKind: .kwic,
                reviewStatus: .keep,
                sectionTitle: "Section A",
                claim: "Claim Alpha",
                tags: ["bundle"]
            )
        ]
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
        XCTAssertTrue(reportBundleService.lastPayload?.textDocuments.contains(where: { $0.relativePath == "reading/evidence-dossier.md" }) == true)
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
