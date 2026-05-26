import SwiftUI

struct WorkbenchTablePrimaryControls<
    SortOption: Identifiable & Hashable,
    PageSize: InteractiveAllPageSizing & CaseIterable & Identifiable & Hashable,
    Prefix: View,
    Middle: View
>: View {
    let sortTitle: String
    @Binding var selectedSort: SortOption
    let sortOptions: [SortOption]
    let sortLabel: (SortOption) -> String
    let pageSizeTitle: String
    @Binding var selectedPageSize: PageSize
    let totalRows: Int
    let showsPageSizeControl: Bool
    let pageSizeLabel: (PageSize) -> String
    private let prefix: Prefix
    private let middle: Middle

    init(
        sortTitle: String,
        selectedSort: Binding<SortOption>,
        sortOptions: [SortOption],
        sortLabel: @escaping (SortOption) -> String,
        pageSizeTitle: String,
        selectedPageSize: Binding<PageSize>,
        totalRows: Int,
        showsPageSizeControl: Bool = true,
        pageSizeLabel: @escaping (PageSize) -> String,
        @ViewBuilder prefix: () -> Prefix,
        @ViewBuilder middle: () -> Middle
    ) {
        self.sortTitle = sortTitle
        self._selectedSort = selectedSort
        self.sortOptions = sortOptions
        self.sortLabel = sortLabel
        self.pageSizeTitle = pageSizeTitle
        self._selectedPageSize = selectedPageSize
        self.totalRows = totalRows
        self.showsPageSizeControl = showsPageSizeControl
        self.pageSizeLabel = pageSizeLabel
        self.prefix = prefix()
        self.middle = middle()
    }

    var body: some View {
        WorkbenchAdaptiveControlCluster {
            prefix

            WorkbenchMenuPicker(
                title: sortTitle,
                selection: $selectedSort,
                options: sortOptions,
                label: sortLabel
            )

            middle

            if showsPageSizeControl {
                WorkbenchGuardedPageSizePicker(
                    title: pageSizeTitle,
                    selection: $selectedPageSize,
                    totalRows: totalRows,
                    label: pageSizeLabel
                )
            }
        }
    }
}

extension WorkbenchTablePrimaryControls where Prefix == EmptyView, Middle == EmptyView {
    init(
        sortTitle: String,
        selectedSort: Binding<SortOption>,
        sortOptions: [SortOption],
        sortLabel: @escaping (SortOption) -> String,
        pageSizeTitle: String,
        selectedPageSize: Binding<PageSize>,
        totalRows: Int,
        showsPageSizeControl: Bool = true,
        pageSizeLabel: @escaping (PageSize) -> String
    ) {
        self.init(
            sortTitle: sortTitle,
            selectedSort: selectedSort,
            sortOptions: sortOptions,
            sortLabel: sortLabel,
            pageSizeTitle: pageSizeTitle,
            selectedPageSize: selectedPageSize,
            totalRows: totalRows,
            showsPageSizeControl: showsPageSizeControl,
            pageSizeLabel: pageSizeLabel
        ) {
            EmptyView()
        } middle: {
            EmptyView()
        }
    }
}

extension WorkbenchTablePrimaryControls where Prefix == EmptyView {
    init(
        sortTitle: String,
        selectedSort: Binding<SortOption>,
        sortOptions: [SortOption],
        sortLabel: @escaping (SortOption) -> String,
        pageSizeTitle: String,
        selectedPageSize: Binding<PageSize>,
        totalRows: Int,
        showsPageSizeControl: Bool = true,
        pageSizeLabel: @escaping (PageSize) -> String,
        @ViewBuilder middle: () -> Middle
    ) {
        self.init(
            sortTitle: sortTitle,
            selectedSort: selectedSort,
            sortOptions: sortOptions,
            sortLabel: sortLabel,
            pageSizeTitle: pageSizeTitle,
            selectedPageSize: selectedPageSize,
            totalRows: totalRows,
            showsPageSizeControl: showsPageSizeControl,
            pageSizeLabel: pageSizeLabel
        ) {
            EmptyView()
        } middle: {
            middle()
        }
    }
}

extension WorkbenchTablePrimaryControls where Middle == EmptyView {
    init(
        sortTitle: String,
        selectedSort: Binding<SortOption>,
        sortOptions: [SortOption],
        sortLabel: @escaping (SortOption) -> String,
        pageSizeTitle: String,
        selectedPageSize: Binding<PageSize>,
        totalRows: Int,
        showsPageSizeControl: Bool = true,
        pageSizeLabel: @escaping (PageSize) -> String,
        @ViewBuilder prefix: () -> Prefix
    ) {
        self.init(
            sortTitle: sortTitle,
            selectedSort: selectedSort,
            sortOptions: sortOptions,
            sortLabel: sortLabel,
            pageSizeTitle: pageSizeTitle,
            selectedPageSize: selectedPageSize,
            totalRows: totalRows,
            showsPageSizeControl: showsPageSizeControl,
            pageSizeLabel: pageSizeLabel
        ) {
            prefix()
        } middle: {
            EmptyView()
        }
    }
}
