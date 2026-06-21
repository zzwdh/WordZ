import AppKit
import WordZExport

protocol NativeTablePasteboardWriting: AnyObject {
    func clearContents() -> Int
    func declareTypes(_ newTypes: [NSPasteboard.PasteboardType], owner newOwner: Any?) -> Int
    func setString(_ string: String, forType dataType: NSPasteboard.PasteboardType) -> Bool
}

extension NSPasteboard: NativeTablePasteboardWriting {}

extension NativeTableView.Coordinator {
    @MainActor
    func syncSelection() {
        guard let tableView else { return }
        guard !rows.isEmpty else {
            clearCellSelection()
            if tableView.selectedRow != -1 {
                tableView.deselectAll(nil)
            }
            return
        }

        if !selectedRowIDs.isEmpty {
            let indexes = IndexSet(selectedRowIDs.compactMap { rowIndexByID[$0] })
            if !indexes.isEmpty, tableView.selectedRowIndexes != indexes {
                tableView.selectRowIndexes(indexes, byExtendingSelection: false)
                if let first = indexes.first {
                    tableView.scrollRowToVisible(first)
                }
            }
            return
        }

        guard let selectedRowID else {
            if tableView.selectedRow != -1 {
                tableView.deselectAll(nil)
            }
            return
        }

        guard let rowIndex = rowIndexByID[selectedRowID] else {
            if tableView.selectedRow != -1 {
                tableView.deselectAll(nil)
            }
            return
        }

        if tableView.selectedRow != rowIndex {
            tableView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
            tableView.scrollRowToVisible(rowIndex)
        }
    }

    @MainActor
    func syncEmptyState() {
        containerView?.updateEmptyState(message: emptyMessage, isEmpty: rows.isEmpty)
    }

    @MainActor
    func reloadVisibleRows(previousRowCount: Int) -> ReloadOutcome {
        guard let tableView else { return .none }
        if previousRowCount != rows.count {
            tableView.noteNumberOfRowsChanged()
        }

        let columnCount = tableView.numberOfColumns
        guard columnCount > 0 else {
            tableView.reloadData()
            return ReloadOutcome(
                mode: .fullMissingColumns,
                reloadedRowCount: rows.count
            )
        }

        let visibleRange = tableView.rows(in: tableView.visibleRect)
        var rowIndexes = IndexSet()
        if visibleRange.length > 0 {
            let upperBound = min(visibleRange.location + visibleRange.length, rows.count)
            if visibleRange.location < upperBound {
                rowIndexes.formUnion(IndexSet(integersIn: visibleRange.location..<upperBound))
            }
        }
        resolvedSelectedRowIndexes().forEach { index in
            guard index >= 0, index < rows.count else { return }
            rowIndexes.insert(index)
        }

        guard !rowIndexes.isEmpty else {
            tableView.reloadData()
            return ReloadOutcome(
                mode: .fullNoVisibleRows,
                reloadedRowCount: rows.count
            )
        }
        tableView.reloadData(
            forRowIndexes: rowIndexes,
            columnIndexes: IndexSet(integersIn: 0..<columnCount)
        )
        return ReloadOutcome(
            mode: .partialVisibleRows,
            reloadedRowCount: rowIndexes.count
        )
    }

    @MainActor
    func reloadCustomPresentationRows(
        previousSelectedRowID: String?,
        selectedRowID: String?
    ) -> ReloadOutcome {
        guard let tableView else { return .none }
        let customColumnIndexes = descriptor.visibleColumns.compactMap { column -> Int? in
            guard case .custom = column.presentation else { return nil }
            return tableView.tableColumns.firstIndex(where: { $0.identifier.rawValue == column.id })
        }
        guard !customColumnIndexes.isEmpty else { return .none }

        var rowIndexes = IndexSet()
        [previousSelectedRowID, selectedRowID].forEach { rowID in
            guard let rowID, let index = rowIndexByID[rowID], index >= 0, index < rows.count else { return }
            rowIndexes.insert(index)
        }
        guard !rowIndexes.isEmpty else { return .none }

        tableView.reloadData(
            forRowIndexes: rowIndexes,
            columnIndexes: IndexSet(customColumnIndexes)
        )
        return ReloadOutcome(
            mode: .partialVisibleRows,
            reloadedRowCount: rowIndexes.count
        )
    }

    @MainActor
    func reloadSelectionAppearanceRows(
        previousSelectedRowID: String?,
        previousSelectedRowIDs: Set<String>,
        selectedRowID: String?,
        selectedRowIDs: Set<String>
    ) -> ReloadOutcome {
        guard let tableView else { return .none }
        let columnCount = tableView.numberOfColumns
        guard columnCount > 0 else { return .none }

        var affectedRowIDs = previousSelectedRowIDs.union(selectedRowIDs)
        if let previousSelectedRowID {
            affectedRowIDs.insert(previousSelectedRowID)
        }
        if let selectedRowID {
            affectedRowIDs.insert(selectedRowID)
        }

        let visibleRange = tableView.rows(in: tableView.visibleRect)
        guard visibleRange.length > 0 else { return .none }
        let visibleUpperBound = visibleRange.location + visibleRange.length
        var rowIndexes = IndexSet()
        affectedRowIDs.compactMap { rowIndexByID[$0] }
            .filter { index in
                index >= 0 &&
                    index < rows.count &&
                    index >= visibleRange.location &&
                    index < visibleUpperBound
            }
            .forEach { rowIndexes.insert($0) }
        guard !rowIndexes.isEmpty else { return .none }

        tableView.reloadData(
            forRowIndexes: rowIndexes,
            columnIndexes: IndexSet(integersIn: 0..<columnCount)
        )
        return ReloadOutcome(
            mode: .partialVisibleRows,
            reloadedRowCount: rowIndexes.count
        )
    }

    @MainActor
    func isRowSelected(_ rowID: String) -> Bool {
        rowID == selectedRowID || selectedRowIDs.contains(rowID)
    }

    @MainActor
    func selectedRowIndexes() -> [Int] {
        guard let tableView else { return [] }
        return tableView.selectedRowIndexes.compactMap { index in
            guard index >= 0, index < rows.count else { return nil }
            return index
        }
    }

    @MainActor
    @discardableResult
    func copySelectedRowsToPasteboard(_ pasteboard: any NativeTablePasteboardWriting = NSPasteboard.general) -> Bool {
        guard let payload = selectedCellsCopyPayload() ?? selectedRowsCopyPayload() else { return false }
        _ = pasteboard.clearContents()
        _ = pasteboard.declareTypes([.string], owner: nil)
        return pasteboard.setString(payload, forType: .string)
    }

    @MainActor
    @discardableResult
    func handleCellSelectionMouseDown(
        rowIndex: Int,
        columnIndex: Int,
        modifierFlags: NSEvent.ModifierFlags
    ) -> Bool {
        let commandOnly = modifierFlags.intersection([.command, .shift, .option, .control]) == .command
        guard commandOnly else {
            clearCellSelection()
            return false
        }

        guard rowIndex >= 0, rowIndex < rows.count else { return false }
        let rowID = rows[rowIndex].id
        let canToggleCell = selectedCellKeys.isEmpty
            ? isRowSelected(rowID)
            : true
        guard canToggleCell else { return false }

        return toggleCellSelection(rowIndex: rowIndex, columnIndex: columnIndex)
    }

    @MainActor
    @discardableResult
    func selectCellForCopy(rowID: String, columnID: String, extending: Bool = true) -> Bool {
        guard
            let rowIndex = rowIndexByID[rowID],
            rowIndex >= 0,
            rowIndex < rows.count,
            orderedVisibleColumns().contains(where: { $0.id == columnID })
        else {
            return false
        }

        let previousCellKeys = selectedCellKeys
        if !extending {
            selectedCellKeys.removeAll()
        }
        selectedCellKeys = selectedCellKeys.filter { $0.rowID == rowID }
        selectedCellKeys.insert(CellSelectionKey(rowID: rowID, columnID: columnID))
        ensureSingleRowSelection(rowIndex: rowIndex)
        reloadCellSelectionAppearance(previousCellKeys: previousCellKeys, selectedCellKeys: selectedCellKeys)
        rebuildRowMenu()
        return true
    }

    @MainActor
    @discardableResult
    func toggleCellSelection(rowIndex: Int, columnIndex: Int) -> Bool {
        guard
            let tableView,
            rowIndex >= 0,
            rowIndex < rows.count,
            columnIndex >= 0,
            columnIndex < tableView.tableColumns.count
        else {
            return false
        }

        let rowID = rows[rowIndex].id
        let columnID = tableView.tableColumns[columnIndex].identifier.rawValue
        guard orderedVisibleColumns().contains(where: { $0.id == columnID }) else { return false }

        let previousCellKeys = selectedCellKeys
        selectedCellKeys = selectedCellKeys.filter { $0.rowID == rowID }
        let key = CellSelectionKey(rowID: rowID, columnID: columnID)
        if selectedCellKeys.contains(key) {
            selectedCellKeys.remove(key)
        } else {
            selectedCellKeys.insert(key)
        }

        ensureSingleRowSelection(rowIndex: rowIndex)
        reloadCellSelectionAppearance(previousCellKeys: previousCellKeys, selectedCellKeys: selectedCellKeys)
        rebuildRowMenu()
        return true
    }

    @MainActor
    func clearCellSelection() {
        guard !selectedCellKeys.isEmpty else { return }
        let previousCellKeys = selectedCellKeys
        selectedCellKeys.removeAll()
        reloadCellSelectionAppearance(previousCellKeys: previousCellKeys, selectedCellKeys: selectedCellKeys)
        rebuildRowMenu()
    }

    @MainActor
    func isCellSelected(rowID: String, columnID: String) -> Bool {
        selectedCellKeys.contains(CellSelectionKey(rowID: rowID, columnID: columnID))
    }

    @MainActor
    @discardableResult
    func activateSelectedRow() -> Bool {
        guard let rowIndex = resolvedSelectedRowIndexes().first, rowIndex < rows.count else {
            return false
        }
        let rowID = rows[rowIndex].id
        if selectedRowID != rowID {
            selectedRowID = rowID
            onSelectionChange?(rowID)
        }
        onDoubleClick?(rowID)
        return true
    }

    @MainActor
    func selectMarker(rowID: String, markerID: String?, activate: Bool) {
        guard let rowIndex = rowIndexByID[rowID], rowIndex >= 0, rowIndex < rows.count else { return }
        clearCellSelection()
        let previousSelectedRowID = selectedRowID
        selectedRowID = rowID
        selectedRowIDs = [rowID]
        selectedMarkerID = markerID
        if let tableView, tableView.selectedRow != rowIndex {
            tableView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
        }
        _ = reloadCustomPresentationRows(
            previousSelectedRowID: previousSelectedRowID,
            selectedRowID: rowID
        )
        onMarkerSelectionChange?(rowID, markerID)
        if activate {
            onDoubleClick?(rowID)
        }
    }

    @MainActor
    @discardableResult
    func selectAdjacentMarker(direction: NativeTableView.MarkerNavigationDirection) -> Bool {
        guard let rowIndex = resolvedSelectedRowIndexes().first, rowIndex >= 0, rowIndex < rows.count else {
            return false
        }
        return selectAdjacentMarker(rowID: rows[rowIndex].id, direction: direction)
    }

    @MainActor
    @discardableResult
    func selectAdjacentMarker(
        rowID: String,
        direction: NativeTableView.MarkerNavigationDirection
    ) -> Bool {
        guard let rowIndex = rowIndexByID[rowID], rowIndex >= 0, rowIndex < rows.count else {
            return false
        }
        let markers = markerValues(in: rows[rowIndex])
        guard !markers.isEmpty else { return false }

        let selectedIndex = selectedMarkerID.flatMap { markerID in
            markers.firstIndex(where: { $0.id == markerID })
        }
        let nextIndex: Int
        switch direction {
        case .previous:
            nextIndex = max((selectedIndex ?? markers.count) - 1, 0)
        case .next:
            nextIndex = min((selectedIndex ?? -1) + 1, markers.count - 1)
        }

        let markerID = markers[nextIndex].id
        guard selectedMarkerID != markerID || selectedRowID != rowID else { return false }
        selectMarker(rowID: rowID, markerID: markerID, activate: false)
        return true
    }

    @MainActor
    @discardableResult
    func activateMarker(rowID: String) -> Bool {
        guard let rowIndex = rowIndexByID[rowID], rowIndex >= 0, rowIndex < rows.count else {
            return false
        }
        clearCellSelection()
        if selectedRowID != rowID {
            selectedRowID = rowID
            selectedRowIDs = [rowID]
            onSelectionChange?(rowID)
        }
        onDoubleClick?(rowID)
        return true
    }

    private func markerValues(in row: NativeTableRowDescriptor) -> [NativeTableMarkerValue] {
        for column in orderedVisibleColumns() {
            guard case .custom(.markerStrip) = column.presentation else { continue }
            if case .custom(_, .markerStrip(let markers))? = row.cell(for: column.id) {
                return markers
            }
        }
        return []
    }

    @MainActor
    func selectedRowsCopyPayload() -> String? {
        let indexes = resolvedSelectedRowIndexes()
        return rowsCopyPayload(indexes: indexes)
    }

    @MainActor
    func selectedCellsCopyPayload() -> String? {
        guard !selectedCellKeys.isEmpty else { return nil }
        let selectedColumnIDs = Set(selectedCellKeys.map(\.columnID))
        let visibleColumns = orderedVisibleColumns().filter { selectedColumnIDs.contains($0.id) }
        guard !visibleColumns.isEmpty else { return nil }

        var selectedRows: [NativeTableRowDescriptor] = []
        for row in rows where selectedCellKeys.contains(where: { $0.rowID == row.id }) {
            var cells: [String: NativeTableCellValue] = [:]
            for column in visibleColumns {
                let key = CellSelectionKey(rowID: row.id, columnID: column.id)
                cells[column.id] = selectedCellKeys.contains(key)
                    ? (row.cell(for: column.id) ?? .text(""))
                    : .text("")
            }
            selectedRows.append(NativeTableRowDescriptor(id: row.id, cells: cells))
        }

        return copyPayload(columns: visibleColumns, rows: selectedRows)
    }

    @MainActor
    func visibleRowsCopyPayload() -> String? {
        rowsCopyPayload(indexes: Array(rows.indices))
    }

    private func rowsCopyPayload(indexes: [Int]) -> String? {
        guard !indexes.isEmpty else { return nil }
        let visibleColumns = orderedVisibleColumns()
        guard !visibleColumns.isEmpty else { return nil }
        let selectedRows = indexes.compactMap { index -> NativeTableRowDescriptor? in
            guard index >= 0, index < rows.count else { return nil }
            return rows[index]
        }
        return copyPayload(columns: visibleColumns, rows: selectedRows)
    }

    private func copyPayload(
        columns: [NativeTableColumnDescriptor],
        rows selectedRows: [NativeTableRowDescriptor]
    ) -> String? {
        guard !columns.isEmpty else { return nil }
        let orderedTable = NativeTableDescriptor(
            storageKey: descriptor.storageKey,
            columns: columns,
            defaultDensity: descriptor.defaultDensity
        )
        guard !selectedRows.isEmpty else { return nil }
        return TableExportService().makeTSV(
            snapshot: NativeTableExportSnapshot(
                suggestedBaseName: "table-copy",
                table: orderedTable,
                rows: selectedRows
            )
        )
    }

    @MainActor
    func resolvedSelectedRowIndexes() -> [Int] {
        let indexes = selectedRowIndexes()
        if !indexes.isEmpty {
            return indexes
        }

        if !selectedRowIDs.isEmpty {
            let fallbackIndexes = selectedRowIDs.compactMap { rowIndexByID[$0] }.sorted()
            if !fallbackIndexes.isEmpty {
                return fallbackIndexes
            }
        }

        if let selectedRowID {
            return rowIndexByID[selectedRowID].map { [$0] } ?? []
        }

        return []
    }

    @MainActor
    private func ensureSingleRowSelection(rowIndex: Int) {
        guard rowIndex >= 0, rowIndex < rows.count else { return }
        let rowID = rows[rowIndex].id
        let previousSelectedRowID = selectedRowID
        selectedRowID = rowID
        selectedRowIDs = [rowID]

        guard let tableView else {
            if previousSelectedRowID != rowID {
                onSelectionChange?(rowID)
            }
            return
        }

        isApplyingCellSelection = true
        tableView.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
        isApplyingCellSelection = false

        if previousSelectedRowID != rowID {
            onSelectionChange?(rowID)
        }
    }

    @MainActor
    func reloadCellSelectionAppearance(
        previousCellKeys: Set<CellSelectionKey>,
        selectedCellKeys: Set<CellSelectionKey>
    ) {
        guard let tableView else { return }
        let affectedCellKeys = previousCellKeys.union(selectedCellKeys)
        guard !affectedCellKeys.isEmpty else { return }

        var rowIndexes = IndexSet()
        for rowID in Set(affectedCellKeys.map(\.rowID)) {
            guard let index = rowIndexByID[rowID], index >= 0, index < rows.count else { continue }
            rowIndexes.insert(index)
        }

        let affectedColumnIDs = Set(affectedCellKeys.map(\.columnID))
        let columnIndexes = IndexSet(
            tableView.tableColumns.enumerated().compactMap { index, column in
                affectedColumnIDs.contains(column.identifier.rawValue) ? index : nil
            }
        )
        guard !rowIndexes.isEmpty, !columnIndexes.isEmpty else { return }

        tableView.reloadData(forRowIndexes: rowIndexes, columnIndexes: columnIndexes)
    }
}
