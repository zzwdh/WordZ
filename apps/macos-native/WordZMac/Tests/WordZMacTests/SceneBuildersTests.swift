import XCTest
@testable import WordZMac

@MainActor
final class SceneBuildersTests: XCTestCase {
    func testStatsSceneBuilderAppliesSortingPaginationAndVisibleColumns() {
        let result = StatsResult(json: [
            "tokenCount": 12,
            "typeCount": 3,
            "ttr": 0.25,
            "sttr": 0.5,
            "freqRows": [
                ["gamma", 3],
                ["alpha", 10],
                ["beta", 7]
            ]
        ])

        let scene = StatsSceneBuilder().build(
            from: result,
            sortMode: .alphabeticalAscending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: [.word]
        )

        XCTAssertEqual(scene.rows.map(\.word), ["alpha", "beta", "gamma"])
        XCTAssertEqual(scene.totalRows, 3)
        XCTAssertEqual(scene.visibleRows, 3)
        XCTAssertTrue(scene.isColumnVisible(.word))
        XCTAssertFalse(scene.isColumnVisible(.count))
        XCTAssertEqual(scene.columnTitle(for: .word), "词 ↑")
    }

    func testKWICSceneBuilderRespectsSortingAndPaging() {
        let result = KWICResult(json: [
            "rows": [
                ["sentenceId": 2, "sentenceTokenIndex": 0, "left": "z", "node": "beta", "right": "r2"],
                ["sentenceId": 0, "sentenceTokenIndex": 0, "left": "a", "node": "alpha", "right": "r0"],
                ["sentenceId": 1, "sentenceTokenIndex": 0, "left": "m", "node": "gamma", "right": "r1"]
            ]
        ])

        let scene = KWICSceneBuilder().build(
            from: result,
            query: "alpha",
            searchOptions: .default,
            stopwordFilter: .default,
            leftWindow: 5,
            rightWindow: 5,
            sortMode: .sentenceAscending,
            pageSize: .twentyFive,
            currentPage: 1,
            visibleColumns: [.keyword, .sentenceIndex]
        )

        XCTAssertEqual(scene.rows.map(\.sentenceIndexText), ["1", "2", "3"])
        XCTAssertEqual(scene.filteredRows, 3)
        XCTAssertFalse(scene.isColumnVisible(.leftContext))
        XCTAssertTrue(scene.isColumnVisible(.keyword))
        XCTAssertEqual(scene.columnTitle(for: .sentenceIndex), "句号 ↑")
    }

    func testCollocateSceneBuilderBuildsRankAndColumnIndicators() {
        let result = CollocateResult(items: [
            [
                "word": "beta",
                "total": 4,
                "left": 1,
                "right": 3,
                "wordFreq": 9,
                "keywordFreq": 12,
                "rate": 0.4
            ],
            [
                "word": "alpha",
                "total": 8,
                "left": 5,
                "right": 3,
                "wordFreq": 11,
                "keywordFreq": 12,
                "rate": 0.7
            ]
        ])

        let scene = CollocateSceneBuilder().build(
            from: result,
            query: "node",
            searchOptions: .default,
            stopwordFilter: .default,
            leftWindow: 4,
            rightWindow: 6,
            minFreq: 2,
            sortMode: .frequencyDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: [.rank, .word, .total, .rate]
        )

        XCTAssertEqual(scene.rows.map(\.rankText), ["1", "2"])
        XCTAssertEqual(scene.rows.map(\.word), ["alpha", "beta"])
        XCTAssertEqual(scene.filteredRows, 2)
        XCTAssertEqual(scene.columnTitle(for: .total), "FreqLR ↓")
        XCTAssertTrue(scene.isColumnVisible(.rate))
        XCTAssertFalse(scene.isColumnVisible(.left))
    }

    func testCompareSceneBuilderBuildsSelectionSummariesAndSortedRows() {
        let scene = CompareSceneBuilder().build(
            selection: [
                CompareSelectableCorpusSceneItem(id: "corpus-1", title: "A", subtitle: "Default", isSelected: true),
                CompareSelectableCorpusSceneItem(id: "corpus-2", title: "B", subtitle: "Default", isSelected: true)
            ],
            from: makeCompareResult(),
            query: "a",
            searchOptions: SearchOptionsState(words: false, caseSensitive: false, regex: false),
            stopwordFilter: .default,
            sortMode: .alphabeticalAscending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: [.word, .total, .distribution]
        )

        XCTAssertEqual(scene.corpusSummaries.count, 2)
        XCTAssertEqual(scene.rows.first?.word, "alpha")
        XCTAssertEqual(scene.filteredRows, 2)
        XCTAssertEqual(scene.columnTitle(for: CompareColumnKey.word), "词 ↑")
        XCTAssertFalse(scene.isColumnVisible(CompareColumnKey.range))
    }

    func testChiSquareSceneBuilderBuildsMetricsAndWarnings() {
        let scene = ChiSquareSceneBuilder().build(from: makeChiSquareResult())

        XCTAssertEqual(scene.metrics.count, 4)
        XCTAssertEqual(scene.observedRows.count, 2)
        XCTAssertEqual(scene.summary, "差异不显著")
    }

    func testLocatorSceneBuilderBuildsPaginationAndVisibleColumns() {
        let scene = LocatorSceneBuilder().build(
            from: makeLocatorResult(rowCount: 30),
            source: LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 1),
            leftWindow: 4,
            rightWindow: 6,
            pageSize: .twentyFive,
            currentPage: 1,
            visibleColumns: [.sentenceId, .status, .text]
        )

        XCTAssertEqual(scene.rows.count, 25)
        XCTAssertEqual(scene.totalRows, 30)
        XCTAssertEqual(scene.pagination.rangeLabel, "1-25 / 30")
        XCTAssertFalse(scene.isColumnVisible(.leftWords))
        XCTAssertTrue(scene.isColumnVisible(.text))
    }

    func testNgramSceneBuilderRespectsFilterSortingAndPaging() {
        let result = NgramResult(json: [
            "n": 3,
            "rows": [
                ["zeta beta", 2],
                ["alpha beta", 10],
                ["beta gamma", 7]
            ]
        ])

        let scene = NgramSceneBuilder().build(
            from: result,
            query: "beta",
            searchOptions: SearchOptionsState(words: false, caseSensitive: false, regex: false),
            stopwordFilter: .default,
            sortMode: .alphabeticalAscending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: [.phrase, .count]
        )

        XCTAssertEqual(scene.n, 3)
        XCTAssertEqual(scene.rows.map(\NgramSceneRow.phrase), ["alpha beta", "beta gamma", "zeta beta"])
        XCTAssertEqual(scene.totalRows, 3)
        XCTAssertEqual(scene.filteredRows, 3)
        XCTAssertEqual(scene.visibleRows, 3)
        XCTAssertFalse(scene.isColumnVisible(NgramColumnKey.rank))
        XCTAssertEqual(scene.columnTitle(for: NgramColumnKey.phrase), "N-Gram ↑")
    }
}
