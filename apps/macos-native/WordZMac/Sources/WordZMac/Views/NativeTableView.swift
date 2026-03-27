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
        tableView.rowHeight = 28
        tableView.intercellSpacing = NSSize(width: 8, height: 4)

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
            scrollView.borderType = .bezelBorder
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
            let columnsChanged = self.descriptor != descriptor
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
            let availableIDs = Set(rows.map(\.id))
            selectedRowIDs = selectedRowIDs.intersection(availableIDs)
            if let selectedRowID, availableIDs.contains(selectedRowID) {
                selectedRowIDs.insert(selectedRowID)
            }
            if columnsChanged || !hasBuiltColumns {
                rebuildColumns()
            }
            rebuildHeaderMenu()
            rebuildRowMenu()
            tableView?.reloadData()
            tableView?.setAccessibilityLabel(accessibilityLabel ?? wordZText("结果表格", "Results table", mode: .system))
            tableView?.setAccessibilityHelp(activationHint)
            syncSelection()
            syncEmptyState()
        }

        @MainActor
        private func rebuildColumns() {
            guard let tableView else { return }
            while !tableView.tableColumns.isEmpty {
                tableView.removeTableColumn(tableView.tableColumns[0])
            }

            for column in orderedVisibleColumns() {
                let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.id))
                tableColumn.title = column.sortIndicator.map { "\(column.title) \($0)" } ?? column.title
                tableColumn.minWidth = 80
                tableColumn.width = storedWidth(for: column.id) ?? preferredWidth(for: column.id)
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

        private func preferredWidth(for columnID: String) -> CGFloat {
            switch columnID {
            case "leftContext", "rightContext", "distribution", "text":
                return 260
            case "word", "keyword", "nodeWord", "phrase":
                return 180
            case "dominantCorpus":
                return 160
            default:
                return 110
            }
        }

        func numberOfRows(in tableView: NSTableView) -> Int {
            rows.count
        }

        func tableViewColumnDidResize(_ notification: Notification) {
            guard
                let tableView,
                let resizedColumn = notification.userInfo?["NSTableColumn"] as? NSTableColumn,
                tableView.tableColumns.contains(where: { $0 === resizedColumn })
            else {
                return
            }
            persistWidth(resizedColumn.width, for: resizedColumn.identifier.rawValue)
        }

        func tableViewColumnDidMove(_ notification: Notification) {
            guard let tableView else { return }
            persistColumnOrder(from: tableView.tableColumns.map(\.identifier.rawValue))
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
            rebuildColumns()
            rebuildHeaderMenu()
            rebuildRowMenu()
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
            let textField: NSTextField
            if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTextField {
                textField = reused
            } else {
                textField = NSTextField(labelWithString: "")
                textField.identifier = identifier
                textField.lineBreakMode = .byTruncatingTail
                textField.maximumNumberOfLines = 1
                textField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            }

            let value = rows[row].value(for: identifier.rawValue)
            textField.stringValue = value
            textField.alignment = isNumeric(value) ? .right : .left
            textField.font = isNumeric(value) ? .monospacedSystemFont(ofSize: 12, weight: .regular) : .systemFont(ofSize: 12)
            textField.toolTip = value
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

        private func persistWidth(_ width: CGFloat, for columnID: String) {
            UserDefaults.standard.set(Double(width), forKey: storageKey(for: columnID))
        }

        private func storedWidth(for columnID: String) -> CGFloat? {
            let value = UserDefaults.standard.double(forKey: storageKey(for: columnID))
            guard value > 0 else { return nil }
            return CGFloat(value)
        }

        private func storageKey(for columnID: String) -> String {
            "wordz.nativeTable.\(descriptor.storageKey).\(columnID).width"
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
            return orderedAllColumns.filter(\.isVisible)
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
        }

        private func columnOrderKey() -> String {
            "wordz.nativeTable.\(descriptor.storageKey).columnOrder"
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
            let visibleColumns = descriptor.visibleColumns
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

        private func isNumeric(_ value: String) -> Bool {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return false }
            return Double(trimmed.replacingOccurrences(of: ",", with: "")) != nil
        }
    }
}
