import XCTest
@testable import WordZWorkspaceCore

final class SentimentEngineFeatureTests: XCTestCase {
    func testRunSentimentHandlesNegationIntensityAndExclamation() throws {
        let engine = NativeAnalysisEngine()
        let result = engine.runSentiment(
            makeRequest(texts: [
                SentimentInputText(
                    id: "negated",
                    sourceTitle: "Manual",
                    text: "This is not bad."
                ),
                SentimentInputText(
                    id: "intense",
                    sourceTitle: "Manual",
                    text: "This is very good!"
                )
            ])
        )

        let negated = try XCTUnwrap(result.rows.first(where: { $0.id == "negated" }))
        XCTAssertEqual(negated.finalLabel, .positive)
        XCTAssertTrue(negated.evidence.contains(where: { $0.ruleTags.contains("negated") }))

        let intense = try XCTUnwrap(result.rows.first(where: { $0.id == "intense" }))
        XCTAssertEqual(intense.finalLabel, .positive)
        XCTAssertTrue(intense.evidence.contains(where: { $0.ruleTags.contains("intensified") }))
        XCTAssertTrue(intense.evidence.contains(where: { $0.ruleTags.contains("exclamation") }))
        XCTAssertGreaterThan(intense.netScore, negated.netScore)
    }

    func testRunSentimentAppliesContrastiveAndQuotedEvidenceAdjustments() throws {
        let engine = NativeAnalysisEngine()
        let result = engine.runSentiment(
            makeRequest(texts: [
                SentimentInputText(
                    id: "contrast",
                    sourceTitle: "Manual",
                    text: "The movie was good but very expensive."
                ),
                SentimentInputText(
                    id: "quoted",
                    sourceTitle: "Manual",
                    text: "\"great,\" he said."
                )
            ])
        )

        let contrast = try XCTUnwrap(result.rows.first(where: { $0.id == "contrast" }))
        XCTAssertEqual(contrast.finalLabel, .negative)
        XCTAssertTrue(contrast.evidence.contains(where: { $0.ruleTags.contains("preContrast") }))
        XCTAssertTrue(contrast.evidence.contains(where: { $0.ruleTags.contains("postContrast") }))

        let quoted = try XCTUnwrap(result.rows.first(where: { $0.id == "quoted" }))
        let quotedHit = try XCTUnwrap(quoted.evidence.first)
        XCTAssertEqual(quoted.finalLabel, .positive)
        XCTAssertTrue(quotedHit.ruleTags.contains("quotedEvidence"))
        XCTAssertLessThan(quotedHit.adjustedScore, quotedHit.baseScore)
    }

    private func makeRequest(texts: [SentimentInputText]) -> SentimentRunRequest {
        SentimentRunRequest(
            source: .pastedText,
            unit: .document,
            contextBasis: .visibleContext,
            thresholds: .default,
            texts: texts,
            backend: .lexicon
        )
    }
}

@MainActor
final class SentimentPresentationFeatureTests: XCTestCase {
    func testSentimentSceneBuilderAppliesFilteringSortingAndVisibleColumns() {
        let scene = SentimentSceneBuilder().build(
            from: makeSentimentResult(),
            thresholdPreset: .conservative,
            filterQuery: "bad",
            labelFilter: .negative,
            sortMode: .negativityDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: [.text, .negativity, .finalLabel, .evidence],
            selectedRowID: "sentiment-negative",
            chartKind: .distributionBar
        )

        XCTAssertEqual(scene.filteredRows, 1)
        XCTAssertEqual(scene.rows.count, 1)
        XCTAssertEqual(scene.rows.first?.text, "This is bad.")
        XCTAssertEqual(scene.selectedRowID, "sentiment-negative")
        XCTAssertTrue(scene.column(for: .evidence)?.isVisible ?? false)
        XCTAssertFalse(scene.column(for: .source)?.isVisible ?? true)
        XCTAssertTrue(scene.exportMetadataLines.contains(where: { $0.contains("Backend") || $0.contains("后端") }))
    }

    func testSentimentPageViewModelTracksFilteringColumnsAndCompareSelection() {
        let viewModel = SentimentPageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)
        viewModel.apply(makeSentimentResult())

        XCTAssertEqual(viewModel.scene?.rows.count, 2)
        XCTAssertEqual(viewModel.selectedSceneRow?.id, "sentiment-positive")

        viewModel.handle(.changeLabelFilter(.negative))
        XCTAssertEqual(viewModel.scene?.rows.count, 1)
        XCTAssertEqual(viewModel.selectedSceneRow?.finalLabel, .negative)

        viewModel.handle(.toggleColumn(.evidence))
        XCTAssertTrue(viewModel.scene?.column(for: .evidence)?.isVisible ?? false)

        viewModel.handle(.changeSource(.kwicVisible))
        XCTAssertEqual(viewModel.unit, .concordanceLine)

        viewModel.handle(.changeSource(.corpusCompare))
        viewModel.handle(.toggleCorpusSelection("corpus-2"))
        viewModel.handle(.changeReferenceCorpus("corpus-2"))

        XCTAssertEqual(viewModel.unit, .document)
        XCTAssertEqual(Set(viewModel.selectedTargetCorpusItems().map(\.id)), Set(["corpus-1"]))
        XCTAssertEqual(viewModel.selectedReferenceCorpusItem()?.id, "corpus-2")
    }

    func testSentimentPageViewModelFallsBackWhenCoreMLBackendIsUnavailable() {
        let viewModel = SentimentPageViewModel(
            availableBackendProvider: { [.lexicon] }
        )
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)

        viewModel.apply(
            makeWorkspaceSnapshot(
                currentTab: WorkspaceDetailTab.sentiment.snapshotValue,
                sentimentBackend: .coreML
            )
        )

        XCTAssertEqual(viewModel.backend, .lexicon)
        XCTAssertNotNil(viewModel.backendNotice)
    }

    func testSentimentPageViewModelShowsBackendPickerWhenMultipleBackendsExist() {
        let viewModel = SentimentPageViewModel(
            availableBackendProvider: { [.lexicon, .coreML] }
        )

        XCTAssertTrue(viewModel.showsBackendPicker)

        viewModel.handle(.changeBackend(.coreML))
        XCTAssertEqual(viewModel.backend, .coreML)
    }

    func testDispatcherSentimentRunActionRunsAnalysisAndBuildsSceneGraph() async {
        let repository = FakeWorkspaceRepository()
        let workspace = makeMainWorkspaceViewModel(repository: repository)
        let dispatcher = WorkspaceActionDispatcher(workspace: workspace)

        await workspace.initializeIfNeeded()
        dispatcher.handleSentimentAction(.run)
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(repository.runSentimentCallCount, 1)
        XCTAssertEqual(workspace.selectedTab, .sentiment)
        XCTAssertEqual(workspace.sentiment.scene?.summary.totalTexts, 2)
        XCTAssertEqual(workspace.sceneGraph.activeTab, .sentiment)
    }
}
