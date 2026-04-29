import AppKit

extension NativeTableView.Coordinator {
    @MainActor
    func syncSelection() {
        guard let tableView else { return }
        guard !rows.isEmpty else {
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
    func selectedRowIndexes() -> [Int] {
        guard let tableView else { return [] }
        return tableView.selectedRowIndexes.compactMap { index in
            guard index >= 0, index < rows.count else { return nil }
            return index
        }
    }

    @MainActor
    @discardableResult
    func copySelectedRowsToPasteboard(_ pasteboard: NSPasteboard = .general) -> Bool {
        guard let payload = selectedRowsCopyPayload() else { return false }
        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)
        return pasteboard.setString(payload, forType: .string)
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
        guard !indexes.isEmpty else { return nil }
        let visibleColumns = orderedVisibleColumns()
        guard !visibleColumns.isEmpty else { return nil }
        let lines = [
            visibleColumns.map(\.title).joined(separator: "\t")
        ] + indexes.map { index in
            visibleColumns.map { rows[index].value(for: $0.id) }.joined(separator: "\t")
        }
        return lines.joined(separator: "\n")
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
}
