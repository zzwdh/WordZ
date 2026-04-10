import AppKit

extension NativeTableView.Coordinator {
    @MainActor
    func rebuildHeaderMenu() {
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
    func rebuildRowMenu() {
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
}
