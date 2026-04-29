import AppKit

extension NativeTableView.Coordinator {
    @MainActor
    func updateHeaderPinning() {
        guard let tableView, let containerView else { return }
        if isHeaderPinned {
            tableView.headerView = tableView.headerView ?? NSTableHeaderView()
        } else {
            tableView.headerView = nil
        }
        containerView.scrollView.tile()
        containerView.needsLayout = true
        containerView.layoutSubtreeIfNeeded()
    }

    @MainActor
    func rebuildColumns() {
        guard let tableView else { return }
        let density = resolvedDensity()
        let metrics = NativeTableView.metrics(for: density)
        while !tableView.tableColumns.isEmpty {
            tableView.removeTableColumn(tableView.tableColumns[0])
        }

        for column in orderedVisibleColumns() {
            let tableColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(column.id))
            tableColumn.title = column.title
            tableColumn.minWidth = minimumWidth(for: column)
            tableColumn.maxWidth = maximumWidth(for: column)
            tableColumn.width = clampedWidth(storedWidth(for: column) ?? preferredWidth(for: column, density: density), for: column)
            tableColumn.headerCell.font = .systemFont(
                ofSize: metrics.headerFontSize,
                weight: column.sortIndicator == nil ? .medium : .bold
            )
            tableColumn.headerCell.alignment = alignment(for: column)
            tableColumn.sortDescriptorPrototype = column.sortDirection.map {
                NSSortDescriptor(key: column.id, ascending: $0.isAscending)
            }
            tableColumn.headerToolTip = headerToolTip(for: column)
            tableView.addTableColumn(tableColumn)
            if let sortDirection = column.sortDirection {
                tableView.setIndicatorImage(sortIndicatorImage(for: sortDirection), in: tableColumn)
            }
        }
        tableView.sortDescriptors = descriptor.columns.compactMap { column in
            column.sortDirection.map { NSSortDescriptor(key: column.id, ascending: $0.isAscending) }
        }
        hasBuiltColumns = true
    }

    private func sortIndicatorImage(for direction: NativeTableSortDirection) -> NSImage? {
        switch direction {
        case .ascending:
            return NSImage(named: NSImage.Name("NSAscendingSortIndicator"))
        case .descending:
            return NSImage(named: NSImage.Name("NSDescendingSortIndicator"))
        }
    }

    private func headerToolTip(for column: NativeTableColumnDescriptor) -> String {
        guard let direction = column.sortDirection else { return column.title }
        switch direction {
        case .ascending:
            return wordZText(
                "\(column.title)，升序排序",
                "\(column.title), sorted ascending",
                mode: .system
            )
        case .descending:
            return wordZText(
                "\(column.title)，降序排序",
                "\(column.title), sorted descending",
                mode: .system
            )
        }
    }

    func preferredWidth(for column: NativeTableColumnDescriptor, density: NativeTableDensityPreset) -> CGFloat {
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

    func minimumWidth(for column: NativeTableColumnDescriptor) -> CGFloat {
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

    func maximumWidth(for column: NativeTableColumnDescriptor) -> CGFloat {
        switch column.widthPolicy {
        case .context:
            return NativeTableView.LayoutMetrics.maximumContextWidth
        case .summary:
            return NativeTableView.LayoutMetrics.maximumSummaryWidth
        default:
            return NativeTableView.LayoutMetrics.maximumCompactWidth
        }
    }

    func clampedWidth(_ width: CGFloat, for column: NativeTableColumnDescriptor) -> CGFloat {
        min(max(width, minimumWidth(for: column)), maximumWidth(for: column))
    }

    func persistWidth(_ width: CGFloat, for column: NativeTableColumnDescriptor) {
        UserDefaults.standard.set(Double(clampedWidth(width, for: column)), forKey: storageKey(for: column.id))
    }

    func storedWidth(for column: NativeTableColumnDescriptor) -> CGFloat? {
        let value = UserDefaults.standard.double(forKey: storageKey(for: column.id))
        guard value > 0 else { return nil }
        return clampedWidth(CGFloat(value), for: column)
    }

    func storageKey(for columnID: String) -> String {
        "wordz.nativeTable.\(NativeTableView.LayoutMetrics.storageVersion).\(descriptor.storageKey).\(columnID).width"
    }

    func orderedVisibleColumns() -> [NativeTableColumnDescriptor] {
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

    func persistColumnOrder(from visibleColumnIDs: [String]) {
        let baselineOrder = storedColumnOrder().isEmpty
            ? descriptor.columns.map(\.id)
            : storedColumnOrder()
        let hiddenColumnIDs = baselineOrder.filter { descriptor.column(id: $0) != nil && !visibleColumnIDs.contains($0) }
        let newColumns = descriptor.columns.map(\.id).filter { !baselineOrder.contains($0) && !visibleColumnIDs.contains($0) }
        UserDefaults.standard.set(visibleColumnIDs + hiddenColumnIDs + newColumns, forKey: columnOrderKey())
    }

    func storedColumnOrder() -> [String] {
        UserDefaults.standard.stringArray(forKey: columnOrderKey()) ?? []
    }

    func clearStoredLayout() {
        descriptor.columns.forEach { column in
            UserDefaults.standard.removeObject(forKey: storageKey(for: column.id))
        }
        UserDefaults.standard.removeObject(forKey: columnOrderKey())
        UserDefaults.standard.removeObject(forKey: densityKey())
    }

    func columnOrderKey() -> String {
        "wordz.nativeTable.\(NativeTableView.LayoutMetrics.storageVersion).\(descriptor.storageKey).columnOrder"
    }

    func resolvedDensity() -> NativeTableDensityPreset {
        resolvedDensity(for: descriptor)
    }

    func resolvedDensity(for descriptor: NativeTableDescriptor) -> NativeTableDensityPreset {
        guard
            let rawValue = UserDefaults.standard.string(forKey: densityKey(for: descriptor)),
            let density = NativeTableDensityPreset(rawValue: rawValue)
        else {
            return descriptor.defaultDensity
        }
        return density
    }

    @MainActor
    func updateTableMetrics(_ density: NativeTableDensityPreset) {
        guard let tableView else { return }
        let metrics = NativeTableView.metrics(for: density)
        tableView.rowHeight = metrics.rowHeight
        tableView.intercellSpacing = NSSize(width: metrics.intercellWidth, height: metrics.intercellHeight)
    }

    func persistDensity(_ density: NativeTableDensityPreset) {
        UserDefaults.standard.set(density.rawValue, forKey: densityKey())
    }

    func densityKey() -> String {
        densityKey(for: descriptor)
    }

    func densityKey(for descriptor: NativeTableDescriptor) -> String {
        "wordz.nativeTable.\(NativeTableView.LayoutMetrics.storageVersion).\(descriptor.storageKey).density"
    }
}
