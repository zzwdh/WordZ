import AppKit
import XCTest
@testable import WordZWorkspaceCore
import WordZExport
@testable import WordZWorkbenchUI

@MainActor
final class PerformanceBoundaryTests: XCTestCase {
    func testInteractiveAllPageSizingFallsBackForLargeResultsAcrossAnalysisPages() {
        let maximumSafeRows = ResultPerformanceGuardrails.maximumInteractiveAllRows
        let oversizedRows = maximumSafeRows + 1

        XCTAssertEqual(StatsPageSize.all.resolvedInteractivePageSize(totalRows: maximumSafeRows), .all)
        XCTAssertEqual(StatsPageSize.all.resolvedInteractivePageSize(totalRows: oversizedRows), .twoHundredFifty)
        XCTAssertEqual(WordPageSize.all.resolvedInteractivePageSize(totalRows: oversizedRows), .twoHundredFifty)
        XCTAssertEqual(TokenizePageSize.all.resolvedInteractivePageSize(totalRows: oversizedRows), .twoHundredFifty)
        XCTAssertEqual(NgramPageSize.all.resolvedInteractivePageSize(totalRows: oversizedRows), .twoHundredFifty)
        XCTAssertEqual(KWICPageSize.all.resolvedInteractivePageSize(totalRows: oversizedRows), .oneHundred)
        XCTAssertEqual(ComparePageSize.all.resolvedInteractivePageSize(totalRows: oversizedRows), .oneHundred)
        XCTAssertEqual(KeywordPageSize.all.resolvedInteractivePageSize(totalRows: oversizedRows), .oneHundred)
        XCTAssertEqual(CollocatePageSize.all.resolvedInteractivePageSize(totalRows: oversizedRows), .oneHundred)
        XCTAssertEqual(LocatorPageSize.all.resolvedInteractivePageSize(totalRows: oversizedRows), .oneHundred)
        XCTAssertEqual(TopicsPageSize.all.resolvedInteractivePageSize(totalRows: oversizedRows), .oneHundred)
        XCTAssertEqual(SentimentPageSize.all.resolvedInteractivePageSize(totalRows: oversizedRows), .oneHundred)
        XCTAssertEqual(ClusterPageSize.all.resolvedInteractivePageSize(totalRows: oversizedRows), .oneHundred)
    }

    func testLargeResultInteractionDispatchStaysWithinP95Budget() {
        let rowCount = LargeResultSceneBuildSupport.asyncThreshold + 240
        var samples: [LargeResultInteractionSample] = []

        let statsViewModel = StatsPageViewModel()
        statsViewModel.apply(makeStatsResult(rowCount: rowCount))
        waitForMainRunLoop(description: "initial stats large scene built") {
            statsViewModel.scene?.totalRows == rowCount
        }
        recordInteractionDispatch("stats.sort.range", samples: &samples) {
            statsViewModel.handle(.changeSort(.rangeAscending))
        }
        recordInteractionDispatch("stats.page.all", samples: &samples) {
            statsViewModel.handle(.changePageSize(.all))
        }
        recordInteractionDispatch("stats.column.count", samples: &samples) {
            statsViewModel.handle(.toggleColumn(.count))
        }
        recordInteractionDispatch("stats.sort.alpha", samples: &samples) {
            statsViewModel.handle(.changeSort(.alphabeticalAscending))
        }

        let kwicViewModel = KWICPageViewModel()
        kwicViewModel.keyword = "node"
        kwicViewModel.apply(makeKWICResult(rowCount: rowCount))
        waitForMainRunLoop(description: "initial kwic large scene built") {
            kwicViewModel.scene?.totalRows == rowCount
        }
        recordInteractionDispatch("kwic.sort.keyword", samples: &samples) {
            kwicViewModel.handle(.changeSort(.keywordAscending))
        }
        recordInteractionDispatch("kwic.page.all", samples: &samples) {
            kwicViewModel.handle(.changePageSize(.all))
        }
        recordInteractionDispatch("kwic.column.sentence", samples: &samples) {
            kwicViewModel.handle(.toggleColumn(.sentenceIndex))
        }
        recordInteractionDispatch("kwic.sort.sentence", samples: &samples) {
            kwicViewModel.handle(.sortByColumn(.sentenceIndex))
        }

        let sentimentViewModel = SentimentPageViewModel()
        sentimentViewModel.apply(makeLargeSentimentResult(rowCount: rowCount))
        waitForMainRunLoop(description: "initial sentiment large scene built") {
            sentimentViewModel.scene?.totalRows == rowCount
        }
        recordInteractionDispatch("sentiment.sort.net", samples: &samples) {
            sentimentViewModel.handle(.changeSort(.netScoreDescending))
        }
        recordInteractionDispatch("sentiment.page.all", samples: &samples) {
            sentimentViewModel.handle(.changePageSize(.all))
        }
        recordInteractionDispatch("sentiment.filter.positive", samples: &samples) {
            sentimentViewModel.handle(.changeLabelFilter(.positive))
        }
        recordInteractionDispatch("sentiment.column.evidence", samples: &samples) {
            sentimentViewModel.handle(.toggleColumn(.evidence))
        }

        let topicsViewModel = TopicsPageViewModel()
        topicsViewModel.apply(makeLargeTopicAnalysisResult(segmentCount: rowCount))
        waitForMainRunLoop(description: "initial topics large scene built") {
            topicsViewModel.scene?.visibleSegments == rowCount
        }
        recordInteractionDispatch("topics.cluster", samples: &samples) {
            topicsViewModel.handle(.selectCluster("topic-large"))
        }
        recordInteractionDispatch("topics.page.all", samples: &samples) {
            topicsViewModel.handle(.changePageSize(.all))
        }
        recordInteractionDispatch("topics.column.score", samples: &samples) {
            topicsViewModel.handle(.toggleColumn(.score))
        }
        recordInteractionDispatch("topics.sort.paragraph", samples: &samples) {
            topicsViewModel.handle(.changeSort(.paragraphAscending))
        }

        waitForMainRunLoop(description: "latest stats budget scene built") {
            statsViewModel.scene?.sorting.selectedSort == .alphabeticalAscending &&
                statsViewModel.scene?.sorting.selectedPageSize == .twoHundredFifty
        }
        waitForMainRunLoop(description: "latest kwic budget scene built") {
            kwicViewModel.scene?.sorting.selectedSort == .sentenceAscending &&
                kwicViewModel.scene?.sorting.selectedPageSize == .oneHundred
        }
        waitForMainRunLoop(description: "latest sentiment budget scene built") {
            sentimentViewModel.scene?.labelFilter == .positive &&
                sentimentViewModel.scene?.sorting.selectedPageSize == .oneHundred
        }
        waitForMainRunLoop(description: "latest topics budget scene built") {
            topicsViewModel.scene?.selectedClusterID == "topic-large" &&
                topicsViewModel.scene?.controls.selectedPageSize == .oneHundred
        }

        let measuredP95 = percentile(samples.map(\.durationMilliseconds), 0.95)
        let slowest = samples.max { $0.durationMilliseconds < $1.durationMilliseconds }
        XCTAssertLessThanOrEqual(
            measuredP95,
            ResultPerformanceGuardrails.largeResultInteractionDispatchP95BudgetMilliseconds,
            "Large-result interaction dispatch p95 \(measuredP95) ms exceeded budget; slowest sample: \(slowest?.label ?? "n/a") \(slowest?.durationMilliseconds ?? 0) ms"
        )
    }

    func testStableTableSnapshotVersionTracksLargeRowSetChanges() {
        let rows = makeTableRows(count: ResultPerformanceGuardrails.maximumInteractiveAllRows + 250)
        var changedCellRows = rows
        changedCellRows[42] = NativeTableRowDescriptor(
            id: "row-42",
            values: [
                "word": "changed",
                "count": "42"
            ]
        )
        var reorderedRows = rows
        reorderedRows.swapAt(0, 1)

        let firstSnapshot = ResultTableSnapshot.stable(rows: rows)
        let equivalentSnapshot = ResultTableSnapshot.stable(rows: rows)
        let changedCellSnapshot = ResultTableSnapshot.stable(rows: changedCellRows)
        let reorderedSnapshot = ResultTableSnapshot.stable(rows: reorderedRows)

        XCTAssertEqual(firstSnapshot.version, equivalentSnapshot.version)
        XCTAssertNotEqual(firstSnapshot.version, changedCellSnapshot.version)
        XCTAssertNotEqual(firstSnapshot.version, reorderedSnapshot.version)
    }

    func testTableCoordinatorPartiallyReloadsVisibleAndSelectedRowsForLargeSnapshotUpdates() {
        let descriptor = NativeTableDescriptor(columns: [
            NativeTableColumnDescriptor(id: "word", title: "Word", isVisible: true, sortIndicator: nil),
            NativeTableColumnDescriptor(id: "count", title: "Count", isVisible: true, sortIndicator: nil)
        ])
        let initialRows = makeTableRows(count: 2_000)
        let updatedRows = initialRows.enumerated().map { index, row in
            NativeTableRowDescriptor(
                id: row.id,
                values: [
                    "word": row.value(for: "word"),
                    "count": "\(index + 1)"
                ]
            )
        }
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: initialRows,
            snapshot: ResultTableSnapshot(version: 1, rows: initialRows),
            selectedRowID: "row-900",
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        let tableView = RecordingTableView(frame: NSRect(x: 0, y: 0, width: 480, height: 280))
        tableView.forcedVisibleRange = NSRange(location: 20, length: 12)

        coordinator.attach(tableView: tableView)
        coordinator.apply(
            descriptor: descriptor,
            rows: initialRows,
            snapshot: ResultTableSnapshot(version: 1, rows: initialRows),
            selectedRowID: "row-900",
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        tableView.resetRecording()

        coordinator.apply(
            descriptor: descriptor,
            rows: updatedRows,
            snapshot: ResultTableSnapshot(version: 2, rows: updatedRows),
            selectedRowID: "row-900",
            onSelectionChange: nil,
            onDoubleClick: nil
        )

        XCTAssertEqual(tableView.fullReloadCount, 0)
        XCTAssertEqual(tableView.partialReloads.count, 1)
        XCTAssertEqual(tableView.partialReloads.first?.columns, IndexSet(integersIn: 0..<2))
        XCTAssertTrue(tableView.partialReloads.first?.rows.isSuperset(of: IndexSet(integersIn: 20..<32)) == true)
        XCTAssertTrue(tableView.partialReloads.first?.rows.contains(900) == true)
        XCTAssertEqual(tableView.noteNumberOfRowsChangedCount, 0)
    }

    func testTableCoordinatorSelectionOnlyApplyKeepsLargeSnapshotOffReloadPath() {
        let descriptor = NativeTableDescriptor(columns: [
            NativeTableColumnDescriptor(id: "word", title: "Word", isVisible: true, sortIndicator: nil),
            NativeTableColumnDescriptor(id: "count", title: "Count", isVisible: true, sortIndicator: nil)
        ])
        let rows = makeTableRows(count: 50_000)
        let snapshot = ResultTableSnapshot(version: 7, rows: rows)
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: rows,
            snapshot: snapshot,
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        let tableView = RecordingTableView(frame: NSRect(x: 0, y: 0, width: 480, height: 280))
        tableView.forcedVisibleRange = NSRange(location: 100, length: 16)

        coordinator.attach(tableView: tableView)
        coordinator.apply(
            descriptor: descriptor,
            rows: rows,
            snapshot: snapshot,
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        tableView.resetRecording()

        coordinator.apply(
            descriptor: descriptor,
            rows: rows,
            snapshot: snapshot,
            selectedRowID: "row-49999",
            onSelectionChange: nil,
            onDoubleClick: nil
        )

        XCTAssertEqual(tableView.fullReloadCount, 0)
        XCTAssertEqual(tableView.partialReloads.count, 0)
        XCTAssertEqual(tableView.noteNumberOfRowsChangedCount, 0)
        XCTAssertEqual(coordinator.resolvedSelectedRowIndexes(), [49_999])
    }

    func testTableCoordinatorClearsUnavailableSelectionWhenLargeRowsShrink() {
        let descriptor = NativeTableDescriptor(columns: [
            NativeTableColumnDescriptor(id: "word", title: "Word", isVisible: true, sortIndicator: nil)
        ])
        let initialRows = makeTableRows(count: 200)
        let reducedRows = makeTableRows(count: 10)
        var selectionChanges: [String?] = []
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: initialRows,
            selectedRowID: "row-150",
            onSelectionChange: { selectionChanges.append($0) },
            onDoubleClick: nil
        )
        let tableView = RecordingTableView(frame: .zero)

        coordinator.attach(tableView: tableView)
        coordinator.apply(
            descriptor: descriptor,
            rows: initialRows,
            selectedRowID: "row-150",
            onSelectionChange: { selectionChanges.append($0) },
            onDoubleClick: nil
        )

        coordinator.apply(
            descriptor: descriptor,
            rows: reducedRows,
            selectedRowID: "row-150",
            onSelectionChange: { selectionChanges.append($0) },
            onDoubleClick: nil
        )

        XCTAssertEqual(coordinator.resolvedSelectedRowIndexes(), [])
        XCTAssertEqual(selectionChanges.count, 1)
        XCTAssertNil(selectionChanges[0])
        XCTAssertFalse(coordinator.activateSelectedRow())
    }

    func testMarkerKeyboardNavigationClampsAtComplexCellBoundaries() {
        let descriptor = NativeTableDescriptor(columns: [
            NativeTableColumnDescriptor(
                id: "plot",
                title: "Plot",
                isVisible: true,
                sortIndicator: nil,
                presentation: .custom(.markerStrip)
            )
        ])
        let rows = [
            NativeTableRowDescriptor(
                id: "row-0",
                cells: [
                    "plot": .custom(
                        text: "3 hits",
                        presentation: .markerStrip([
                            NativeTableMarkerValue(id: "hit-1", normalizedPosition: -0.25, accessibilityLabel: "Hit 1"),
                            NativeTableMarkerValue(id: "hit-2", normalizedPosition: 0.5, accessibilityLabel: "Hit 2"),
                            NativeTableMarkerValue(id: "hit-3", normalizedPosition: 1.25, accessibilityLabel: "Hit 3")
                        ])
                    )
                ]
            )
        ]
        var markerSelections: [(rowID: String, markerID: String?)] = []
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: "row-0",
            onSelectionChange: nil,
            onDoubleClick: nil,
            selectedMarkerID: "hit-1",
            onMarkerSelectionChange: { markerSelections.append(($0, $1)) }
        )

        XCTAssertFalse(coordinator.selectAdjacentMarker(direction: .previous))
        XCTAssertEqual(markerSelections.count, 0)

        XCTAssertTrue(coordinator.selectAdjacentMarker(direction: .next))
        XCTAssertEqual(markerSelections.last?.markerID, "hit-2")
        XCTAssertTrue(coordinator.selectAdjacentMarker(direction: .next))
        XCTAssertEqual(markerSelections.last?.markerID, "hit-3")
        XCTAssertFalse(coordinator.selectAdjacentMarker(direction: .next))
        XCTAssertFalse(coordinator.selectAdjacentMarker(rowID: "missing", direction: .next))
        XCTAssertEqual(rows[0].cell(for: "plot"), .custom(
            text: "3 hits",
            presentation: .markerStrip([
                NativeTableMarkerValue(id: "hit-1", normalizedPosition: 0, accessibilityLabel: "Hit 1"),
                NativeTableMarkerValue(id: "hit-2", normalizedPosition: 0.5, accessibilityLabel: "Hit 2"),
                NativeTableMarkerValue(id: "hit-3", normalizedPosition: 1, accessibilityLabel: "Hit 3")
            ])
        ))
    }

    func testActionTableViewKeyDownRoutesCopyActivationAndMarkerNavigation() {
        let descriptor = NativeTableDescriptor(columns: [
            NativeTableColumnDescriptor(
                id: "plot",
                title: "Plot",
                isVisible: true,
                sortIndicator: nil,
                presentation: .custom(.markerStrip)
            )
        ])
        let rows = [
            NativeTableRowDescriptor(
                id: "row-0",
                cells: [
                    "plot": .custom(
                        text: "2 hits",
                        presentation: .markerStrip([
                            NativeTableMarkerValue(id: "hit-1", normalizedPosition: 0.25, accessibilityLabel: "Hit 1"),
                            NativeTableMarkerValue(id: "hit-2", normalizedPosition: 0.75, accessibilityLabel: "Hit 2")
                        ])
                    )
                ]
            )
        ]
        var activatedRows: [String] = []
        var markerSelections: [(rowID: String, markerID: String?)] = []
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: "row-0",
            onSelectionChange: nil,
            onDoubleClick: { activatedRows.append($0) },
            selectedMarkerID: "hit-1",
            onMarkerSelectionChange: { markerSelections.append(($0, $1)) }
        )
        let tableView = NativeTableView.ActionTableView(frame: .zero)
        tableView.actionCoordinator = coordinator
        let pasteboard = InMemoryNativeTablePasteboard()
        tableView.copyPasteboard = pasteboard

        coordinator.attach(tableView: tableView)
        coordinator.apply(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: "row-0",
            onSelectionChange: nil,
            onDoubleClick: { activatedRows.append($0) },
            selectedMarkerID: "hit-1",
            onMarkerSelectionChange: { markerSelections.append(($0, $1)) }
        )

        tableView.keyDown(with: keyEvent(keyCode: 8, characters: "c", modifiers: .command))
        tableView.keyDown(with: keyEvent(keyCode: 36, characters: "\r"))
        tableView.keyDown(with: keyEvent(keyCode: 124, characters: "\u{F703}"))
        tableView.keyDown(with: keyEvent(keyCode: 123, characters: "\u{F702}"))

        XCTAssertEqual(pasteboard.string, "Plot\n2 hits")
        XCTAssertEqual(activatedRows, ["row-0"])
        XCTAssertEqual(markerSelections.map(\.markerID), ["hit-2", "hit-1"])
    }

    func testStatsLargeResultKeepsLatestSceneAfterRapidSortPagingAndColumnChanges() {
        let viewModel = StatsPageViewModel()
        let rowCount = LargeResultSceneBuildSupport.asyncThreshold + 200
        let latestSceneBuilt = expectation(description: "latest rapid stats scene built")
        var didFulfill = false
        viewModel.onSceneChange = { [weak viewModel] in
            guard let viewModel,
                  !didFulfill,
                  viewModel.scene?.sorting.selectedSort == .rangeAscending,
                  viewModel.scene?.sorting.selectedPageSize == .twoHundredFifty,
                  viewModel.scene?.isColumnVisible(.count) == false
            else {
                return
            }
            didFulfill = true
            latestSceneBuilt.fulfill()
        }

        viewModel.apply(makeStatsResult(rowCount: rowCount))
        viewModel.handle(.changeSort(.alphabeticalAscending))
        viewModel.handle(.changePageSize(.all))
        viewModel.handle(.toggleColumn(.count))
        viewModel.handle(.changeSort(.rangeAscending))

        wait(for: [latestSceneBuilt], timeout: 2.0)
        XCTAssertEqual(viewModel.pageSize, .twoHundredFifty)
        XCTAssertEqual(viewModel.scene?.sorting.selectedSort, .rangeAscending)
        XCTAssertEqual(viewModel.scene?.sorting.selectedPageSize, .twoHundredFifty)
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.count) ?? true)
        XCTAssertEqual(viewModel.scene?.rows.count, StatsPageSize.twoHundredFifty.rawValue)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-250 / \(rowCount)")
    }

    func testWordLargeResultKeepsLatestSceneAfterRapidSortPagingAndColumnChanges() {
        let viewModel = WordPageViewModel()
        let rowCount = LargeResultSceneBuildSupport.asyncThreshold + 220

        viewModel.apply(makeStatsResult(rowCount: rowCount))
        viewModel.handle(.changeSort(.frequencyAscending))
        viewModel.handle(.changePageSize(.all))
        viewModel.handle(.toggleColumn(.rank))
        viewModel.handle(.sortByColumn(.word))

        waitForMainRunLoop(description: "latest rapid word scene built") {
            viewModel.scene?.sorting.selectedSort == .alphabeticalAscending &&
                viewModel.scene?.sorting.selectedPageSize == .twoHundredFifty &&
                viewModel.scene?.table.isVisible(WordColumnKey.rank.rawValue) == true
        }

        XCTAssertEqual(viewModel.pageSize, .twoHundredFifty)
        XCTAssertEqual(viewModel.scene?.sorting.selectedSort, .alphabeticalAscending)
        XCTAssertEqual(viewModel.scene?.sorting.selectedPageSize, .twoHundredFifty)
        XCTAssertTrue(viewModel.scene?.table.isVisible(WordColumnKey.rank.rawValue) ?? false)
        XCTAssertEqual(viewModel.scene?.rows.count, WordPageSize.twoHundredFifty.rawValue)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-250 / \(rowCount)")
    }

    func testTokenizeLargeResultKeepsLatestSceneAfterRapidSortPagingAndColumnChanges() {
        let viewModel = TokenizePageViewModel()
        let rowCount = LargeResultSceneBuildSupport.asyncThreshold + 260

        viewModel.apply(makeLargeTokenizeResult(tokenCount: rowCount))
        viewModel.handle(.changeSort(.normalizedAscending))
        viewModel.handle(.changePageSize(.all))
        viewModel.handle(.toggleColumn(.position))
        viewModel.handle(.sortByColumn(.lemma))

        waitForMainRunLoop(description: "latest rapid tokenize scene built") {
            viewModel.scene?.sorting.selectedSort == .lemmaAscending &&
                viewModel.scene?.sorting.selectedPageSize == .twoHundredFifty &&
                viewModel.scene?.table.isVisible(TokenizeColumnKey.position.rawValue) == true
        }

        XCTAssertEqual(viewModel.pageSize, .twoHundredFifty)
        XCTAssertEqual(viewModel.scene?.sorting.selectedSort, .lemmaAscending)
        XCTAssertEqual(viewModel.scene?.sorting.selectedPageSize, .twoHundredFifty)
        XCTAssertTrue(viewModel.scene?.table.isVisible(TokenizeColumnKey.position.rawValue) ?? false)
        XCTAssertEqual(viewModel.scene?.rows.count, TokenizePageSize.twoHundredFifty.rawValue)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-250 / \(rowCount)")
        XCTAssertEqual(viewModel.selectedRowID, viewModel.scene?.rows.first?.id)
    }

    func testNgramLargeResultKeepsLatestSceneAfterRapidSortPagingAndColumnChanges() {
        let viewModel = NgramPageViewModel()
        let rowCount = LargeResultSceneBuildSupport.asyncThreshold + 240

        viewModel.apply(makeNgramResult(rowCount: rowCount, n: 3))
        viewModel.handle(.changeSort(.frequencyAscending))
        viewModel.handle(.changePageSize(.all))
        viewModel.handle(.toggleColumn(.rank))
        viewModel.handle(.sortByColumn(.phrase))

        waitForMainRunLoop(description: "latest rapid ngram scene built") {
            viewModel.scene?.sorting.selectedSort == .alphabeticalAscending &&
                viewModel.scene?.sorting.selectedPageSize == .twoHundredFifty &&
                viewModel.scene?.isColumnVisible(.rank) == true
        }

        XCTAssertEqual(viewModel.pageSize, .twoHundredFifty)
        XCTAssertEqual(viewModel.scene?.n, 3)
        XCTAssertEqual(viewModel.scene?.sorting.selectedSort, .alphabeticalAscending)
        XCTAssertEqual(viewModel.scene?.sorting.selectedPageSize, .twoHundredFifty)
        XCTAssertTrue(viewModel.scene?.isColumnVisible(.rank) ?? false)
        XCTAssertEqual(viewModel.scene?.rows.count, NgramPageSize.twoHundredFifty.rawValue)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-250 / \(rowCount)")
    }

    func testKWICLargeResultKeepsLatestSceneAfterRapidSortPagingAndColumnChanges() {
        let viewModel = KWICPageViewModel()
        let rowCount = LargeResultSceneBuildSupport.asyncThreshold + 150
        viewModel.keyword = "node"

        viewModel.apply(makeKWICResult(rowCount: rowCount))
        viewModel.handle(.changeSort(.keywordAscending))
        viewModel.handle(.changePageSize(.all))
        viewModel.handle(.toggleColumn(.sentenceIndex))
        viewModel.handle(.sortByColumn(.sentenceIndex))

        waitForMainRunLoop(description: "latest rapid kwic scene built") {
            viewModel.scene?.sorting.selectedSort == .sentenceAscending &&
                viewModel.scene?.sorting.selectedPageSize == .oneHundred &&
                viewModel.scene?.isColumnVisible(.sentenceIndex) == true
        }

        XCTAssertEqual(viewModel.pageSize, .oneHundred)
        XCTAssertEqual(viewModel.scene?.sorting.selectedSort, .sentenceAscending)
        XCTAssertEqual(viewModel.scene?.sorting.selectedPageSize, .oneHundred)
        XCTAssertTrue(viewModel.scene?.isColumnVisible(.sentenceIndex) ?? false)
        XCTAssertEqual(viewModel.scene?.rows.count, KWICPageSize.oneHundred.rawValue)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-100 / \(rowCount)")
        XCTAssertEqual(viewModel.selectedRowID, viewModel.scene?.rows.first?.id)
    }

    func testCompareLargeResultKeepsLatestSceneAfterRapidSortPagingAndColumnChanges() {
        let viewModel = ComparePageViewModel()
        let rowCount = LargeResultSceneBuildSupport.asyncThreshold + 180
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)

        viewModel.apply(makeLargeCompareResult(rowCount: rowCount))
        viewModel.handle(.changeSort(.spreadDescending))
        viewModel.handle(.changePageSize(.all))
        viewModel.handle(.toggleColumn(.distribution))
        viewModel.handle(.sortByColumn(.total))

        waitForMainRunLoop(description: "latest rapid compare scene built") {
            viewModel.scene?.sorting.selectedSort == .totalDescending &&
                viewModel.scene?.sorting.selectedPageSize == .oneHundred &&
                viewModel.scene?.isColumnVisible(.distribution) == true
        }

        XCTAssertEqual(viewModel.pageSize, .oneHundred)
        XCTAssertEqual(viewModel.scene?.sorting.selectedSort, .totalDescending)
        XCTAssertEqual(viewModel.scene?.sorting.selectedPageSize, .oneHundred)
        XCTAssertTrue(viewModel.scene?.isColumnVisible(.distribution) ?? false)
        XCTAssertEqual(viewModel.scene?.rows.count, ComparePageSize.oneHundred.rawValue)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-100 / \(rowCount)")
        XCTAssertEqual(viewModel.selectedSceneRow?.id, viewModel.scene?.rows.first?.id)
    }

    func testSentimentLargeResultKeepsLatestSceneAfterRapidFilterSortPagingAndColumnChanges() {
        let viewModel = SentimentPageViewModel()
        let rowCount = LargeResultSceneBuildSupport.asyncThreshold + 220
        let positiveRows = (rowCount + 1) / 2

        viewModel.apply(makeLargeSentimentResult(rowCount: rowCount))
        viewModel.handle(.selectRow("sentiment-1"))
        viewModel.handle(.changeSort(.netScoreDescending))
        viewModel.handle(.changePageSize(.all))
        viewModel.handle(.toggleColumn(.evidence))
        viewModel.handle(.changeLabelFilter(.positive))
        viewModel.handle(.sortByColumn(.source))

        waitForMainRunLoop(description: "latest rapid sentiment scene built") {
            viewModel.scene?.labelFilter == .positive &&
                viewModel.scene?.sorting.selectedSort == .sourceAscending &&
                viewModel.scene?.sorting.selectedPageSize == .oneHundred &&
                viewModel.scene?.table.isVisible(SentimentColumnKey.evidence.rawValue) == true &&
                viewModel.selectedRowID != "sentiment-1"
        }

        XCTAssertEqual(viewModel.pageSize, .oneHundred)
        XCTAssertEqual(viewModel.labelFilter, .positive)
        XCTAssertEqual(viewModel.scene?.sorting.selectedSort, .sourceAscending)
        XCTAssertEqual(viewModel.scene?.sorting.selectedPageSize, .oneHundred)
        XCTAssertTrue(viewModel.scene?.table.isVisible(SentimentColumnKey.evidence.rawValue) ?? false)
        XCTAssertEqual(viewModel.scene?.filteredRows, positiveRows)
        XCTAssertEqual(viewModel.scene?.rows.count, SentimentPageSize.oneHundred.rawValue)
        XCTAssertTrue(viewModel.scene?.rows.allSatisfy { $0.effectiveLabel == .positive } ?? false)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-100 / \(positiveRows)")
        XCTAssertEqual(viewModel.selectedRowID, viewModel.scene?.selectedRowID)
    }

    func testKeywordLargeResultKeepsLatestSceneAfterRapidTabSortPagingAndColumnChanges() {
        let viewModel = KeywordPageViewModel()
        let rowCount = LargeResultSceneBuildSupport.asyncThreshold + 160
        viewModel.syncLibrarySnapshot(makeBootstrapState().librarySnapshot)

        viewModel.apply(makeLargeKeywordSuiteResult(rowCount: rowCount))
        viewModel.handle(.changeTab(.terms))
        viewModel.handle(.changePageSize(.all))
        viewModel.handle(.toggleColumn(.example))
        viewModel.handle(.changeSort(.focusFrequencyDescending))
        viewModel.handle(.sortByColumn(.item))

        waitForMainRunLoop(description: "latest rapid keyword scene built") {
            viewModel.scene?.activeTab == .terms &&
                viewModel.scene?.sorting.selectedSort == .alphabeticalAscending &&
                viewModel.scene?.sorting.selectedPageSize == .oneHundred &&
                viewModel.scene?.table.isVisible(KeywordColumnKey.example.rawValue) == true
        }

        XCTAssertEqual(viewModel.activeTab, .terms)
        XCTAssertEqual(viewModel.pageSize, .oneHundred)
        XCTAssertEqual(viewModel.scene?.totalRows, rowCount)
        XCTAssertEqual(viewModel.scene?.sorting.selectedSort, .alphabeticalAscending)
        XCTAssertEqual(viewModel.scene?.sorting.selectedPageSize, .oneHundred)
        XCTAssertTrue(viewModel.scene?.table.isVisible(KeywordColumnKey.example.rawValue) ?? false)
        XCTAssertEqual(viewModel.scene?.rows.count, KeywordPageSize.oneHundred.rawValue)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-100 / \(rowCount)")
        XCTAssertEqual(viewModel.selectedRowID, viewModel.scene?.rows.first?.id)
    }

    func testCollocateLargeResultKeepsLatestSceneAfterRapidMetricSortPagingAndColumnChanges() {
        let viewModel = CollocatePageViewModel()
        let rowCount = LargeResultSceneBuildSupport.asyncThreshold + 170
        viewModel.keyword = "node"

        viewModel.apply(makeCollocateResult(rowCount: rowCount))
        viewModel.handle(.changeFocusMetric(.mutualInformation))
        viewModel.handle(.changePageSize(.all))
        viewModel.handle(.toggleColumn(.mutualInformation))
        viewModel.handle(.sortByColumn(.mutualInformation))

        waitForMainRunLoop(description: "latest rapid collocate scene built") {
            viewModel.scene?.focusMetric == .mutualInformation &&
                viewModel.scene?.sorting.selectedSort == .mutualInformationDescending &&
                viewModel.scene?.sorting.selectedPageSize == .oneHundred &&
                viewModel.scene?.isColumnVisible(.mutualInformation) == false
        }

        XCTAssertEqual(viewModel.focusMetric, .mutualInformation)
        XCTAssertEqual(viewModel.pageSize, .oneHundred)
        XCTAssertEqual(viewModel.scene?.focusMetric, .mutualInformation)
        XCTAssertEqual(viewModel.scene?.sorting.selectedSort, .mutualInformationDescending)
        XCTAssertEqual(viewModel.scene?.sorting.selectedPageSize, .oneHundred)
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.mutualInformation) ?? true)
        XCTAssertEqual(viewModel.scene?.rows.count, CollocatePageSize.oneHundred.rawValue)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-100 / \(rowCount)")
        XCTAssertEqual(viewModel.selectedRowID, viewModel.scene?.rows.first?.id)
    }

    func testLocatorLargeResultKeepsLatestSceneAfterRapidPagingColumnSelectionAndActivation() {
        let viewModel = LocatorPageViewModel()
        let rowCount = LargeResultSceneBuildSupport.asyncThreshold + 140
        let source = LocatorSource(keyword: "node", sentenceId: 1, nodeIndex: 2)

        viewModel.apply(makeLocatorResult(rowCount: rowCount), source: source)
        waitForMainRunLoop(description: "initial large locator scene built") {
            viewModel.scene?.totalRows == rowCount
        }

        viewModel.handle(.changePageSize(.all))
        viewModel.handle(.toggleColumn(.leftWords))
        viewModel.handle(.selectRow("42"))
        viewModel.handle(.activateRow("42"))

        waitForMainRunLoop(description: "latest rapid locator scene built") {
            viewModel.scene?.selectedPageSize == .oneHundred &&
                viewModel.scene?.isColumnVisible(.leftWords) == true &&
                viewModel.currentSource?.sentenceId == 42
        }

        XCTAssertEqual(viewModel.pageSize, .oneHundred)
        XCTAssertEqual(viewModel.scene?.selectedPageSize, .oneHundred)
        XCTAssertTrue(viewModel.scene?.isColumnVisible(.leftWords) ?? false)
        XCTAssertEqual(viewModel.scene?.rows.count, LocatorPageSize.oneHundred.rawValue)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-100 / \(rowCount)")
        XCTAssertEqual(viewModel.selectedRowID, "42")
        XCTAssertEqual(viewModel.currentSource?.sentenceId, 42)
        XCTAssertEqual(viewModel.currentSource?.nodeIndex, source.nodeIndex)
    }

    func testTopicsLargeResultKeepsLatestSceneAfterRapidClusterSortPagingAndColumnChanges() {
        let viewModel = TopicsPageViewModel()
        let rowCount = LargeResultSceneBuildSupport.asyncThreshold + 190

        viewModel.apply(makeLargeTopicAnalysisResult(segmentCount: rowCount))
        viewModel.handle(.selectCluster("topic-large"))
        viewModel.handle(.changePageSize(.all))
        viewModel.handle(.toggleColumn(.score))
        viewModel.handle(.changeSort(.paragraphAscending))
        viewModel.handle(.sortByColumn(.excerpt))

        waitForMainRunLoop(description: "latest rapid topics scene built") {
            viewModel.scene?.selectedClusterID == "topic-large" &&
                viewModel.scene?.controls.selectedSort == .alphabeticalAscending &&
                viewModel.scene?.controls.selectedPageSize == .oneHundred &&
                viewModel.scene?.isColumnVisible(.score) == false
        }

        XCTAssertEqual(viewModel.selectedClusterID, "topic-large")
        XCTAssertEqual(viewModel.pageSize, .oneHundred)
        XCTAssertEqual(viewModel.scene?.controls.selectedSort, .alphabeticalAscending)
        XCTAssertEqual(viewModel.scene?.controls.selectedPageSize, .oneHundred)
        XCTAssertFalse(viewModel.scene?.isColumnVisible(.score) ?? true)
        XCTAssertEqual(viewModel.scene?.segmentRows.count, TopicsPageSize.oneHundred.rawValue)
        XCTAssertEqual(viewModel.scene?.visibleSegments, rowCount)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-100 / \(rowCount)")
        XCTAssertEqual(viewModel.selectedRowID, viewModel.scene?.selectedSegmentID)
    }

    func testClusterLargeResultKeepsLatestSceneAfterRapidFilterSortPagingColumnAndSelectionChanges() {
        let viewModel = ClusterPageViewModel()
        let rowCount = LargeResultSceneBuildSupport.asyncThreshold + 210
        let selectedRowID = "3|cluster-10"

        viewModel.apply(makeClusterResult(rowCount: rowCount))
        viewModel.handle(.changeMinFrequency("1"))
        viewModel.handle(.changePageSize(.all))
        viewModel.handle(.toggleColumn(.rank))
        viewModel.handle(.sortByColumn(.phrase))
        viewModel.handle(.selectRow(selectedRowID))

        XCTAssertEqual(viewModel.minimumFrequency, "1")
        XCTAssertEqual(viewModel.pageSize, .oneHundred)
        XCTAssertEqual(viewModel.scene?.minimumFrequency, 1)
        XCTAssertEqual(viewModel.scene?.filteredRows, rowCount)
        XCTAssertEqual(viewModel.scene?.sorting.selectedSort, .alphabeticalAscending)
        XCTAssertEqual(viewModel.scene?.sorting.selectedPageSize, .oneHundred)
        XCTAssertTrue(viewModel.scene?.table.isVisible(ClusterColumnKey.rank.rawValue) ?? false)
        XCTAssertEqual(viewModel.scene?.rows.count, ClusterPageSize.oneHundred.rawValue)
        XCTAssertEqual(viewModel.scene?.pagination.rangeLabel, "1-100 / \(rowCount)")
        XCTAssertEqual(viewModel.selectedRowID, selectedRowID)
        XCTAssertEqual(viewModel.scene?.selectedRowID, selectedRowID)
    }
}

private struct LargeResultInteractionSample {
    let label: String
    let durationMilliseconds: Double
}

private func recordInteractionDispatch(
    _ label: String,
    samples: inout [LargeResultInteractionSample],
    operation: () -> Void
) {
    let clock = ContinuousClock()
    let elapsed = clock.measure {
        operation()
    }
    samples.append(LargeResultInteractionSample(
        label: label,
        durationMilliseconds: milliseconds(elapsed)
    ))
}

private func percentile(_ values: [Double], _ percentile: Double) -> Double {
    guard !values.isEmpty else { return 0 }
    let sortedValues = values.sorted()
    guard sortedValues.count > 1 else { return sortedValues[0] }
    let clamped = min(max(percentile, 0), 1)
    let position = clamped * Double(sortedValues.count - 1)
    let lowerIndex = Int(position.rounded(.down))
    let upperIndex = Int(position.rounded(.up))
    guard lowerIndex != upperIndex else { return sortedValues[lowerIndex] }
    let weight = position - Double(lowerIndex)
    return sortedValues[lowerIndex] * (1 - weight) + sortedValues[upperIndex] * weight
}

private func milliseconds(_ duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds) * 1000
        + Double(components.attoseconds) / 1_000_000_000_000_000
}

private func makeTableRows(count: Int) -> [NativeTableRowDescriptor] {
    (0..<count).map { index in
        NativeTableRowDescriptor(
            id: "row-\(index)",
            values: [
                "word": "word-\(index)",
                "count": "\(count - index)"
            ]
        )
    }
}

private func keyEvent(
    keyCode: UInt16,
    characters: String,
    modifiers: NSEvent.ModifierFlags = []
) -> NSEvent {
    NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: modifiers,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: keyCode
    )!
}

@MainActor
private func waitForMainRunLoop(
    description: String,
    timeout: TimeInterval = 2.0,
    file: StaticString = #filePath,
    line: UInt = #line,
    condition: () -> Bool
) {
    let deadline = Date().addingTimeInterval(timeout)
    while !condition() && Date() < deadline {
        _ = RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
    }
    XCTAssertTrue(condition(), description, file: file, line: line)
}

private func makeLargeCompareResult(rowCount: Int) -> CompareResult {
    let corpora: [[String: Any]] = [
        [
            "corpusId": "corpus-1",
            "corpusName": "Demo Corpus",
            "folderName": "Default",
            "tokenCount": 10_000,
            "typeCount": 4_000,
            "ttr": 0.4,
            "sttr": 0.42,
            "topWord": "term-0",
            "topWordCount": rowCount
        ],
        [
            "corpusId": "corpus-2",
            "corpusName": "Compare Corpus",
            "folderName": "Default",
            "tokenCount": 12_000,
            "typeCount": 4_800,
            "ttr": 0.4,
            "sttr": 0.41,
            "topWord": "term-1",
            "topWordCount": max(rowCount - 1, 0)
        ]
    ]
    let rows: [[String: Any]] = (0..<rowCount).map { index in
        let targetCount = rowCount - index
        let referenceCount = index + 1
        return [
            "word": "term-\(index)",
            "total": targetCount + referenceCount,
            "spread": index % 2 == 0 ? 2 : 1,
            "range": Double(targetCount - referenceCount),
            "dominantCorpusName": targetCount >= referenceCount ? "Demo Corpus" : "Compare Corpus",
            "keyness": Double(rowCount - index) / 10.0,
            "effectSize": Double(rowCount - index) / 100.0,
            "pValue": Double(index + 1) / Double(rowCount + 1),
            "referenceNormFreq": Double(referenceCount) / 12_000.0 * 1_000_000.0,
            "perCorpus": [
                [
                    "corpusId": "corpus-1",
                    "corpusName": "Demo Corpus",
                    "folderName": "Default",
                    "count": targetCount,
                    "tokenCount": 10_000,
                    "normFreq": Double(targetCount) / 10_000.0 * 1_000_000.0
                ],
                [
                    "corpusId": "corpus-2",
                    "corpusName": "Compare Corpus",
                    "folderName": "Default",
                    "count": referenceCount,
                    "tokenCount": 12_000,
                    "normFreq": Double(referenceCount) / 12_000.0 * 1_000_000.0
                ]
            ]
        ]
    }
    return CompareResult(json: [
        "corpora": corpora,
        "rows": rows
    ])
}

private func makeLargeTokenizeResult(tokenCount: Int) -> TokenizeResult {
    let sentences = (0..<tokenCount).map { index in
        let original = "Token\(index)"
        let normalized = "token-\(index)"
        return TokenizedSentence(
            sentenceId: index,
            text: "\(original).",
            tokens: [
                TokenizedToken(
                    original: original,
                    normalized: normalized,
                    sentenceId: index,
                    tokenIndex: 0,
                    annotations: TokenLinguisticAnnotations(
                        script: .latin,
                        lemma: "lemma-\(index)",
                        lexicalClass: .noun
                    )
                )
            ]
        )
    }
    return TokenizeResult(sentences: sentences)
}

private func makeLargeKeywordSuiteResult(rowCount: Int) -> KeywordSuiteResult {
    let words = makeKeywordSuiteRows(group: .words, prefix: "word", rowCount: rowCount)
    let terms = makeKeywordSuiteRows(group: .terms, prefix: "term", rowCount: rowCount)
    return KeywordSuiteResult(
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
            tokenCount: rowCount * 20,
            typeCount: rowCount,
            isWordList: false
        ),
        referenceSummary: KeywordSuiteScopeSummary(
            label: "Reference Corpus",
            corpusCount: 1,
            corpusIDs: ["corpus-2"],
            corpusNames: ["Reference Corpus"],
            tokenCount: rowCount * 24,
            typeCount: rowCount,
            isWordList: false
        ),
        words: words,
        terms: terms,
        ngrams: []
    )
}

private func makeKeywordSuiteRows(
    group: KeywordResultGroup,
    prefix: String,
    rowCount: Int
) -> [KeywordSuiteRow] {
    (0..<rowCount).map { index in
        let focusFrequency = rowCount - index
        let referenceFrequency = index + 1
        return KeywordSuiteRow(
            group: group,
            item: "\(prefix)-\(index)",
            direction: index % 2 == 0 ? .positive : .negative,
            focusFrequency: focusFrequency,
            referenceFrequency: referenceFrequency,
            focusNormalizedFrequency: Double(focusFrequency) * 10,
            referenceNormalizedFrequency: Double(referenceFrequency) * 8,
            keynessScore: Double(rowCount - index) / 3,
            logRatio: Double(rowCount - index) / 100,
            pValue: Double(index + 1) / Double(rowCount + 1),
            focusRange: max(1, focusFrequency % 17),
            referenceRange: max(1, referenceFrequency % 13),
            example: "\(prefix)-\(index) example",
            focusExampleCorpusID: "corpus-1",
            referenceExampleCorpusID: "corpus-2"
        )
    }
}

private func makeLargeTopicAnalysisResult(segmentCount: Int) -> TopicAnalysisResult {
    let clusterID = "topic-large"
    let segments = (0..<segmentCount).map { index in
        TopicSegmentRow(
            id: "topic-segment-\(index)",
            topicID: clusterID,
            paragraphIndex: index + 1,
            text: "Topic segment \(index) covers a repeated large-result interaction fixture.",
            similarityScore: Double(segmentCount - index) / Double(max(segmentCount, 1)),
            isOutlier: false,
            sourceID: "corpus-1",
            sourceTitle: "Demo Corpus",
            groupID: "topic-large-group",
            groupTitle: "Large Topic",
            sourceParagraphIndex: index + 1
        )
    }
    return TopicAnalysisResult(
        modelVersion: "wordz-topics-large-test",
        modelProvider: "system-sentence-embedding",
        usesFallbackProvider: false,
        clusters: [
            TopicClusterSummary(
                id: clusterID,
                index: 1,
                isOutlier: false,
                size: segmentCount,
                keywordCandidates: [
                    TopicKeywordCandidate(term: "large", score: 1.4),
                    TopicKeywordCandidate(term: "interaction", score: 1.1)
                ],
                representativeSegmentIDs: ["topic-segment-0"]
            )
        ],
        segments: segments,
        totalSegments: segmentCount,
        clusteredSegments: segmentCount,
        outlierCount: 0,
        warnings: []
    )
}

private func makeLargeSentimentResult(rowCount: Int) -> SentimentRunResult {
    let base = makeSentimentResult()
    let rows = (0..<rowCount).map { index in
        let template = base.rows[index % base.rows.count]
        return SentimentRowResult(
            id: "sentiment-\(index)",
            sourceID: template.sourceID,
            sourceTitle: template.sourceTitle,
            groupID: template.groupID,
            groupTitle: template.groupTitle,
            text: "\(template.text) #\(index)",
            positivityScore: template.positivityScore,
            negativityScore: template.negativityScore,
            neutralityScore: template.neutralityScore,
            finalLabel: template.finalLabel,
            netScore: template.netScore,
            evidence: template.evidence,
            evidenceCount: template.evidenceCount,
            mixedEvidence: template.mixedEvidence,
            diagnostics: template.diagnostics,
            sentenceID: index,
            tokenIndex: template.tokenIndex
        )
    }
    let positiveCount = rows.filter { $0.finalLabel == .positive }.count
    let neutralCount = rows.filter { $0.finalLabel == .neutral }.count
    let negativeCount = rows.filter { $0.finalLabel == .negative }.count
    let summary = SentimentAggregateSummary(
        id: "overall",
        title: "Overall",
        totalTexts: rowCount,
        positiveCount: positiveCount,
        neutralCount: neutralCount,
        negativeCount: negativeCount,
        positiveRatio: rowCount == 0 ? 0 : Double(positiveCount) / Double(rowCount),
        neutralRatio: rowCount == 0 ? 0 : Double(neutralCount) / Double(rowCount),
        negativeRatio: rowCount == 0 ? 0 : Double(negativeCount) / Double(rowCount),
        averagePositivity: rows.map(\.positivityScore).performanceBoundaryAverage,
        averageNeutrality: rows.map(\.neutralityScore).performanceBoundaryAverage,
        averageNegativity: rows.map(\.negativityScore).performanceBoundaryAverage,
        averageNetScore: rows.map(\.netScore).performanceBoundaryAverage
    )
    return SentimentRunResult(
        request: base.request,
        backendKind: base.backendKind,
        backendRevision: base.backendRevision,
        resourceRevision: base.resourceRevision,
        providerID: base.providerID,
        providerFamily: base.providerFamily,
        supportsEvidenceHits: base.supportsEvidenceHits,
        rows: rows,
        overallSummary: summary,
        groupSummaries: [summary],
        lexiconVersion: base.lexiconVersion,
        activeRuleProfileRevision: base.activeRuleProfileRevision,
        activePackIDs: base.activePackIDs,
        calibrationProfileRevision: base.calibrationProfileRevision,
        userLexiconBundleIDs: base.userLexiconBundleIDs
    )
}

private extension Array where Element == Double {
    var performanceBoundaryAverage: Double {
        isEmpty ? 0 : reduce(0, +) / Double(count)
    }
}

@MainActor
private final class RecordingTableView: NSTableView {
    var forcedVisibleRange = NSRange(location: 0, length: 0)
    private(set) var fullReloadCount = 0
    private(set) var noteNumberOfRowsChangedCount = 0
    private(set) var partialReloads: [(rows: IndexSet, columns: IndexSet)] = []

    override func rows(in rect: NSRect) -> NSRange {
        forcedVisibleRange
    }

    override func reloadData() {
        fullReloadCount += 1
        super.reloadData()
    }

    override func reloadData(forRowIndexes rowIndexes: IndexSet, columnIndexes: IndexSet) {
        partialReloads.append((rowIndexes, columnIndexes))
        super.reloadData(forRowIndexes: rowIndexes, columnIndexes: columnIndexes)
    }

    override func noteNumberOfRowsChanged() {
        noteNumberOfRowsChangedCount += 1
        super.noteNumberOfRowsChanged()
    }

    func resetRecording() {
        fullReloadCount = 0
        noteNumberOfRowsChangedCount = 0
        partialReloads = []
    }
}
