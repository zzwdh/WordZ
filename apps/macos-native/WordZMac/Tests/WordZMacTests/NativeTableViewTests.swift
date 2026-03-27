import AppKit
import XCTest
@testable import WordZMac

final class NativeTableViewTests: XCTestCase {
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
    func testCoordinatorRestoresPersistedColumnOrder() {
        let storageKey = "native-table-test-\(UUID().uuidString)"
        let orderKey = "wordz.nativeTable.\(storageKey).columnOrder"
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
        let orderKey = "wordz.nativeTable.\(storageKey).columnOrder"
        let widthKey = "wordz.nativeTable.\(storageKey).word.width"
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
}
