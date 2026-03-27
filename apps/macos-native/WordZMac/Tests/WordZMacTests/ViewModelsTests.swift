import XCTest
@testable import WordZMac

@MainActor
final class ViewModelsTests: XCTestCase {
    func testStatsPageViewModelSupportsSortingPagingAndColumnToggles() {
        let viewModel = StatsPageViewModel()
        viewModel.apply(makeStatsResult(rowCount: 120))

        XCTAssertEqual(viewModel.scene?.rows.count, 100)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-100 / 120")

        viewModel.handle(.nextPage)
        XCTAssertEqual(viewModel.scene?.rows.count, 20)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "101-120 / 120")

        viewModel.handle(.changeSort(.alphabeticalAscending))
        XCTAssertEqual(viewModel.scene?.rows.first?.word, "word-0")
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-100 / 120")

        viewModel.handle(.toggleColumn(.count))
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.count) ?? true)

        viewModel.handle(.toggleColumn(.word))
        XCTAssertTrue(viewModel.scene?.isColumnVisible(.word) ?? false)
    }

    func testComparePageViewModelTracksSelectionAndColumns() {
        let viewModel = ComparePageViewModel()
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)

        XCTAssertEqual(viewModel.selectedCorpusCount, 2)

        viewModel.apply(makeCompareResult())
        viewModel.handle(.toggleColumn(.distribution))
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.distribution) ?? true)

        viewModel.handle(.changeSort(.alphabeticalAscending))
        XCTAssertEqual(viewModel.scene?.rows.first?.word, "alpha")
    }

    func testChiSquarePageViewModelValidatesAndResets() throws {
        let viewModel = ChiSquarePageViewModel()
        viewModel.a = "10"
        viewModel.b = "20"
        viewModel.c = "5"
        viewModel.d = "15"

        let inputs = try viewModel.validatedInputs()
        XCTAssertEqual(inputs.0, 10)
        XCTAssertEqual(inputs.3, 15)

        viewModel.apply(makeChiSquareResult())
        XCTAssertNotNil(viewModel.scene)
        viewModel.handle(.reset)
        XCTAssertNil(viewModel.scene)
        XCTAssertEqual(viewModel.a, "")
    }

    func testKWICPageViewModelAppliesSnapshotAndRebuildsScene() {
        let viewModel = KWICPageViewModel()
        let snapshot = makeWorkspaceSnapshot(searchQuery: "  alpha  ")
        viewModel.apply(snapshot)

        XCTAssertEqual(viewModel.keyword, "  alpha  ")
        XCTAssertEqual(viewModel.normalizedKeyword, "alpha")
        XCTAssertEqual(viewModel.leftWindowValue, 3)
        XCTAssertEqual(viewModel.rightWindowValue, 4)

        viewModel.apply(makeKWICResult(rowCount: 40))
        viewModel.handle(.changeSort(.sentenceAscending))
        XCTAssertEqual(viewModel.scene?.rows.first?.sentenceIndexText, "2")

        viewModel.handle(.toggleColumn(.leftContext))
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.leftContext) ?? true)
        XCTAssertNotNil(viewModel.primaryLocatorSource)
    }

    func testKWICPageViewModelSelectionChangesPrimaryLocatorSource() {
        let viewModel = KWICPageViewModel()
        viewModel.keyword = "node"
        viewModel.apply(makeKWICResult(rowCount: 3))

        XCTAssertEqual(viewModel.selectedRowID, "3-0")
        XCTAssertEqual(viewModel.primaryLocatorSource?.sentenceId, 3)

        viewModel.handle(.selectRow("1-2"))

        XCTAssertEqual(viewModel.selectedRowID, "1-2")
        XCTAssertEqual(viewModel.primaryLocatorSource?.sentenceId, 1)
        XCTAssertEqual(viewModel.primaryLocatorSource?.nodeIndex, 2)
    }

    func testNgramPageViewModelAppliesSnapshotFiltersAndPaging() {
        let viewModel = NgramPageViewModel()
        let snapshot = makeWorkspaceSnapshot(currentTab: "ngram")
        viewModel.apply(snapshot)

        XCTAssertEqual(viewModel.ngramSizeValue, 2)

        viewModel.apply(makeNgramResult(rowCount: 40, n: 4))
        XCTAssertEqual(viewModel.ngramSizeValue, 4)

        viewModel.query = "phrase-1"
        XCTAssertTrue(viewModel.scene?.filteredRows ?? 0 > 0)

        viewModel.handle(.changePageSize(.all))
        XCTAssertEqual(viewModel.pageSizeSnapshotValue, "全部")

        viewModel.handle(.toggleColumn(.count))
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.count) ?? true)
    }

    func testCollocatePageViewModelAppliesSnapshotPagingAndColumnVisibility() {
        let viewModel = CollocatePageViewModel()
        let snapshot = makeWorkspaceSnapshot()
        viewModel.apply(snapshot)

        XCTAssertEqual(viewModel.leftWindowValue, 5)
        XCTAssertEqual(viewModel.rightWindowValue, 6)
        XCTAssertEqual(viewModel.minFreqValue, 2)

        viewModel.apply(makeCollocateResult(rowCount: 40))
        viewModel.handle(.changePageSize(.twentyFive))
        XCTAssertEqual(viewModel.scene?.rows.count, 25)

        viewModel.handle(.nextPage)
        XCTAssertEqual(viewModel.scene?.rows.count, 15)

        viewModel.handle(.toggleColumn(.rate))
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.rate) ?? true)
    }

    func testLocatorPageViewModelTracksSourcePagingAndColumns() {
        let viewModel = LocatorPageViewModel()
        let source = LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 2)
        viewModel.updateSource(source)
        viewModel.apply(makeLocatorResult(rowCount: 30), source: source)

        XCTAssertEqual(viewModel.scene?.rows.count, 30)

        viewModel.handle(.changePageSize(.twentyFive))
        XCTAssertEqual(viewModel.scene?.rows.count, 25)

        viewModel.handle(.toggleColumn(.status))
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.status) ?? true)
    }

    func testLocatorPageViewModelActivationPromotesSelectedRowSource() {
        let viewModel = LocatorPageViewModel()
        let source = LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 2)
        viewModel.updateSource(source)
        viewModel.apply(makeLocatorResult(rowCount: 4), source: source)

        viewModel.handle(.selectRow("3"))
        viewModel.handle(.activateRow("3"))

        XCTAssertEqual(viewModel.selectedRowID, "3")
        XCTAssertEqual(viewModel.currentSource?.sentenceId, 3)
        XCTAssertEqual(viewModel.currentSource?.nodeIndex, 2)
    }

    func testLibraryManagementViewModelBuildsInspectorAndFiltersCorpora() {
        let viewModel = LibraryManagementViewModel()
        let snapshot = makeBootstrapState().librarySnapshot
        viewModel.applyBootstrap(snapshot)

        XCTAssertEqual(viewModel.scene.corpora.count, 2)
        XCTAssertEqual(viewModel.scene.inspector.title, "全部语料")

        viewModel.selectFolder("folder-1")
        XCTAssertEqual(viewModel.scene.corpora.count, 2)
        XCTAssertEqual(viewModel.scene.inspector.title, "Default")

        viewModel.selectCorpus("corpus-2")
        XCTAssertEqual(viewModel.scene.selectedCorpusID, "corpus-2")
        XCTAssertEqual(viewModel.scene.inspector.title, "Compare Corpus")
        XCTAssertEqual(viewModel.scene.inspector.actions.first?.action, .openSelectedCorpus)
    }

    func testWordCloudPageViewModelSupportsLimitAndColumns() {
        let viewModel = WordCloudPageViewModel()
        viewModel.apply(makeWordCloudResult(rowCount: 24))

        XCTAssertEqual(viewModel.scene?.visibleRows, 24)

        viewModel.handle(.changeLimit(20))
        XCTAssertEqual(viewModel.scene?.visibleRows, 20)

        viewModel.handle(.toggleColumn(.prominence))
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.prominence) ?? true)
    }
}
