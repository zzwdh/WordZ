import AppKit
import SwiftUI

struct NativeTableView: NSViewRepresentable {
    @AppStorage(WorkbenchTablePreferences.pinnedHeaderKey) private var isHeaderPinned = true
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

    enum LayoutMetrics {
        static let storageVersion = "v3"
        static let minimumWidth: CGFloat = 56
        static let maximumCompactWidth: CGFloat = 280
        static let maximumContextWidth: CGFloat = 640
        static let maximumSummaryWidth: CGFloat = 420
    }

    struct DensityMetrics {
        let rowHeight: CGFloat
        let intercellWidth: CGFloat
        let intercellHeight: CGFloat
        let fontSize: CGFloat
        let headerFontSize: CGFloat
    }

    static func metrics(for density: NativeTableDensityPreset) -> DensityMetrics {
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
            isHeaderPinned: isHeaderPinned,
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
        tableView.headerView = isHeaderPinned ? NSTableHeaderView() : nil
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
            isHeaderPinned: isHeaderPinned,
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
            isHeaderPinned: isHeaderPinned,
            emptyMessage: emptyMessage,
            accessibilityLabel: accessibilityLabel,
            activationHint: activationHint
        )
    }
}
