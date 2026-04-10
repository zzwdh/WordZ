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
            let indexes = IndexSet(rows.enumerated().compactMap { selectedRowIDs.contains($0.element.id) ? $0.offset : nil })
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

        guard let rowIndex = rows.firstIndex(where: { $0.id == selectedRowID }) else {
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
            let fallbackIndexes = rows.enumerated().compactMap { offset, row in
                selectedRowIDs.contains(row.id) ? offset : nil
            }
            if !fallbackIndexes.isEmpty {
                return fallbackIndexes
            }
        }

        if let selectedRowID {
            return rows.enumerated().compactMap { offset, row in
                row.id == selectedRowID ? offset : nil
            }
        }

        return []
    }
}
