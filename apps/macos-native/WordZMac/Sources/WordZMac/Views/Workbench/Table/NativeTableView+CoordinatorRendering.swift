import AppKit

extension NativeTableView.Coordinator {
    @MainActor
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row >= 0, row < rows.count, let tableColumn else { return nil }
        let identifier = tableColumn.identifier
        let columnID = identifier.rawValue
        guard let column = descriptor.column(id: columnID) else { return nil }
        if case .custom(.markerStrip) = column.presentation {
            return markerStripView(
                tableView: tableView,
                identifier: identifier,
                row: rows[row],
                columnID: columnID
            )
        }

        let textField: NSTextField
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField {
            textField = reused
        } else {
            textField = NSTextField(labelWithString: "")
            textField.identifier = identifier
            textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        }
        configure(textField, for: column)

        let rawValue = rows[row].value(for: columnID)
        textField.stringValue = displayValue(rawValue, for: column)
        textField.toolTip = rawValue.count > 24 ? rawValue : nil
        return textField
    }

    @MainActor
    private func markerStripView(
        tableView: NSTableView,
        identifier: NSUserInterfaceItemIdentifier,
        row: NativeTableRowDescriptor,
        columnID: String
    ) -> NSView {
        let cellIdentifier = NSUserInterfaceItemIdentifier("\(identifier.rawValue)-marker-strip")
        let cellView: NativeTableView.MarkerStripCellView
        if let reused = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NativeTableView.MarkerStripCellView {
            cellView = reused
        } else {
            cellView = NativeTableView.MarkerStripCellView(frame: .zero)
            cellView.identifier = cellIdentifier
        }

        let markers: [NativeTableMarkerValue]
        if case .custom(_, .markerStrip(let values))? = row.cell(for: columnID) {
            markers = values
        } else {
            markers = []
        }

        let isSelected = row.id == selectedRowID || selectedRowIDs.contains(row.id)
        cellView.markers = markers
        cellView.selectedMarkerID = isSelected ? selectedMarkerID : nil
        cellView.isSelectedRow = isSelected
        cellView.toolTip = markerStripToolTip(for: markers)
        cellView.setAccessibilityLabel(markerStripAccessibilityLabel(for: markers))
        cellView.onSelectMarker = { [weak self] markerID, shouldActivate in
            self?.selectMarker(rowID: row.id, markerID: markerID, activate: shouldActivate)
        }
        cellView.onNavigateMarker = { [weak self] direction in
            self?.selectAdjacentMarker(rowID: row.id, direction: direction) ?? false
        }
        cellView.onActivateMarker = { [weak self] in
            self?.activateMarker(rowID: row.id) ?? false
        }
        cellView.needsDisplay = true
        return cellView
    }

    private func markerStripToolTip(for markers: [NativeTableMarkerValue]) -> String {
        if markers.isEmpty {
            return wordZText("无命中", "No hits", mode: .system)
        }
        return wordZText("\(markers.count) 个命中", "\(markers.count) hits", mode: .system)
    }

    private func markerStripAccessibilityLabel(for markers: [NativeTableMarkerValue]) -> String {
        if markers.isEmpty {
            return wordZText("Plot 命中分布：无命中", "Plot hit distribution: no hits", mode: .system)
        }
        return wordZText(
            "Plot 命中分布：\(markers.count) 个命中",
            "Plot hit distribution: \(markers.count) hits",
            mode: .system
        )
    }

    @MainActor
    func configure(_ textField: NSTextField, for columnID: String) {
        guard let column = descriptor.column(id: columnID) else { return }
        configure(textField, for: column)
    }

    @MainActor
    func configure(_ textField: NSTextField, for column: NativeTableColumnDescriptor) {
        let metrics = NativeTableView.metrics(for: resolvedDensity())
        textField.maximumNumberOfLines = 1
        textField.alignment = alignment(for: column)
        textField.font = font(for: column, metrics: metrics)
        textField.textColor = textColor(for: column)
        textField.lineBreakMode = lineBreakMode(for: column)
        textField.backgroundColor = .clear
        textField.drawsBackground = false
    }
}
