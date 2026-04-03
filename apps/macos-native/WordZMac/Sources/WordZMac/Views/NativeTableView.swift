import AppKit
import SwiftUI

struct NativeTableView: NSViewRepresentable {
    let descriptor: NativeTableDescriptor
    let rows: [NativeTableRowDescriptor]
    var selectedRowID: String? = nil
    var onSelectionChange: ((String?) -> Void)? = nil
    var onDoubleClick: ((String) -> Void)? = nil
    var onSortByColumn: ((String) -> Void)? = nil
    var onToggleColumnFromHeader: ((String) -> Void)? = nil
    var allowsMultipleSelection = true
    var emptyMessage: String = "当前没有可显示的数据。"
    var accessibilityLabel: String? = nil
    var activationHint: String? = nil

    private enum LayoutMetrics {
        static let storageVersion = "v3"
        static let minimumWidth: CGFloat = 56
        static let maximumCompactWidth: CGFloat = 280
        static let maximumContextWidth: CGFloat = 640
        static let maximumSummaryWidth: CGFloat = 420
    }

    private struct DensityMetrics {
        let rowHeight: CGFloat
        let intercellWidth: CGFloat
        let intercellHeight: CGFloat
        let fontSize: CGFloat
        let headerFontSize: CGFloat
    }

    private static func metrics(for density: NativeTableDensityPreset) -> DensityMetrics {
        switch density {
        case .compact:
            return DensityMetrics(
                rowHeight: 22,
                intercellWidth: 4,
                intercellHeight: 2,
                fontSize: 11,
                headerFontSize: 11
            )
        case .standard:
            return DensityMetrics(
                rowHeight: 26,
                intercellWidth: 5,
                intercellHeight: 3,
                fontSize: 12,
                headerFontSize: 11
            )
        case .reading:
            return DensityMetrics(
                rowHeight: 30,
                intercellWidth: 6,
                intercellHeight: 4,
                fontSize: 13,
                headerFontSize: 12
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: selectedRowID,
            onSelectionChange: onSelectionChange,
            onDoubleClick: onDoubleClick,
            onSortByColumn: onSortByColumn,
            onToggleColumnFromHeader: onToggleColumnFromHeader,
            allowsMultipleSelection: allowsMultipleSelection,
            emptyMessage: emptyMessage,
            accessibilityLabel: accessibilityLabel,
            activationHint: activationHint
        )
    }

    func makeNSView(context: Context) -> IntrinsicTableContainerView {
        let metrics = Self.metrics(for: descriptor.defaultDensity)
        let tableView = ActionTableView(frame: .zero)
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsColumnReordering = true
        tableView.allowsColumnResizing = true
        tableView.allowsTypeSelect = true
        tableView.allowsMultipleSelection = allowsMultipleSelection
        tableView.headerView = NSTableHeaderView()
        tableView.delegate = context.coordinator
        tableView.dataSource = context.coordinator
        tableView.target = context.coordinator
        tableView.actionCoordinator = context.coordinator
        tableView.doubleAction = #selector(Coordinator.handleDoubleClick(_:))
        tableView.rowSizeStyle = .small
        tableView.rowHeight = metrics.rowHeight
        tableView.intercellSpacing = NSSize(width: metrics.intercellWidth, height: metrics.intercellHeight)
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle

        let containerView = IntrinsicTableContainerView(frame: .zero)
        let scrollView = containerView.scrollView
        scrollView.documentView = tableView

        context.coordinator.attach(tableView: tableView, containerView: containerView)
        context.coordinator.apply(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: selectedRowID,
            onSelectionChange: onSelectionChange,
            onDoubleClick: onDoubleClick,
            onSortByColumn: onSortByColumn,
            onToggleColumnFromHeader: onToggleColumnFromHeader,
            allowsMultipleSelection: allowsMultipleSelection,
            emptyMessage: emptyMessage,
            accessibilityLabel: accessibilityLabel,
            activationHint: activationHint
        )
        return containerView
    }

    func updateNSView(_ containerView: IntrinsicTableContainerView, context: Context) {
        context.coordinator.apply(
            descriptor: descriptor,
            rows: rows,
            selectedRowID: selectedRowID,
            onSelectionChange: onSelectionChange,
            onDoubleClick: onDoubleClick,
            onSortByColumn: onSortByColumn,
            onToggleColumnFromHeader: onToggleColumnFromHeader,
            allowsMultipleSelection: allowsMultipleSelection,
            emptyMessage: emptyMessage,
            accessibilityLabel: accessibilityLabel,
            activationHint: activationHint
        )
    }

    final class ActionTableView: NSTableView {
        weak var actionCoordinator: Coordinator?

        override func keyDown(with event: NSEvent) {
            if event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
               event.charactersIgnoringModifiers?.lowercased() == "c",
               actionCoordinator?.copySelectedRowsToPasteboard() == true {
                return
            }
            if [36, 49, 76].contains(event.keyCode),
               actionCoordinator?.activateSelectedRow() == true {
                return
            }
            super.keyDown(with: event)
        }

        override func menu(for event: NSEvent) -> NSMenu? {
            let point = convert(event.locationInWindow, from: nil)
            let clickedRow = row(at: point)
            if clickedRow >= 0, !selectedRowIndexes.contains(clickedRow) {
                selectRowIndexes(IndexSet(integer: clickedRow), byExtendingSelection: false)
            }
            return super.menu(for: event)
        }
    }

    final class IntrinsicTableContainerView: NSView {
        let scrollView = IntrinsicTableScrollView(frame: .zero)
        private let emptyLabel = NSTextField(labelWithString: "")

        override init(frame frameRect: NSRect) {
            super.init(frame: frameRect)

            scrollView.hasVerticalScroller = true
            scrollView.hasHorizontalScroller = true
            scrollView.autohidesScrollers = true
            scrollView.borderType = .noBorder
            scrollView.drawsBackground = false
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            addSubview(scrollView)

            emptyLabel.alignment = .center
            emptyLabel.font = .systemFont(ofSize: 13)
            emptyLabel.textColor = .secondaryLabelColor
            emptyLabel.maximumNumberOfLines = 0
            emptyLabel.lineBreakMode = .byWordWrapping
            emptyLabel.translatesAutoresizingMaskIntoConstraints = false
            addSubview(emptyLabel)

            NSLayoutConstraint.activate([
                scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
                scrollView.topAnchor.constraint(equalTo: topAnchor),
                scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),

                emptyLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
                emptyLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
                emptyLabel.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
                emptyLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24)
            ])
        }

        required init?(coder: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        func updateEmptyState(message: String, isEmpty: Bool) {
            emptyLabel.stringValue = message
            emptyLabel.isHidden = !isEmpty
            scrollView.isHidden = isEmpty
        }

        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: 360)
        }
    }

    final class IntrinsicTableScrollView: NSScrollView {
        override var intrinsicContentSize: NSSize {
            NSSize(width: NSView.noIntrinsicMetric, height: 360)
        }
    }

    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        private var descriptor: NativeTableDescriptor
        private var rows: [NativeTableRowDescriptor]
        private var selectedRowID: String?
        private var onSelectionChange: ((String?) -> Void)?
        private var onDoubleClick: ((String) -> Void)?
        private var onSortByColumn: ((String) -> Void)?
        private var onToggleColumnFromHeader: ((String) -> Void)?
        private var allowsMultipleSelection: Bool
        private var emptyMessage: String
        private var accessibilityLabel: String?
        private var activationHint: String?
        private weak var tableView: NSTableView?
        private weak var containerView: IntrinsicTableContainerView?
        private var hasBuiltColumns = false
        private var selectedRowIDs: Set<String>

        init(
            descriptor: NativeTableDescriptor,
            rows: [NativeTableRowDescriptor],
            selectedRowID: String?,
            onSelectionChange: ((String?) -> Void)?,
            onDoubleClick: ((String) -> Void)?,
            onSortByColumn: ((String) -> Void)? = nil,
            onToggleColumnFromHeader: ((String) -> Void)? = nil,
            allowsMultipleSelection: Bool = true,
            emptyMessage: String = "当前没有可显示的数据。",
            accessibilityLabel: String? = nil,
            activationHint: String? = nil
        ) {
            self.descriptor = descriptor
            self.rows = rows
            self.selectedRowID = selectedRowID
            self.onSelectionChange = onSelectionChange
            self.onDoubleClick = onDoubleClick
            self.onSortByColumn = onSortByColumn
            self.onToggleColumnFromHeader = onToggleColumnFromHeader
            self.allowsMultipleSelection = allowsMultipleSelection
            self.emptyMessage = emptyMessage
            self.accessibilityLabel = accessibilityLabel
            self.activationHint = activationHint
            if let selectedRowID {
                self.selectedRowIDs = [selectedRowID]
            } else {
                self.selectedRowIDs = []
            }
        }

        func attach(tableView: NSTableView) {
            self.tableView = tableView
        }

        func attach(tableView: NSTableView, containerView: IntrinsicTableContainerView) {
            self.tableView = tableView
            self.containerView = containerView
        }

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
            emptyMessage: String = "当前没有可显示的数据。",
            accessibilityLabel: String? = nil,
            activationHint: String? = nil
        ) {
            let previousDescriptor = self.descriptor
            let previousRows = self.rows
            let previousSelectedRowID = self.selectedRowID
            let previousSelectedRowIDs = self.selectedRowIDs
            let previousDensity = resolvedDensity(for: previousDescriptor)
            let columnsChanged = previousDescriptor != descriptor
            let rowsChanged = previousRows != rows
            self.descriptor = descriptor
            self.rows = rows
            self.selectedRowID = selectedRowID
            self.onSelectionChange = onSelectionChange
            self.onDoubleClick = onDoubleClick
            self.onSortByColumn = onSortByColumn
            self.onToggleColumnFromHeader = onToggleColumnFromHeader
            self.allowsMultipleSelection = allowsMultipleSelection
            self.emptyMessage = emptyMessage
            self.accessibilityLabel = accessibilityLabel
            self.activationHint = activationHint
            tableView?.allowsMultipleSelection = allowsMultipleSelection
            let nextDensity = resolvedDensity()
            updateTableMetrics(nextDensity)
            let availableIDs = Set(rows.map(\.id))
            selectedRowIDs = previousSelectedRowIDs.intersection(availableIDs)
            if let selectedRowID, availableIDs.contains(selectedRowID) {
                selectedRowIDs.insert(selectedRowID)
            }
            let selectionChanged = previousSelectedRowID != selectedRowID || previousSelectedRowIDs != selectedRowIDs
            let emptinessChanged = previousRows.isEmpty != rows.isEmpty
            if columnsChanged || previousDensity != nextDensity || !hasBuiltColumns {
                rebuildColumns()
            }
            if columnsChanged || previousDensity != nextDensity || tableView?.headerView?.menu == nil {
                rebuildHeaderMenu()
            }
            if selectionChanged || emptinessChanged || tableView?.menu == nil {
                rebuildRowMenu()
            }
            if columnsChanged {
                tableView?.reloadData()
            } else if rowsChanged {
                reloadVisibleRows(previousRowCount: previousRows.count)
            }
            tableView?.setAccessibilityLabel(accessibilityLabel ?? wordZText("结果表格", "Results table", mode: .system))
            tableView?.setAccessibilityHelp(activationHint)
            syncSelection()
            syncEmptyState()
        }

        @MainActor
        private func rebuildColumns() {
            guard let tableView else { return }
            let density = resolvedDensity()
            let metrics = NativeTableView.metrics(for: density)
            while !tableView.tableColumns.isEmpty {
                tableView.removeTableColumn(tableView.tableColumns[0])
            }

            for column in orderedVisibleColumns() {
                let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.id))
                tableColumn.title = column.sortIndicator.map { "\(column.title) \($0)" } ?? column.title
                tableColumn.minWidth = minimumWidth(for: column)
                tableColumn.maxWidth = maximumWidth(for: column)
                tableColumn.width = clampedWidth(storedWidth(for: column) ?? preferredWidth(for: column, density: density), for: column)
                tableColumn.headerCell.font = .systemFont(
                    ofSize: metrics.headerFontSize,
                    weight: column.sortIndicator == nil ? .medium : .bold
                )
                tableColumn.headerCell.alignment = alignment(for: column)
                tableColumn.headerToolTip = column.title
                tableView.addTableColumn(tableColumn)
            }
            hasBuiltColumns = true
        }

        @MainActor
        private func rebuildHeaderMenu() {
            guard let headerView = tableView?.headerView else { return }
            let menu = NSMenu(title: wordZText("列", "Columns", mode: .system))
            for column in descriptor.columns {
                let item = NSMenuItem(
                    title: column.title,
                    action: #selector(handleHeaderMenuSelection(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = column.id
                item.state = column.isVisible ? .on : .off
                item.isEnabled = !column.isVisible || descriptor.visibleColumns.count > 1
                menu.addItem(item)
            }
            menu.addItem(.separator())
            let densityItem = NSMenuItem(
                title: wordZText("表格密度", "Table Density", mode: .system),
                action: nil,
                keyEquivalent: ""
            )
            let densityMenu = NSMenu(title: densityItem.title)
            let selectedDensity = resolvedDensity()
            for preset in NativeTableDensityPreset.allCases {
                let item = NSMenuItem(
                    title: preset.title(in: .system),
                    action: #selector(handleDensityMenuSelection(_:)),
                    keyEquivalent: ""
                )
                item.target = self
                item.representedObject = preset.rawValue
                item.state = preset == selectedDensity ? .on : .off
                densityMenu.addItem(item)
            }
            densityItem.submenu = densityMenu
            menu.addItem(densityItem)

            menu.addItem(.separator())
            let resetItem = NSMenuItem(
                title: wordZText("恢复默认列布局", "Restore Default Layout", mode: .system),
                action: #selector(handleResetTableLayout(_:)),
                keyEquivalent: ""
            )
            resetItem.target = self
            menu.addItem(resetItem)
            headerView.menu = menu
        }

        @MainActor
        private func rebuildRowMenu() {
            guard let tableView else { return }
            let menu = NSMenu(title: wordZText("行", "Rows", mode: .system))

            let copyItem = NSMenuItem(
                title: wordZText("复制所选行", "Copy Selected Rows", mode: .system),
                action: #selector(handleCopySelectedRows(_:)),
                keyEquivalent: ""
            )
            copyItem.target = self
            copyItem.isEnabled = !resolvedSelectedRowIndexes().isEmpty
            menu.addItem(copyItem)

            let selectAllItem = NSMenuItem(
                title: wordZText("全选", "Select All", mode: .system),
                action: #selector(handleSelectAllRows(_:)),
                keyEquivalent: ""
            )
            selectAllItem.target = self
            selectAllItem.isEnabled = !rows.isEmpty
            menu.addItem(selectAllItem)

            tableView.menu = menu
        }

        private func preferredWidth(for column: NativeTableColumnDescriptor, density: NativeTableDensityPreset) -> CGFloat {
            switch column.widthPolicy {
            case .compact:
                return density == .reading ? 92 : 82
            case .numeric:
                return density == .reading ? 94 : 82
            case .standard:
                return density == .reading ? 128 : 110
            case .keyword:
                return density == .reading ? 180 : 156
            case .context:
                return density == .compact ? 220 : (density == .standard ? 260 : 320)
            case .summary:
                return density == .compact ? 220 : (density == .standard ? 260 : 320)
            }
        }

        private func minimumWidth(for column: NativeTableColumnDescriptor) -> CGFloat {
            switch column.widthPolicy {
            case .compact, .numeric:
                return 56
            case .standard:
                return 96
            case .keyword:
                return 120
            case .context:
                return 180
            case .summary:
                return 160
            }
        }

        private func maximumWidth(for column: NativeTableColumnDescriptor) -> CGFloat {
            switch column.widthPolicy {
            case .context:
                return LayoutMetrics.maximumContextWidth
            case .summary:
                return LayoutMetrics.maximumSummaryWidth
            default:
                return LayoutMetrics.maximumCompactWidth
            }
        }

        private func clampedWidth(_ width: CGFloat, for column: NativeTableColumnDescriptor) -> CGFloat {
            min(max(width, minimumWidth(for: column)), maximumWidth(for: column))
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableViewColumnDidResize(_ notification: Notification) {
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

        func tableViewColumnDidMove(_ notification: Notification) {
            guard let tableView else { return }
            persistColumnOrder(from: tableView.tableColumns.map(\.identifier.rawValue))
            let expectedOrder = orderedVisibleColumns().map(\.id)
            let currentOrder = tableView.tableColumns.map(\.identifier.rawValue)
            if currentOrder != expectedOrder {
                rebuildColumns()
                tableView.reloadData()
            }
        }

        func tableView(_ tableView: NSTableView, didClick tableColumn: NSTableColumn) {
            onSortByColumn?(tableColumn.identifier.rawValue)
        }

        func tableViewSelectionDidChange(_ notification: Notification) {
            guard let tableView else { return }
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
            guard selectedRowID != nextSelection else { return }
            selectedRowID = nextSelection
            onSelectionChange?(nextSelection)
            rebuildRowMenu()
        }

        @MainActor @objc
        func handleHeaderMenuSelection(_ sender: NSMenuItem) {
            guard let columnID = sender.representedObject as? String else { return }
            onToggleColumnFromHeader?(columnID)
        }

        @MainActor @objc
        func handleResetTableLayout(_ sender: NSMenuItem) {
            clearStoredLayout()
            updateTableMetrics(descriptor.defaultDensity)
            rebuildColumns()
            rebuildHeaderMenu()
            rebuildRowMenu()
            tableView?.reloadData()
        }

        @MainActor @objc
        func handleDensityMenuSelection(_ sender: NSMenuItem) {
            guard
                let rawValue = sender.representedObject as? String,
                let density = NativeTableDensityPreset(rawValue: rawValue)
            else {
                return
            }
            persistDensity(density)
            updateTableMetrics(density)
            rebuildColumns()
            rebuildHeaderMenu()
            tableView?.reloadData()
        }

        @MainActor @objc
        func handleCopySelectedRows(_ sender: Any?) {
            _ = copySelectedRowsToPasteboard()
        }

        @MainActor @objc
        func handleSelectAllRows(_ sender: Any?) {
            guard let tableView, !rows.isEmpty else { return }
            tableView.selectRowIndexes(IndexSet(integersIn: 0..<rows.count), byExtendingSelection: false)
        }

        @MainActor @objc
        func handleDoubleClick(_ sender: Any?) {
            guard let tableView else { return }
            let rowIndex = tableView.clickedRow >= 0 ? tableView.clickedRow : tableView.selectedRow
            guard rowIndex >= 0, rowIndex < rows.count else { return }
            let rowID = rows[rowIndex].id
            if selectedRowID != rowID {
                selectedRowID = rowID
                onSelectionChange?(rowID)
            }
            onDoubleClick?(rowID)
        }

        func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
            guard row >= 0, row < rows.count, let tableColumn else { return nil }
            let identifier = tableColumn.identifier
            let columnID = identifier.rawValue
            guard let column = descriptor.column(id: columnID) else { return nil }
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
        private func syncSelection() {
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
        private func syncEmptyState() {
            containerView?.updateEmptyState(message: emptyMessage, isEmpty: rows.isEmpty)
        }

        @MainActor
        private func reloadVisibleRows(previousRowCount: Int) {
            guard let tableView else { return }
            if previousRowCount != rows.count {
                tableView.noteNumberOfRowsChanged()
            }

            let columnCount = tableView.numberOfColumns
            guard columnCount > 0 else {
                tableView.reloadData()
                return
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
                return
            }
            tableView.reloadData(
                forRowIndexes: rowIndexes,
                columnIndexes: IndexSet(integersIn: 0..<columnCount)
            )
        }

        private func persistWidth(_ width: CGFloat, for column: NativeTableColumnDescriptor) {
            UserDefaults.standard.set(Double(clampedWidth(width, for: column)), forKey: storageKey(for: column.id))
        }

        private func storedWidth(for column: NativeTableColumnDescriptor) -> CGFloat? {
            let value = UserDefaults.standard.double(forKey: storageKey(for: column.id))
            guard value > 0 else { return nil }
            return clampedWidth(CGFloat(value), for: column)
        }

        private func storageKey(for columnID: String) -> String {
            "wordz.nativeTable.\(LayoutMetrics.storageVersion).\(descriptor.storageKey).\(columnID).width"
        }

        private func orderedVisibleColumns() -> [NativeTableColumnDescriptor] {
            let storedOrder = storedColumnOrder()
            let orderedAllColumns: [NativeTableColumnDescriptor]
            if storedOrder.isEmpty {
                orderedAllColumns = descriptor.columns
            } else {
                let columnsByID = Dictionary(uniqueKeysWithValues: descriptor.columns.map { ($0.id, $0) })
                orderedAllColumns = storedOrder.compactMap { columnsByID[$0] }
                    + descriptor.columns.filter { !storedOrder.contains($0.id) }
            }
            let visibleColumns = orderedAllColumns.filter(\.isVisible)
            return visibleColumns.filter(\.isPinned) + visibleColumns.filter { !$0.isPinned }
        }

        private func persistColumnOrder(from visibleColumnIDs: [String]) {
            let baselineOrder = storedColumnOrder().isEmpty
                ? descriptor.columns.map(\.id)
                : storedColumnOrder()
            let hiddenColumnIDs = baselineOrder.filter { descriptor.column(id: $0) != nil && !visibleColumnIDs.contains($0) }
            let newColumns = descriptor.columns.map(\.id).filter { !baselineOrder.contains($0) && !visibleColumnIDs.contains($0) }
            UserDefaults.standard.set(visibleColumnIDs + hiddenColumnIDs + newColumns, forKey: columnOrderKey())
        }

        private func storedColumnOrder() -> [String] {
            UserDefaults.standard.stringArray(forKey: columnOrderKey()) ?? []
        }

        private func clearStoredLayout() {
            descriptor.columns.forEach { column in
                UserDefaults.standard.removeObject(forKey: storageKey(for: column.id))
            }
            UserDefaults.standard.removeObject(forKey: columnOrderKey())
            UserDefaults.standard.removeObject(forKey: densityKey())
        }

        private func columnOrderKey() -> String {
            "wordz.nativeTable.\(LayoutMetrics.storageVersion).\(descriptor.storageKey).columnOrder"
        }

        @MainActor
        private func selectedRowIndexes() -> [Int] {
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
        private func resolvedSelectedRowIndexes() -> [Int] {
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

        @MainActor
        private func configure(_ textField: NSTextField, for columnID: String) {
            guard let column = descriptor.column(id: columnID) else { return }
            configure(textField, for: column)
        }

        @MainActor
        private func configure(_ textField: NSTextField, for column: NativeTableColumnDescriptor) {
            let metrics = NativeTableView.metrics(for: resolvedDensity())
            textField.maximumNumberOfLines = 1
            textField.alignment = alignment(for: column)
            textField.font = font(for: column, metrics: metrics)
            textField.textColor = textColor(for: column)
            textField.lineBreakMode = lineBreakMode(for: column)
            textField.backgroundColor = .clear
            textField.drawsBackground = false
        }

        private func alignment(for column: NativeTableColumnDescriptor) -> NSTextAlignment {
            switch column.presentation {
            case .numeric:
                return .right
            case .keyword, .contextCenter:
                return .center
            case .contextLeading:
                return .right
            default:
                return .left
            }
        }

        private func font(for column: NativeTableColumnDescriptor, metrics: NativeTableView.DensityMetrics) -> NSFont {
            switch column.presentation {
            case .numeric:
                return .monospacedSystemFont(ofSize: metrics.fontSize, weight: .regular)
            case .keyword:
                return .systemFont(ofSize: metrics.fontSize, weight: .semibold)
            default:
                return .systemFont(ofSize: metrics.fontSize)
            }
        }

        private func textColor(for column: NativeTableColumnDescriptor) -> NSColor {
            switch column.presentation {
            case .keyword:
                return .controlAccentColor
            case .contextLeading, .contextTrailing, .summary:
                return .secondaryLabelColor
            default:
                return .labelColor
            }
        }

        private func lineBreakMode(for column: NativeTableColumnDescriptor) -> NSLineBreakMode {
            switch column.presentation {
            case .contextLeading:
                return .byTruncatingHead
            case .summary:
                return .byTruncatingMiddle
            default:
                return .byTruncatingTail
            }
        }

        private func displayValue(_ rawValue: String, for column: NativeTableColumnDescriptor) -> String {
            switch column.presentation {
            case .numeric(let precision, let usesGrouping):
                return formattedNumericValue(rawValue, precision: precision, usesGrouping: usesGrouping)
            default:
                return rawValue
            }
        }

        private func formattedNumericValue(_ rawValue: String, precision: Int?, usesGrouping: Bool) -> String {
            let normalized = rawValue.replacingOccurrences(of: ",", with: "")
            guard let number = Double(normalized) else { return rawValue }
            if let precision, number != 0 {
                let threshold = pow(10.0, Double(-precision))
                if abs(number) < threshold {
                    return number < 0
                        ? "-<\(formattedThreshold(threshold, precision: precision))"
                        : "<\(formattedThreshold(threshold, precision: precision))"
                }
            }

            let resolvedPrecision: Int?
            if let precision {
                resolvedPrecision = precision
            } else if number.rounded() == number {
                resolvedPrecision = 0
            } else {
                resolvedPrecision = 2
            }

            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = usesGrouping
            if let resolvedPrecision {
                formatter.minimumFractionDigits = resolvedPrecision == 0 ? 0 : resolvedPrecision
                formatter.maximumFractionDigits = resolvedPrecision
            } else {
                formatter.minimumFractionDigits = 0
                formatter.maximumFractionDigits = 6
            }
            return formatter.string(from: NSNumber(value: number)) ?? rawValue
        }

        private func formattedThreshold(_ value: Double, precision: Int) -> String {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.usesGroupingSeparator = false
            formatter.minimumFractionDigits = precision
            formatter.maximumFractionDigits = precision
            return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(precision)f", value)
        }

        private func resolvedDensity() -> NativeTableDensityPreset {
            resolvedDensity(for: descriptor)
        }

        private func resolvedDensity(for descriptor: NativeTableDescriptor) -> NativeTableDensityPreset {
            guard
                let rawValue = UserDefaults.standard.string(forKey: densityKey(for: descriptor)),
                let density = NativeTableDensityPreset(rawValue: rawValue)
            else {
                return descriptor.defaultDensity
            }
            return density
        }

        @MainActor
        private func updateTableMetrics(_ density: NativeTableDensityPreset) {
            guard let tableView else { return }
            let metrics = NativeTableView.metrics(for: density)
            tableView.rowHeight = metrics.rowHeight
            tableView.intercellSpacing = NSSize(width: metrics.intercellWidth, height: metrics.intercellHeight)
        }

        private func persistDensity(_ density: NativeTableDensityPreset) {
            UserDefaults.standard.set(density.rawValue, forKey: densityKey())
        }

        private func densityKey() -> String {
            densityKey(for: descriptor)
        }

        private func densityKey(for descriptor: NativeTableDescriptor) -> String {
            "wordz.nativeTable.\(LayoutMetrics.storageVersion).\(descriptor.storageKey).density"
        }
    }
}
