import AppKit
import XCTest
@testable import WordZWorkspaceCore

final class NativeTableViewTests: XCTestCase {
    func testRowDescriptorKeepsTypedCellValuesBehindStringCompatibility() {
        let row = NativeTableRowDescriptor(
            id: "alpha",
            cells: [
                "word": .text("alpha"),
                "count": .integer(12),
                "score": .decimal(0.25),
                "kept": .boolean(true)
            ]
        )

        XCTAssertEqual(row.cell(for: "count"), .integer(12))
        XCTAssertEqual(row.value(for: "word"), "alpha")
        XCTAssertEqual(row.value(for: "count"), "12")
        XCTAssertEqual(row.value(for: "score"), "0.25")
        XCTAssertEqual(row.values["kept"], "true")
    }

    func testTypedColumnAndRowBuildersKeepColumnKeysTyped() {
        enum TestColumn: String, Sendable {
            case word
            case count
            case plot
        }

        let descriptor = NativeTableDescriptor(
            storageKey: "typed-builder-test",
            columnKey: TestColumn.self
        ) {
            NativeTableColumnSpec(.word, title: "Word", isVisible: true, presentation: .keyword)
            NativeTableColumnSpec(
                .count,
                title: "Count",
                isVisible: true,
                sortDirection: .descending,
                presentation: .numeric(precision: 0),
                widthPolicy: .numeric
            )
            NativeTableColumnSpec(.plot, title: "Plot", isVisible: true, presentation: .custom(.markerStrip))
        }
        let row = NativeTableRowDescriptor(
            id: "alpha",
            columnKey: TestColumn.self
        ) {
            NativeTableCell(.word, "alpha")
            NativeTableCell(.count, value: .integer(12))
            NativeTableCell(
                .plot,
                value: .custom(
                    text: "0.25",
                    presentation: .markerStrip([
                        NativeTableMarkerValue(
                            id: "hit-1",
                            normalizedPosition: 0.25,
                            accessibilityLabel: "Hit 1"
                        )
                    ])
                )
            )
        }

        XCTAssertEqual(descriptor.column(for: TestColumn.count)?.sortDirection, .descending)
        XCTAssertEqual(descriptor.displayTitle(for: TestColumn.count, fallback: "Count"), "Count ↓")
        XCTAssertEqual(row.value(for: TestColumn.word), "alpha")
        XCTAssertEqual(row.cell(for: TestColumn.count), .integer(12))
        XCTAssertEqual(row.value(for: TestColumn.plot), "0.25")
    }

    func testTypedRowDescriptorKeepsCellsTypedUntilExplicitErasure() {
        enum TestColumn: String, Sendable {
            case word
            case count
        }

        let typedRow = NativeTableTypedRowDescriptor(
            id: "alpha",
            columnKey: TestColumn.self
        ) {
            NativeTableCell(.word, "alpha")
            NativeTableCell(.count, value: .integer(12))
        }

        XCTAssertEqual(typedRow.cells.map(\.columnID), ["word", "count"])
        XCTAssertEqual(typedRow.value(for: .word), "alpha")
        XCTAssertEqual(typedRow.cell(for: .count), .integer(12))

        let erasedRow = typedRow.erased
        XCTAssertEqual(erasedRow.value(for: TestColumn.word), "alpha")
        XCTAssertEqual(erasedRow.cell(for: TestColumn.count), .integer(12))
    }

    func testTypedRowBuilderReportsDuplicateColumnKeysBeforeDictionaryCoalescing() {
        enum TestColumn: String, Sendable {
            case word
            case count
        }

        let duplicateColumnIDs = NativeTableRowDescriptor.duplicateColumnIDs(
            in: [
                NativeTableCell(.word, "alpha"),
                NativeTableCell(.count, value: .integer(12)),
                NativeTableCell(.word, "beta"),
                NativeTableCell(.word, "gamma")
            ] as [NativeTableCell<TestColumn>]
        )

        XCTAssertEqual(duplicateColumnIDs, ["word"])
    }

    func testResultTableSnapshotKeepsFirstIndexForDuplicateRowIDs() {
        let rows = [
            NativeTableRowDescriptor(id: "duplicate", values: ["word": "first"]),
            NativeTableRowDescriptor(id: "duplicate", values: ["word": "second"]),
            NativeTableRowDescriptor(id: "unique", values: ["word": "third"])
        ]

        let snapshot = ResultTableSnapshot.stable(rows: rows)

        XCTAssertEqual(snapshot.rowIndexByID["duplicate"], 0)
        XCTAssertEqual(snapshot.rowIndexByID["unique"], 2)
    }

    func testWorkbenchTablePreferencesKeepEmbeddedTablesFiniteInsideScrollingLayouts() {
        XCTAssertEqual(WorkbenchTablePreferences.minimumEmbeddedTableHeight, 360)
        XCTAssertEqual(WorkbenchTablePreferences.defaultTableHeight, 430)
        XCTAssertEqual(WorkbenchTablePreferences.maximumEmbeddedTableHeight, 560)
    }

    @MainActor
    func testWorkbenchColumnMenuDisablesOnlyTheLastVisibleColumn() {
        enum TestColumn: String, Identifiable {
            case word
            case count

            var id: String { rawValue }
        }

        let keys: [TestColumn] = [.word, .count]

        XCTAssertEqual(
            WorkbenchColumnMenu<TestColumn>.visibleCount(keys: keys) { $0 == .word },
            1
        )
        XCTAssertFalse(
            WorkbenchColumnMenu<TestColumn>.canToggle(.word, keys: keys) { $0 == .word }
        )
        XCTAssertTrue(
            WorkbenchColumnMenu<TestColumn>.canToggle(.count, keys: keys) { $0 == .word }
        )
        XCTAssertTrue(
            WorkbenchColumnMenu<TestColumn>.canToggle(.word, keys: keys) { _ in true }
        )
    }

    @MainActor
    func testCoordinatorBuildsColumnsOnInitialApplyEvenWhenDescriptorDoesNotChange() {
        let descriptor = NativeTableDescriptor(columns: [
            NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil),
            NativeTableColumnDescriptor(id: "count", title: "频次", isVisible: true, sortIndicator: "↓")
        ])
        let rows = [
            NativeTableRowDescriptor(id: "alpha", values: ["word": "alpha", "count": "10"])
        ]

        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        let tableView = NSTableView(frame: .zero)

        coordinator.attach(tableView: tableView)
        coordinator.apply(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )

        XCTAssertEqual(tableView.tableColumns.map(\.identifier.rawValue), ["word", "count"])
        XCTAssertEqual(coordinator.numberOfRows(in: tableView), 1)
    }

    @MainActor
    func testCoordinatorInvokesHeaderSortAndColumnMenuCallbacks() {
        let descriptor = NativeTableDescriptor(columns: [
            NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil),
            NativeTableColumnDescriptor(id: "count", title: "频次", isVisible: true, sortIndicator: nil)
        ])
        let rows = [
            NativeTableRowDescriptor(id: "alpha", values: ["word": "alpha", "count": "10"])
        ]

        var sortedColumn: String?
        var toggledColumn: String?
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil,
            onSortByColumn: { sortedColumn = $0 },
            onToggleColumnFromHeader: { toggledColumn = $0 }
        )
        let tableView = NSTableView(frame: .zero)
        let containerView = NativeTableView.IntrinsicTableContainerView(frame: .zero)
        containerView.scrollView.documentView = tableView

        coordinator.attach(tableView: tableView, containerView: containerView)
        coordinator.apply(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil,
            onSortByColumn: { sortedColumn = $0 },
            onToggleColumnFromHeader: { toggledColumn = $0 }
        )

        coordinator.tableView(tableView, didClick: tableView.tableColumns[0])
        XCTAssertEqual(sortedColumn, "word")

        let item = NSMenuItem(title: "频次", action: nil, keyEquivalent: "")
        item.representedObject = "count"
        coordinator.handleHeaderMenuSelection(item)
        XCTAssertEqual(toggledColumn, "count")
        XCTAssertNotNil(containerView.scrollView.documentView)
        XCTAssertNotNil(tableView.headerView?.menu)
    }

    @MainActor
    func testCoordinatorMapsSortDirectionToAppKitColumnMetadata() {
        let descriptor = NativeTableDescriptor(columns: [
            NativeTableColumnDescriptor(
                id: "count",
                title: "Count",
                isVisible: true,
                sortIndicator: nil,
                sortDirection: .descending,
                presentation: .numeric(precision: 0)
            )
        ])
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: [],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        let tableView = NSTableView(frame: .zero)

        coordinator.attach(tableView: tableView)
        coordinator.apply(
            descriptor: descriptor,
            rows: [],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )

        let column = tableView.tableColumns[0]
        XCTAssertEqual(column.title, "Count")
        XCTAssertEqual(column.sortDescriptorPrototype?.key, "count")
        XCTAssertEqual(column.sortDescriptorPrototype?.ascending, false)
        XCTAssertEqual(tableView.sortDescriptors.first?.key, "count")
        XCTAssertEqual(tableView.sortDescriptors.first?.ascending, false)
        XCTAssertTrue(column.headerToolTip?.contains("descending") == true || column.headerToolTip?.contains("降序") == true)
    }

    @MainActor
    func testCoordinatorRestoresPersistedColumnOrder() {
        let storageKey = "native-table-test-\(UUID().uuidString)"
        let orderKey = "wordz.nativeTable.v3.\(storageKey).columnOrder"
        UserDefaults.standard.set(["count", "word"], forKey: orderKey)
        defer { UserDefaults.standard.removeObject(forKey: orderKey) }

        let descriptor = NativeTableDescriptor(
            storageKey: storageKey,
            columns: [
                NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "频次", isVisible: true, sortIndicator: nil)
            ]
        )
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: [],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        let tableView = NSTableView(frame: .zero)

        coordinator.attach(tableView: tableView)
        coordinator.apply(
            descriptor: descriptor,
            rows: [],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )

        XCTAssertEqual(tableView.tableColumns.map(\.identifier.rawValue), ["count", "word"])
    }

    @MainActor
    func testResetLayoutClearsStoredWidthsAndColumnOrder() {
        let storageKey = "native-table-test-\(UUID().uuidString)"
        let orderKey = "wordz.nativeTable.v3.\(storageKey).columnOrder"
        let widthKey = "wordz.nativeTable.v3.\(storageKey).word.width"
        UserDefaults.standard.set(["count", "word"], forKey: orderKey)
        UserDefaults.standard.set(240.0, forKey: widthKey)
        defer {
            UserDefaults.standard.removeObject(forKey: orderKey)
            UserDefaults.standard.removeObject(forKey: widthKey)
        }

        let descriptor = NativeTableDescriptor(
            storageKey: storageKey,
            columns: [
                NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil),
                NativeTableColumnDescriptor(id: "count", title: "频次", isVisible: true, sortIndicator: nil)
            ]
        )
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: [],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        let tableView = NSTableView(frame: .zero)
        let containerView = NativeTableView.IntrinsicTableContainerView(frame: .zero)
        containerView.scrollView.documentView = tableView

        coordinator.attach(tableView: tableView, containerView: containerView)
        coordinator.apply(
            descriptor: descriptor,
            rows: [],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        coordinator.handleResetTableLayout(NSMenuItem(title: "恢复默认列布局", action: nil, keyEquivalent: ""))

        XCTAssertNil(UserDefaults.standard.stringArray(forKey: orderKey))
        XCTAssertEqual(UserDefaults.standard.double(forKey: widthKey), 0)
        XCTAssertEqual(tableView.tableColumns.map(\.identifier.rawValue), ["word", "count"])
    }

    @MainActor
    func testCoordinatorClampsPersistedOversizedColumnWidthToCompactMaximum() {
        let storageKey = "native-table-width-clamp-\(UUID().uuidString)"
        let widthKey = "wordz.nativeTable.v3.\(storageKey).word.width"
        UserDefaults.standard.set(1200.0, forKey: widthKey)
        defer { UserDefaults.standard.removeObject(forKey: widthKey) }

        let descriptor = NativeTableDescriptor(
            storageKey: storageKey,
            columns: [
                NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil)
            ]
        )
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: [],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        let tableView = NSTableView(frame: .zero)

        coordinator.attach(tableView: tableView)
        coordinator.apply(
            descriptor: descriptor,
            rows: [],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )

        XCTAssertEqual(Double(tableView.tableColumns.first?.width ?? 0), 280, accuracy: 0.1)
    }

    @MainActor
    func testCoordinatorRestoresPersistedDensitySelection() {
        let storageKey = "native-table-density-\(UUID().uuidString)"
        let densityKey = "wordz.nativeTable.v3.\(storageKey).density"
        UserDefaults.standard.set(NativeTableDensityPreset.reading.rawValue, forKey: densityKey)
        defer { UserDefaults.standard.removeObject(forKey: densityKey) }

        let descriptor = NativeTableDescriptor(
            storageKey: storageKey,
            columns: [
                NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil)
            ],
            defaultDensity: .compact
        )
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: [],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        let tableView = NativeTableView.ActionTableView(frame: .zero)

        coordinator.attach(tableView: tableView)
        coordinator.apply(
            descriptor: descriptor,
            rows: [],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )

        XCTAssertEqual(tableView.rowHeight, 30, accuracy: 0.1)
    }

    @MainActor
    func testCoordinatorTogglesEmbeddedEmptyState() {
        let descriptor = NativeTableDescriptor(columns: [
            NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil)
        ])
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: [],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        let tableView = NativeTableView.ActionTableView(frame: .zero)
        let containerView = NativeTableView.IntrinsicTableContainerView(frame: .zero)
        containerView.scrollView.documentView = tableView

        coordinator.attach(tableView: tableView, containerView: containerView)
        coordinator.apply(
            descriptor: descriptor,
            rows: [],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil,
            emptyMessage: "No rows"
        )
        XCTAssertTrue(containerView.scrollView.isHidden)

        coordinator.apply(
            descriptor: descriptor,
            rows: [NativeTableRowDescriptor(id: "alpha", values: ["word": "alpha"])],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil,
            emptyMessage: "No rows"
        )
        XCTAssertFalse(containerView.scrollView.isHidden)
    }

    @MainActor
    func testCoordinatorBuildsCopyPayloadFromSelectedRow() {
        let descriptor = NativeTableDescriptor(columns: [
            NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil),
            NativeTableColumnDescriptor(id: "count", title: "频次", isVisible: true, sortIndicator: nil)
        ])
        let rows = [
            NativeTableRowDescriptor(id: "alpha", values: ["word": "alpha", "count": "10"]),
            NativeTableRowDescriptor(id: "beta", values: ["word": "beta", "count": "5"])
        ]
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: "alpha",
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        let tableView = NativeTableView.ActionTableView(frame: .zero)
        let containerView = NativeTableView.IntrinsicTableContainerView(frame: .zero)
        containerView.scrollView.documentView = tableView

        coordinator.attach(tableView: tableView, containerView: containerView)
        coordinator.apply(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: "alpha",
            onSelectionChange: nil,
            onDoubleClick: nil
        )

        XCTAssertEqual(
            coordinator.selectedRowsCopyPayload(),
            "词\t频次\nalpha\t10"
        )
    }

    @MainActor
    func testCoordinatorCopyPayloadIsNilWithoutSelection() {
        let descriptor = NativeTableDescriptor(columns: [
            NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil)
        ])
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: [NativeTableRowDescriptor(id: "alpha", values: ["word": "alpha"])],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )
        let tableView = NativeTableView.ActionTableView(frame: .zero)
        coordinator.attach(tableView: tableView)
        coordinator.apply(
            descriptor: descriptor,
            rows: [NativeTableRowDescriptor(id: "alpha", values: ["word": "alpha"])],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )

        XCTAssertEqual(
            coordinator.selectedRowsCopyPayload(),
            nil
        )
    }

    @MainActor
    func testCoordinatorActivatesSelectedRowFromKeyboardSelection() {
        let descriptor = NativeTableDescriptor(columns: [
            NativeTableColumnDescriptor(id: "word", title: "词", isVisible: true, sortIndicator: nil)
        ])
        let rows = [
            NativeTableRowDescriptor(id: "alpha", values: ["word": "alpha"])
        ]
        var activatedRowID: String?
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: "alpha",
            onSelectionChange: nil,
            onDoubleClick: { activatedRowID = $0 }
        )
        let tableView = NativeTableView.ActionTableView(frame: .zero)
        coordinator.attach(tableView: tableView)
        coordinator.apply(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: "alpha",
            onSelectionChange: nil,
            onDoubleClick: { activatedRowID = $0 },
            accessibilityLabel: "Stats results table",
            activationHint: "Press Return to activate."
        )

        XCTAssertTrue(coordinator.activateSelectedRow())
        XCTAssertEqual(activatedRowID, "alpha")
        XCTAssertEqual(tableView.accessibilityLabel(), "Stats results table")
        XCTAssertEqual(tableView.accessibilityHelp(), "Press Return to activate.")
    }

    @MainActor
    func testCoordinatorRendersAndSelectsCustomMarkerStripCells() {
        let descriptor = NativeTableDescriptor(
            storageKey: "marker-strip-test",
            columns: [
                NativeTableColumnDescriptor(
                    id: "plot",
                    title: "Plot",
                    isVisible: true,
                    sortIndicator: nil,
                    presentation: .custom(.markerStrip),
                    widthPolicy: .context
                )
            ]
        )
        let rows = [
            NativeTableRowDescriptor(
                id: "alpha",
                cells: [
                    "plot": .custom(
                        text: "0.25 | 0.75",
                        presentation: .markerStrip([
                            NativeTableMarkerValue(id: "hit-1", normalizedPosition: 0.25, accessibilityLabel: "Hit 1"),
                            NativeTableMarkerValue(id: "hit-2", normalizedPosition: 0.75, accessibilityLabel: "Hit 2")
                        ])
                    )
                ]
            )
        ]
        var selectedMarker: (rowID: String, markerID: String?)?
        var activatedRowID: String?
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: "alpha",
            onSelectionChange: nil,
            onDoubleClick: { activatedRowID = $0 },
            selectedMarkerID: "hit-2",
            onMarkerSelectionChange: { selectedMarker = ($0, $1) }
        )
        let tableView = NativeTableView.ActionTableView(frame: .zero)
        let containerView = NativeTableView.IntrinsicTableContainerView(frame: .zero)
        containerView.scrollView.documentView = tableView

        coordinator.attach(tableView: tableView, containerView: containerView)
        coordinator.apply(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: "alpha",
            onSelectionChange: nil,
            onDoubleClick: { activatedRowID = $0 },
            selectedMarkerID: "hit-2",
            onMarkerSelectionChange: { selectedMarker = ($0, $1) }
        )

        let cellView = coordinator.tableView(
            tableView,
            viewFor: tableView.tableColumns[0],
            row: 0
        ) as? NativeTableView.MarkerStripCellView
        XCTAssertEqual(cellView?.markers.map(\.id), ["hit-1", "hit-2"])
        XCTAssertEqual(cellView?.selectedMarkerID, "hit-2")
        XCTAssertEqual(cellView?.accessibilityValue() as? String, "Hit 2")
        XCTAssertEqual(cellView?.accessibilityCustomActions()?.count, 5)

        let accessibilityChildren = cellView?.accessibilityChildren() as? [NativeTableView.MarkerAccessibilityElement]
        XCTAssertEqual(accessibilityChildren?.count, 2)
        XCTAssertEqual(accessibilityChildren?.first?.accessibilityRole(), .button)
        XCTAssertEqual(accessibilityChildren?.first?.accessibilityLabel(), "Hit 1")
        let selectedAccessibilityValue = accessibilityChildren?.last?.accessibilityValue() as? String
        XCTAssertTrue(
            ["Selected", "已选择"].contains(selectedAccessibilityValue ?? ""),
            "Expected the selected marker accessibility value to follow the active localization."
        )
        XCTAssertTrue(accessibilityChildren?.first?.accessibilityPerformPress() == true)
        XCTAssertEqual(selectedMarker?.rowID, "alpha")
        XCTAssertEqual(selectedMarker?.markerID, "hit-1")

        XCTAssertTrue(coordinator.selectAdjacentMarker(direction: .next))
        XCTAssertEqual(selectedMarker?.rowID, "alpha")
        XCTAssertEqual(selectedMarker?.markerID, "hit-2")

        coordinator.selectMarker(rowID: "alpha", markerID: "hit-1", activate: true)
        XCTAssertEqual(selectedMarker?.rowID, "alpha")
        XCTAssertEqual(selectedMarker?.markerID, "hit-1")
        XCTAssertEqual(activatedRowID, "alpha")
    }

    @MainActor
    func testCoordinatorFormatsNumericValuesWithStablePrecision() {
        let descriptor = NativeTableDescriptor(columns: [
            NativeTableColumnDescriptor(
                id: "score",
                title: "Score",
                isVisible: true,
                sortIndicator: nil,
                presentation: .numeric(precision: 2, usesGrouping: false)
            )
        ])
        let coordinator = NativeTableView.Coordinator(
            descriptor: descriptor,
            rows: [],
            selectedRowID: nil,
            onSelectionChange: nil,
            onDoubleClick: nil
        )

        XCTAssertEqual(
            coordinator.formattedNumericValue("1234.5", precision: 2, usesGrouping: false),
            "1234.50"
        )
        XCTAssertEqual(
            coordinator.formattedNumericValue("0.0001", precision: 2, usesGrouping: false),
            "<0.01"
        )
        XCTAssertEqual(
            coordinator.formattedNumericValue("-0.0001", precision: 2, usesGrouping: false),
            "-<0.01"
        )
    }
}
