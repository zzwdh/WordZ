import AppKit
import WordZExport

@MainActor
extension NativeTableView.Coordinator {
    package func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }

    package func tableViewColumnDidResize(_ notification: Notification) {
        guard
            let tableView,
            let resizedColumn = notification.userInfo?["NSTableColumn"] as? NSTableColumn,
            tableView.tableColumns.contains(where: { $0 === resizedColumn }),
            let descriptorColumn = descriptor.column(id: resizedColumn.identifier.rawValue)
        else {
            return
        }
        persistWidth(resizedColumn.width, for: descriptorColumn)
    }

    package func tableViewColumnDidMove(_ notification: Notification) {
        guard let tableView else { return }
        persistColumnOrder(from: tableView.tableColumns.map(\.identifier.rawValue))
        let expectedOrder = orderedVisibleColumns().map(\.id)
        let currentOrder = tableView.tableColumns.map(\.identifier.rawValue)
        if currentOrder != expectedOrder {
            rebuildColumns()
            tableView.reloadData()
        }
    }

    package func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
        onSortByColumn?(tableColumn.identifier.rawValue)
    }

    package func tableViewSelectionDidChange(_ notification: Notification) {
        guard let tableView else { return }
        let previousSelectedRowID = selectedRowID
        let previousSelectedRowIDs = selectedRowIDs
        let previousSelectedCellKeys = selectedCellKeys
        let nextSelection: String?
        if tableView.selectedRow >= 0, tableView.selectedRow < rows.count {
            nextSelection = rows[tableView.selectedRow].id
        } else {
            nextSelection = nil
        }
        selectedRowIDs = Set(tableView.selectedRowIndexes.compactMap { index in
            guard index >= 0, index < rows.count else { return nil }
            return rows[index].id
        })
        let selectionAppearanceChanged = previousSelectedRowID != nextSelection
            || previousSelectedRowIDs != selectedRowIDs
        selectedRowID = nextSelection
        if !isApplyingCellSelection {
            selectedCellKeys.removeAll()
        }
        if selectionAppearanceChanged {
            _ = reloadSelectionAppearanceRows(
                previousSelectedRowID: previousSelectedRowID,
                previousSelectedRowIDs: previousSelectedRowIDs,
                selectedRowID: nextSelection,
                selectedRowIDs: selectedRowIDs
            )
        }
        if previousSelectedCellKeys != selectedCellKeys {
            reloadCellSelectionAppearance(
                previousCellKeys: previousSelectedCellKeys,
                selectedCellKeys: selectedCellKeys
            )
            rebuildRowMenu()
        }
        if previousSelectedRowID != nextSelection {
            onSelectionChange?(nextSelection)
            rebuildRowMenu()
        }
    }
}
