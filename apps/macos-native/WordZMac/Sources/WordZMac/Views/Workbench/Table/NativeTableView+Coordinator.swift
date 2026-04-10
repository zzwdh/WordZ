import AppKit

extension NativeTableView {
    final class Coordinator: NSObject, NSTableViewDataSource, NSTableViewDelegate {
        struct ReloadOutcome {
            let mode: AnalysisPerformanceTelemetry.TableReloadMode
            let reloadedRowCount: Int

            static let none = ReloadOutcome(mode: .none, reloadedRowCount: 0)
        }

        var descriptor: NativeTableDescriptor
        var rows: [NativeTableRowDescriptor]
        var selectedRowID: String?
        var onSelectionChange: ((String?) -> Void)?
        var onDoubleClick: ((String) -> Void)?
        var onSortByColumn: ((String) -> Void)?
        var onToggleColumnFromHeader: ((String) -> Void)?
        var allowsMultipleSelection: Bool
        var isHeaderPinned: Bool
        var emptyMessage: String
        var accessibilityLabel: String?
        var activationHint: String?
        weak var tableView: NSTableView?
        weak var containerView: IntrinsicTableContainerView?
        var hasBuiltColumns = false
        var selectedRowIDs: Set<String>

        init(
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
    }
}
