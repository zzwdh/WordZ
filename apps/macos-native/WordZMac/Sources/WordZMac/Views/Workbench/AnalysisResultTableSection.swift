import SwiftUI

struct AnalysisResultTableSection<
    ColumnKey: Identifiable & RawRepresentable,
    Header: View,
    HeaderTrailing: View,
    LeadingControls: View,
    SecondaryLeadingControls: View,
    TableSupplement: View,
    PaginationFallback: View
>: View where ColumnKey.RawValue == String {
    private let annotationState: WorkspaceAnnotationState?
    private let annotationResultCount: Int?
    private let showsAnnotationImpact: Bool
    private let descriptor: NativeTableDescriptor
    private let snapshot: ResultTableSnapshot
    private let selectedRowID: String?
    private let onSelectionChange: ((String?) -> Void)?
    private let onDoubleClick: ((String) -> Void)?
    private let columnKeys: [ColumnKey]
    private let columnMenuTitle: String
    private let columnLabel: (ColumnKey) -> String
    private let isColumnVisible: (ColumnKey) -> Bool
    private let onToggleColumn: (ColumnKey) -> Void
    private let onSortByColumn: ((ColumnKey) -> Void)?
    private let onToggleColumnFromHeader: ((ColumnKey) -> Void)?
    private let pagination: ResultPaginationSceneModel
    private let showsPaginationControls: Bool
    private let onPreviousPage: () -> Void
    private let onNextPage: () -> Void
    private let allowsMultipleSelection: Bool
    private let secondaryLeadingControls: SecondaryLeadingControls
    private let emptyMessage: String
    private let accessibilityLabel: String?
    private let activationHint: String?
    private let header: Header
    private let headerTrailing: HeaderTrailing
    private let leadingControls: LeadingControls
    private let tableSupplement: TableSupplement
    private let paginationFallback: PaginationFallback

    init(
        annotationState: WorkspaceAnnotationState? = nil,
        annotationResultCount: Int? = nil,
        showsAnnotationImpact: Bool = true,
        descriptor: NativeTableDescriptor,
        snapshot: ResultTableSnapshot,
        selectedRowID: String? = nil,
        onSelectionChange: ((String?) -> Void)? = nil,
        onDoubleClick: ((String) -> Void)? = nil,
        columnKeys: [ColumnKey],
        columnMenuTitle: String,
        columnLabel: @escaping (ColumnKey) -> String,
        isColumnVisible: @escaping (ColumnKey) -> Bool,
        onToggleColumn: @escaping (ColumnKey) -> Void,
        onSortByColumn: ((ColumnKey) -> Void)? = nil,
        onToggleColumnFromHeader: ((ColumnKey) -> Void)? = nil,
        pagination: ResultPaginationSceneModel,
        showsPaginationControls: Bool = true,
        onPreviousPage: @escaping () -> Void,
        onNextPage: @escaping () -> Void,
        allowsMultipleSelection: Bool = true,
        emptyMessage: String,
        accessibilityLabel: String? = nil,
        activationHint: String? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder headerTrailing: () -> HeaderTrailing,
        @ViewBuilder leadingControls: () -> LeadingControls,
        @ViewBuilder secondaryLeadingControls: () -> SecondaryLeadingControls,
        @ViewBuilder tableSupplement: () -> TableSupplement,
        @ViewBuilder paginationFallback: () -> PaginationFallback
    ) {
        self.annotationState = annotationState
        self.annotationResultCount = annotationResultCount
        self.showsAnnotationImpact = showsAnnotationImpact
        self.descriptor = descriptor
        self.snapshot = snapshot
        self.selectedRowID = selectedRowID
        self.onSelectionChange = onSelectionChange
        self.onDoubleClick = onDoubleClick
        self.columnKeys = columnKeys
        self.columnMenuTitle = columnMenuTitle
        self.columnLabel = columnLabel
        self.isColumnVisible = isColumnVisible
        self.onToggleColumn = onToggleColumn
        self.onSortByColumn = onSortByColumn
        self.onToggleColumnFromHeader = onToggleColumnFromHeader
        self.pagination = pagination
        self.showsPaginationControls = showsPaginationControls
        self.onPreviousPage = onPreviousPage
        self.onNextPage = onNextPage
        self.allowsMultipleSelection = allowsMultipleSelection
        self.secondaryLeadingControls = secondaryLeadingControls()
        self.emptyMessage = emptyMessage
        self.accessibilityLabel = accessibilityLabel
        self.activationHint = activationHint
        self.header = header()
        self.headerTrailing = headerTrailing()
        self.leadingControls = leadingControls()
        self.tableSupplement = tableSupplement()
        self.paginationFallback = paginationFallback()
    }

    var body: some View {
        WorkbenchResultsToolbarSection(
            annotationState: annotationState,
            annotationResultCount: annotationResultCount,
            showsAnnotationImpact: showsAnnotationImpact
        ) {
            header
        } trailing: {
            headerTrailing
        } leadingControls: {
            leadingControls
        } trailingControls: {
            WorkbenchTableSecondaryControls(
                columnMenuTitle: columnMenuTitle,
                keys: columnKeys,
                label: columnLabel,
                isVisible: isColumnVisible,
                onToggle: onToggleColumn,
                canGoBackward: pagination.canGoBackward,
                canGoForward: pagination.canGoForward,
                rangeLabel: pagination.rangeLabel,
                showsPaginationControls: showsPaginationControls,
                onPrevious: onPreviousPage,
                onNext: onNextPage,
                leading: {
                    secondaryLeadingControls
                },
                paginationFallback: {
                    paginationFallback
                }
            )
        }

        tableSupplement

        WorkbenchTableCard {
            NativeTableView(
                descriptor: descriptor,
                snapshot: snapshot,
                selectedRowID: selectedRowID,
                onSelectionChange: onSelectionChange,
                onDoubleClick: onDoubleClick,
                columnKey: ColumnKey.self,
                onSortByColumnKey: onSortByColumn,
                onToggleColumnFromHeaderKey: onToggleColumnFromHeader,
                allowsMultipleSelection: allowsMultipleSelection,
                emptyMessage: emptyMessage,
                accessibilityLabel: accessibilityLabel,
                activationHint: activationHint
            )
        }
    }
}

extension AnalysisResultTableSection where SecondaryLeadingControls == EmptyView {
    init(
        annotationState: WorkspaceAnnotationState? = nil,
        annotationResultCount: Int? = nil,
        showsAnnotationImpact: Bool = true,
        descriptor: NativeTableDescriptor,
        snapshot: ResultTableSnapshot,
        selectedRowID: String? = nil,
        onSelectionChange: ((String?) -> Void)? = nil,
        onDoubleClick: ((String) -> Void)? = nil,
        columnKeys: [ColumnKey],
        columnMenuTitle: String,
        columnLabel: @escaping (ColumnKey) -> String,
        isColumnVisible: @escaping (ColumnKey) -> Bool,
        onToggleColumn: @escaping (ColumnKey) -> Void,
        onSortByColumn: ((ColumnKey) -> Void)? = nil,
        onToggleColumnFromHeader: ((ColumnKey) -> Void)? = nil,
        pagination: ResultPaginationSceneModel,
        showsPaginationControls: Bool = true,
        onPreviousPage: @escaping () -> Void,
        onNextPage: @escaping () -> Void,
        allowsMultipleSelection: Bool = true,
        emptyMessage: String,
        accessibilityLabel: String? = nil,
        activationHint: String? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder headerTrailing: () -> HeaderTrailing,
        @ViewBuilder leadingControls: () -> LeadingControls,
        @ViewBuilder tableSupplement: () -> TableSupplement,
        @ViewBuilder paginationFallback: () -> PaginationFallback
    ) {
        self.init(
            annotationState: annotationState,
            annotationResultCount: annotationResultCount,
            showsAnnotationImpact: showsAnnotationImpact,
            descriptor: descriptor,
            snapshot: snapshot,
            selectedRowID: selectedRowID,
            onSelectionChange: onSelectionChange,
            onDoubleClick: onDoubleClick,
            columnKeys: columnKeys,
            columnMenuTitle: columnMenuTitle,
            columnLabel: columnLabel,
            isColumnVisible: isColumnVisible,
            onToggleColumn: onToggleColumn,
            onSortByColumn: onSortByColumn,
            onToggleColumnFromHeader: onToggleColumnFromHeader,
            pagination: pagination,
            showsPaginationControls: showsPaginationControls,
            onPreviousPage: onPreviousPage,
            onNextPage: onNextPage,
            allowsMultipleSelection: allowsMultipleSelection,
            emptyMessage: emptyMessage,
            accessibilityLabel: accessibilityLabel,
            activationHint: activationHint,
            header: header,
            headerTrailing: headerTrailing,
            leadingControls: leadingControls,
            secondaryLeadingControls: {
                EmptyView()
            },
            tableSupplement: tableSupplement,
            paginationFallback: paginationFallback
        )
    }
}
