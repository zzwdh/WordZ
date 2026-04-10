import AppKit

extension NativeTableView.Coordinator {
    @MainActor
    func apply(
        descriptor: NativeTableDescriptor,
        rows: [NativeTableRowDescriptor],
        selectedRowID: String?,
        onSelectionChange: ((String?) -> Void)?,
        onDoubleClick: ((String) -> Void)?,
        onSortByColumn: ((String) -> Void)? = nil,
        onToggleColumnFromHeader: ((String) -> Void)? = nil,
        allowsMultipleSelection: Bool = true,
        isHeaderPinned: Bool = true,
        emptyMessage: String = "当前没有可显示的数据。",
        accessibilityLabel: String? = nil,
        activationHint: String? = nil
    ) {
        let startedAt = Date()
        let previousDescriptor = self.descriptor
        let previousRows = self.rows
        let previousSelectedRowID = self.selectedRowID
        let previousSelectedRowIDs = self.selectedRowIDs
        let previousDensity = resolvedDensity(for: previousDescriptor)
        let previousHeaderPinning = self.isHeaderPinned
        let columnsChanged = previousDescriptor != descriptor
        let rowsChanged = !previousRows.isContentEqual(to: rows)

        self.descriptor = descriptor
        self.rows = rows
        self.selectedRowID = selectedRowID
        self.onSelectionChange = onSelectionChange
        self.onDoubleClick = onDoubleClick
        self.onSortByColumn = onSortByColumn
        self.onToggleColumnFromHeader = onToggleColumnFromHeader
        self.allowsMultipleSelection = allowsMultipleSelection
        self.isHeaderPinned = isHeaderPinned
        self.emptyMessage = emptyMessage
        self.accessibilityLabel = accessibilityLabel
        self.activationHint = activationHint

        tableView?.allowsMultipleSelection = allowsMultipleSelection

        let nextDensity = resolvedDensity()
        let headerPinningChanged = previousHeaderPinning != isHeaderPinned
        updateTableMetrics(nextDensity)

        let availableIDs = Set(rows.map(\.id))
        selectedRowIDs = previousSelectedRowIDs.intersection(availableIDs)
        if let selectedRowID, availableIDs.contains(selectedRowID) {
            selectedRowIDs.insert(selectedRowID)
        }

        let selectionChanged = previousSelectedRowID != selectedRowID || previousSelectedRowIDs != selectedRowIDs
        let emptinessChanged = previousRows.isEmpty != rows.isEmpty
        let densityChanged = previousDensity != nextDensity

        if columnsChanged || densityChanged || !hasBuiltColumns {
            rebuildColumns()
        }
        if columnsChanged || densityChanged || headerPinningChanged {
            updateHeaderPinning()
        }
        if columnsChanged || densityChanged || tableView?.headerView?.menu == nil {
            rebuildHeaderMenu()
        }
        if selectionChanged || emptinessChanged || tableView?.menu == nil {
            rebuildRowMenu()
        }

        var reloadOutcome = ReloadOutcome.none
        if columnsChanged {
            tableView?.reloadData()
            reloadOutcome = ReloadOutcome(
                mode: .fullColumnsChanged,
                reloadedRowCount: rows.count
            )
        } else if rowsChanged {
            reloadOutcome = reloadVisibleRows(previousRowCount: previousRows.count)
        }

        tableView?.setAccessibilityLabel(accessibilityLabel ?? wordZText("结果表格", "Results table", mode: .system))
        tableView?.setAccessibilityHelp(activationHint)
        syncSelection()
        syncEmptyState()

        AnalysisPerformanceTelemetry.logTableApply(
            storageKey: descriptor.storageKey,
            rowCount: rows.count,
            columnCount: descriptor.columns.count,
            columnsChanged: columnsChanged,
            rowsChanged: rowsChanged,
            selectionChanged: selectionChanged,
            emptinessChanged: emptinessChanged,
            densityChanged: densityChanged,
            headerPinningChanged: headerPinningChanged,
            reloadMode: reloadOutcome.mode,
            reloadedRowCount: reloadOutcome.reloadedRowCount,
            durationMs: WordZTelemetry.elapsedMilliseconds(since: startedAt)
        )
    }
}
