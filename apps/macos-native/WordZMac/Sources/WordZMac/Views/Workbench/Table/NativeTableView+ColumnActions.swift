extension NativeTableView {
    @available(*, unavailable, message: "Pass ResultTableSnapshot with init(descriptor:snapshot:columnKey:) so typed column actions avoid row equality checks.")
    init<ColumnKey>(
        descriptor: NativeTableDescriptor,
        rows: [NativeTableRowDescriptor],
        selectedRowID: String? = nil,
        onSelectionChange: ((String?) -> Void)? = nil,
        onDoubleClick: ((String) -> Void)? = nil,
        columnKey: ColumnKey.Type,
        onSortByColumnKey: ((ColumnKey) -> Void)? = nil,
        onToggleColumnFromHeaderKey: ((ColumnKey) -> Void)? = nil,
        selectedMarkerID: String? = nil,
        onMarkerSelectionChange: ((String, String?) -> Void)? = nil,
        allowsMultipleSelection: Bool = true,
        emptyMessage: String = "当前没有可显示的数据。",
        accessibilityLabel: String? = nil,
        activationHint: String? = nil
    ) where ColumnKey: RawRepresentable, ColumnKey.RawValue == String {
        self.init(
            descriptor: descriptor,
            snapshot: ResultTableSnapshot.stable(rows: rows),
            selectedRowID: selectedRowID,
            onSelectionChange: onSelectionChange,
            onDoubleClick: onDoubleClick,
            columnKey: columnKey,
            onSortByColumnKey: onSortByColumnKey,
            onToggleColumnFromHeaderKey: onToggleColumnFromHeaderKey,
            selectedMarkerID: selectedMarkerID,
            onMarkerSelectionChange: onMarkerSelectionChange,
            allowsMultipleSelection: allowsMultipleSelection,
            emptyMessage: emptyMessage,
            accessibilityLabel: accessibilityLabel,
            activationHint: activationHint
        )
    }

    init<ColumnKey>(
        descriptor: NativeTableDescriptor,
        snapshot: ResultTableSnapshot,
        selectedRowID: String? = nil,
        onSelectionChange: ((String?) -> Void)? = nil,
        onDoubleClick: ((String) -> Void)? = nil,
        columnKey: ColumnKey.Type,
        onSortByColumnKey: ((ColumnKey) -> Void)? = nil,
        onToggleColumnFromHeaderKey: ((ColumnKey) -> Void)? = nil,
        selectedMarkerID: String? = nil,
        onMarkerSelectionChange: ((String, String?) -> Void)? = nil,
        allowsMultipleSelection: Bool = true,
        emptyMessage: String = "当前没有可显示的数据。",
        accessibilityLabel: String? = nil,
        activationHint: String? = nil
    ) where ColumnKey: RawRepresentable, ColumnKey.RawValue == String {
        self.init(
            descriptor: descriptor,
            snapshot: snapshot,
            selectedRowID: selectedRowID,
            onSelectionChange: onSelectionChange,
            onDoubleClick: onDoubleClick,
            onSortByColumn: Self.makeColumnHandler(columnKey: columnKey, action: onSortByColumnKey),
            onToggleColumnFromHeader: Self.makeColumnHandler(columnKey: columnKey, action: onToggleColumnFromHeaderKey),
            selectedMarkerID: selectedMarkerID,
            onMarkerSelectionChange: onMarkerSelectionChange,
            allowsMultipleSelection: allowsMultipleSelection,
            emptyMessage: emptyMessage,
            accessibilityLabel: accessibilityLabel,
            activationHint: activationHint
        )
    }

    private static func makeColumnHandler<ColumnKey>(
        columnKey: ColumnKey.Type,
        action: ((ColumnKey) -> Void)?
    ) -> ((String) -> Void)? where ColumnKey: RawRepresentable, ColumnKey.RawValue == String {
        guard let action else { return nil }
        return { columnID in
            guard let column = ColumnKey(rawValue: columnID) else { return }
            action(column)
        }
    }
}
