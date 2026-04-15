import AppKit
import SwiftUI

struct PlotDistributionTableView: NSViewRepresentable {
    let rows: [PlotSceneRow]
    var selectedRowID: String? = nil
    var selectedMarkerID: String? = nil
    var onSelectionChange: ((String?) -> Void)? = nil
    var onMarkerSelectionChange: ((String, String?) -> Void)? = nil
    var onActivateRow: ((String) -> Void)? = nil
    var emptyMessage: String = "当前没有可显示的数据。"
    var accessibilityLabel: String? = nil

    func makeCoordinator() -> Coordinator {
        Coordinator(
            rows: rows,
            selectedRowID: selectedRowID,
            selectedMarkerID: selectedMarkerID,
            onSelectionChange: onSelectionChange,
            onMarkerSelectionChange: onMarkerSelectionChange,
            onActivateRow: onActivateRow,
            emptyMessage: emptyMessage,
            accessibilityLabel: accessibilityLabel
        )
    }

    func makeNSView(context: Context) -> NativeTableView.IntrinsicTableContainerView {
        let containerView = NativeTableView.IntrinsicTableContainerView(frame: .zero)
        let tableView = PlotTableView(frame: .zero)
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnReordering = false
        tableView.allowsColumnResizing = true
        tableView.allowsTypeSelect = true
        tableView.allowsMultipleSelection = false
        tableView.headerView = NSTableHeaderView()
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.target = context.coordinator
        tableView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))
        tableView.rowSizeStyle = .small
        tableView.rowHeight = 24
        tableView.intercellSpacing = NSSize(width: 4, height: 2)
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.actionCoordinator = context.coordinator
        tableView.selectionHighlightStyle = .regular

        buildColumns(for: tableView)
        containerView.scrollView.documentView = tableView
        context.coordinator.attach(tableView: tableView, containerView: containerView)
        context.coordinator.apply(
            rows: rows,
            selectedRowID: selectedRowID,
            selectedMarkerID: selectedMarkerID,
            onSelectionChange: onSelectionChange,
            onMarkerSelectionChange: onMarkerSelectionChange,
            onActivateRow: onActivateRow,
            emptyMessage: emptyMessage,
            accessibilityLabel: accessibilityLabel
        )
        return containerView
    }

    func updateNSView(_ containerView: NativeTableView.IntrinsicTableContainerView, context: Context) {
        context.coordinator.apply(
            rows: rows,
            selectedRowID: selectedRowID,
            selectedMarkerID: selectedMarkerID,
            onSelectionChange: onSelectionChange,
            onMarkerSelectionChange: onMarkerSelectionChange,
            onActivateRow: onActivateRow,
            emptyMessage: emptyMessage,
            accessibilityLabel: accessibilityLabel
        )
    }

    private func buildColumns(for tableView: NSTableView) {
        let columns: [(id: PlotColumnKey, width: CGFloat, minWidth: CGFloat)] = [
            (.row, 48, 40),
            (.fileID, 64, 56),
            (.filePath, 300, 180),
            (.fileTokens, 88, 80),
            (.frequency, 72, 64),
            (.normalizedFrequency, 92, 84),
            (.plot, 340, 220)
        ]

        for column in columns {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.id.rawValue))
            tableColumn.title = column.id.title(in: WordZLocalization.shared.effectiveMode)
            tableColumn.width = column.width
            tableColumn.minWidth = column.minWidth
            tableColumn.resizingMask = .autoresizingMask
            tableView.addTableColumn(tableColumn)
        }
    }
}

extension PlotDistributionTableView {
    final class PlotTableView: NSTableView {
        weak var actionCoordinator: Coordinator?

        override func keyDown(with event: NSEvent) {
            if [36, 49, 76].contains(event.keyCode),
               actionCoordinator?.activateSelectedRow() == true {
                return
            }
            super.keyDown(with: event)
        }
    }

    final class PlotMarkerCellView: NSView {
        var markers: [PlotSceneMarker] = []
        var selectedMarkerID: String?
        var isSelectedRow = false
        var onSelectMarker: ((String?, Bool) -> Void)?

        override var isFlipped: Bool { true }

        override func draw(_ dirtyRect: NSRect) {
            super.draw(dirtyRect)

            let borderRect = bounds.insetBy(dx: 4, dy: 4)
            NSColor.separatorColor.withAlphaComponent(isSelectedRow ? 0.5 : 0.25).setStroke()
            let borderPath = NSBezierPath(roundedRect: borderRect, xRadius: 4, yRadius: 4)
            borderPath.lineWidth = 1
            borderPath.stroke()

            guard !markers.isEmpty else { return }

            let usableWidth = max(borderRect.width - 2, 1)
            let minY = borderRect.minY + 2
            let maxY = borderRect.maxY - 2
            let baseColor = NSColor.controlAccentColor.withAlphaComponent(isSelectedRow ? 0.9 : 0.7)
            let selectedColor = NSColor.controlAccentColor

            for marker in markers {
                let x = borderRect.minX + CGFloat(marker.normalizedPosition) * usableWidth
                let path = NSBezierPath()
                path.move(to: NSPoint(x: x, y: minY))
                path.line(to: NSPoint(x: x, y: maxY))
                path.lineWidth = marker.id == selectedMarkerID ? 2 : 1
                (marker.id == selectedMarkerID ? selectedColor : baseColor).setStroke()
                path.stroke()
            }
        }

        override func mouseDown(with event: NSEvent) {
            let shouldActivate = event.clickCount > 1
            guard !markers.isEmpty else {
                onSelectMarker?(nil, shouldActivate)
                return
            }
            let localPoint = convert(event.locationInWindow, from: nil)
            let markerID = nearestMarker(to: localPoint.x)?.id
            onSelectMarker?(markerID, shouldActivate)
        }

        private func nearestMarker(to x: CGFloat) -> PlotSceneMarker? {
            let borderRect = bounds.insetBy(dx: 4, dy: 4)
            let usableWidth = max(borderRect.width - 2, 1)
            return markers.min { lhs, rhs in
                let lhsX = borderRect.minX + CGFloat(lhs.normalizedPosition) * usableWidth
                let rhsX = borderRect.minX + CGFloat(rhs.normalizedPosition) * usableWidth
                return abs(lhsX - x) < abs(rhsX - x)
            }
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        var rows: [PlotSceneRow]
        var selectedRowID: String?
        var selectedMarkerID: String?
        var onSelectionChange: ((String?) -> Void)?
        var onMarkerSelectionChange: ((String, String?) -> Void)?
        var onActivateRow: ((String) -> Void)?
        var emptyMessage: String
        var accessibilityLabel: String?
        weak var tableView: NSTableView?
        weak var containerView: NativeTableView.IntrinsicTableContainerView?
        var isApplyingSelection = false

        init(
            rows: [PlotSceneRow],
            selectedRowID: String?,
            selectedMarkerID: String?,
            onSelectionChange: ((String?) -> Void)?,
            onMarkerSelectionChange: ((String, String?) -> Void)?,
            onActivateRow: ((String) -> Void)?,
            emptyMessage: String,
            accessibilityLabel: String?
        ) {
            self.rows = rows
            self.selectedRowID = selectedRowID
            self.selectedMarkerID = selectedMarkerID
            self.onSelectionChange = onSelectionChange
            self.onMarkerSelectionChange = onMarkerSelectionChange
            self.onActivateRow = onActivateRow
            self.emptyMessage = emptyMessage
            self.accessibilityLabel = accessibilityLabel
        }

        func attach(tableView: NSTableView, containerView: NativeTableView.IntrinsicTableContainerView) {
            self.tableView = tableView
            self.containerView = containerView
        }

        func apply(
            rows: [PlotSceneRow],
            selectedRowID: String?,
            selectedMarkerID: String?,
            onSelectionChange: ((String?) -> Void)?,
            onMarkerSelectionChange: ((String, String?) -> Void)?,
            onActivateRow: ((String) -> Void)?,
            emptyMessage: String,
            accessibilityLabel: String?
        ) {
            self.rows = rows
            self.selectedRowID = selectedRowID
            self.selectedMarkerID = selectedMarkerID
            self.onSelectionChange = onSelectionChange
            self.onMarkerSelectionChange = onMarkerSelectionChange
            self.onActivateRow = onActivateRow
            self.emptyMessage = emptyMessage
            self.accessibilityLabel = accessibilityLabel
            tableView?.reloadData()
            syncSelection()
            containerView?.updateEmptyState(message: emptyMessage, isEmpty: rows.isEmpty)
            if let accessibilityLabel {
                tableView?.setAccessibilityLabel(accessibilityLabel)
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row >= 0, row < rows.count, let tableColumn else { return nil }
            let sceneRow = rows[row]
            guard let column = PlotColumnKey(rawValue: tableColumn.identifier.rawValue) else { return nil }

            switch column {
            case .plot:
                let identifier = NSUserInterfaceItemIdentifier("plot-marker-cell")
                let cellView: PlotMarkerCellView
                if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? PlotMarkerCellView {
                    cellView = reused
                } else {
                    cellView = PlotMarkerCellView(frame: .zero)
                    cellView.identifier = identifier
                }
                cellView.markers = sceneRow.markers
                cellView.selectedMarkerID = sceneRow.id == selectedRowID ? selectedMarkerID : nil
                cellView.isSelectedRow = sceneRow.id == selectedRowID
                cellView.toolTip = sceneRow.markers.isEmpty ? "No hits" : "\(sceneRow.markers.count) hits"
                cellView.onSelectMarker = { [weak self] markerID, shouldActivate in
                    self?.selectMarker(rowID: sceneRow.id, markerID: markerID, activate: shouldActivate)
                }
                cellView.needsDisplay = true
                return cellView
            case .row, .fileID, .fileTokens, .frequency, .normalizedFrequency, .filePath:
                let identifier = NSUserInterfaceItemIdentifier(column.rawValue)
                let textField: NSTextField
                if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField {
                    textField = reused
                } else {
                    textField = NSTextField(labelWithString: "")
                    textField.identifier = identifier
                    textField.lineBreakMode = .byTruncatingMiddle
                    textField.maximumNumberOfLines = 1
                    textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                }
                configure(textField, for: column)
                textField.stringValue = value(for: sceneRow, column: column)
                textField.toolTip = column == .filePath ? sceneRow.displayPath : nil
                return textField
            }
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard !isApplyingSelection, let tableView else { return }
            let nextSelection: String?
            if tableView.selectedRow >= 0, tableView.selectedRow < rows.count {
                nextSelection = rows[tableView.selectedRow].id
            } else {
                nextSelection = nil
            }
            selectedRowID = nextSelection
            onSelectionChange?(nextSelection)
        }

        @objc
        func handleDoubleClick(_ sender: Any?) {
            _ = activateSelectedRow()
        }

        func activateSelectedRow() -> Bool {
            guard let tableView,
                  tableView.selectedRow >= 0,
                  tableView.selectedRow < rows.count else {
                return false
            }
            onActivateRow?(rows[tableView.selectedRow].id)
            return true
        }

        private func selectMarker(rowID: String, markerID: String?, activate: Bool) {
            guard let rowIndex = rows.firstIndex(where: { $0.id == rowID }) else { return }
            isApplyingSelection = true
            tableView?.selectRowIndexes(IndexSet(integer: rowIndex), byExtendingSelection: false)
            isApplyingSelection = false
            selectedRowID = rowID
            selectedMarkerID = markerID
            onMarkerSelectionChange?(rowID, markerID)
            if activate {
                onActivateRow?(rowID)
            }
        }

        private func syncSelection() {
            guard let tableView else { return }
            let targetRowIndex = selectedRowID.flatMap { selectedRowID in
                rows.firstIndex(where: { $0.id == selectedRowID })
            }
            isApplyingSelection = true
            defer { isApplyingSelection = false }
            if let targetRowIndex {
                tableView.selectRowIndexes(IndexSet(integer: targetRowIndex), byExtendingSelection: false)
            } else {
                tableView.deselectAll(nil)
            }
        }

        private func value(for row: PlotSceneRow, column: PlotColumnKey) -> String {
            switch column {
            case .row:
                return "\(row.rowNumber)"
            case .fileID:
                return "\(row.fileID)"
            case .filePath:
                return row.displayPath
            case .fileTokens:
                return "\(row.fileTokens)"
            case .frequency:
                return "\(row.frequency)"
            case .normalizedFrequency:
                return row.normalizedFrequencyText
            case .plot:
                return row.plotText
            }
        }

        private func configure(_ textField: NSTextField, for column: PlotColumnKey) {
            textField.font = .systemFont(ofSize: 11)
            textField.textColor = .labelColor
            textField.backgroundColor = .clear
            textField.drawsBackground = false
            switch column {
            case .row, .fileID, .fileTokens, .frequency, .normalizedFrequency:
                textField.alignment = .right
            case .filePath, .plot:
                textField.alignment = .left
            }
        }
    }
}
