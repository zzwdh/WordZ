import AppKit

extension NativeTableView.Coordinator {
    @MainActor
    func apply(
        descriptor: NativeTableDescriptor,
        rows: [NativeTableRowDescriptor],
        snapshot: ResultTableSnapshot? = nil,
        selectedRowID: String?,
        onSelectionChange: ((String?) -> Void)?,
        onDoubleClick: ((String) -> Void)?,
        onSortByColumn: ((String) -> Void)? = nil,
        onToggleColumnFromHeader: ((String) -> Void)? = nil,
        selectedMarkerID: String? = nil,
        onMarkerSelectionChange: ((String, String?) -> Void)? = nil,
        allowsMultipleSelection: Bool = true,
        isHeaderPinned: Bool = true,
        emptyMessage: String = "当前没有可显示的数据。",
        accessibilityLabel: String? = nil,
        activationHint: String? = nil
    ) {
        let startedAt = Date()
        let previousDescriptor = self.descriptor
        let previousRows = self.rows
        let previousSnapshotVersion = self.snapshotVersion
        let previousSelectedRowID = self.selectedRowID
        let previousSelectedMarkerID = self.selectedMarkerID
        let previousSelectedRowIDs = self.selectedRowIDs
        let previousSelectedCellKeys = self.selectedCellKeys
        let previousDensity = resolvedDensity(for: previousDescriptor)
        let previousHeaderPinning = self.isHeaderPinned
        let columnsChanged = previousDescriptor != descriptor
        let resolvedRows = snapshot?.rows ?? rows
        let rowsChanged: Bool
        if let snapshot {
            rowsChanged = previousSnapshotVersion != snapshot.version
        } else {
            rowsChanged = !previousRows.isContentEqual(to: resolvedRows)
        }
        let resolvedRowIndexByID: [String: Int]
        if let snapshot {
            resolvedRowIndexByID = snapshot.rowIndexByID
        } else if rowsChanged {
            resolvedRowIndexByID = NativeTableRowIndexing.firstIndexByID(resolvedRows)
        } else {
            resolvedRowIndexByID = rowIndexByID
        }
        let resolvedSelectedRowID = selectedRowID.flatMap { resolvedRowIndexByID[$0] == nil ? nil : $0 }
        let shouldNotifyUnavailableSelection = selectedRowID != nil && resolvedSelectedRowID == nil

        self.descriptor = descriptor
        self.rows = resolvedRows
        self.snapshotVersion = snapshot?.version
        self.rowIndexByID = resolvedRowIndexByID
        self.selectedRowID = resolvedSelectedRowID
        self.onSelectionChange = onSelectionChange
        self.onDoubleClick = onDoubleClick
        self.onSortByColumn = onSortByColumn
        self.onToggleColumnFromHeader = onToggleColumnFromHeader
        self.selectedMarkerID = selectedMarkerID
        self.onMarkerSelectionChange = onMarkerSelectionChange
        self.allowsMultipleSelection = allowsMultipleSelection
        self.isHeaderPinned = isHeaderPinned
        self.emptyMessage = emptyMessage
        self.accessibilityLabel = accessibilityLabel
        self.activationHint = activationHint

        tableView?.allowsMultipleSelection = allowsMultipleSelection

        let nextDensity = resolvedDensity()
        let headerPinningChanged = previousHeaderPinning != isHeaderPinned
        updateTableMetrics(nextDensity)

        selectedRowIDs = previousSelectedRowIDs.isEmpty
            ? []
            : Set(previousSelectedRowIDs.lazy.filter { resolvedRowIndexByID[$0] != nil })
        if let resolvedSelectedRowID {
            selectedRowIDs.insert(resolvedSelectedRowID)
        }
        let visibleColumnIDs = Set(descriptor.visibleColumns.map(\.id))
        selectedCellKeys = selectedCellKeys.filter { key in
            resolvedRowIndexByID[key.rowID] != nil && visibleColumnIDs.contains(key.columnID)
        }
        if let resolvedSelectedRowID {
            selectedCellKeys = selectedCellKeys.filter { $0.rowID == resolvedSelectedRowID }
        } else {
            selectedCellKeys.removeAll()
        }

        let selectionChanged = previousSelectedRowID != resolvedSelectedRowID
            || previousSelectedMarkerID != selectedMarkerID
            || previousSelectedRowIDs != selectedRowIDs
        let cellSelectionChanged = previousSelectedCellKeys != selectedCellKeys
        let emptinessChanged = previousRows.isEmpty != resolvedRows.isEmpty
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
        if selectionChanged || cellSelectionChanged || emptinessChanged || tableView?.menu == nil {
            rebuildRowMenu()
        }

        var reloadOutcome = ReloadOutcome.none
        if columnsChanged {
            tableView?.reloadData()
            reloadOutcome = ReloadOutcome(
                mode: .fullColumnsChanged,
                reloadedRowCount: resolvedRows.count
            )
        } else if rowsChanged {
            reloadOutcome = reloadVisibleRows(previousRowCount: previousRows.count)
        } else if selectionChanged {
            reloadOutcome = reloadSelectionAppearanceRows(
                previousSelectedRowID: previousSelectedRowID,
                previousSelectedRowIDs: previousSelectedRowIDs,
                selectedRowID: resolvedSelectedRowID,
                selectedRowIDs: selectedRowIDs
            )
        } else if cellSelectionChanged {
            reloadCellSelectionAppearance(
                previousCellKeys: previousSelectedCellKeys,
                selectedCellKeys: selectedCellKeys
            )
        }

        tableView?.setAccessibilityLabel(accessibilityLabel ?? wordZText("结果表格", "Results table", mode: .system))
        tableView?.setAccessibilityHelp(activationHint)
        syncSelection()
        syncEmptyState()
        if shouldNotifyUnavailableSelection {
            onSelectionChange?(nil)
        }

        AnalysisPerformanceTelemetry.logTableApply(
            storageKey: descriptor.storageKey,
            rowCount: resolvedRows.count,
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
