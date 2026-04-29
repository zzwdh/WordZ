import SwiftUI

struct WorkbenchGuardedPageSizePicker<PageSize: InteractiveAllPageSizing & CaseIterable & Identifiable & Hashable>: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    let title: String
    @Binding var selection: PageSize
    let totalRows: Int
    let label: (PageSize) -> String
    let maxWidth: CGFloat

    init(
        title: String,
        selection: Binding<PageSize>,
        totalRows: Int,
        maxWidth: CGFloat = 300,
        label: @escaping (PageSize) -> String
    ) {
        self.title = title
        self._selection = selection
        self.totalRows = totalRows
        self.label = label
        self.maxWidth = maxWidth
    }

    private var disablesInteractiveAllPageSize: Bool {
        !PageSize.allowsInteractiveAllPageSize(totalRows: totalRows)
    }

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(Array(PageSize.allCases)) { size in
                Text(label(size))
                    .tag(size)
                    .disabled(disablesInteractiveAllPageSize && size.isAllSelection)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: maxWidth)
        .help(disablesInteractiveAllPageSize ? wordZText("结果较大时，“全部”页大小会被禁用，以保持界面响应。", "For large result sets, the All page size is disabled to keep the UI responsive.", mode: languageMode) : "")
    }
}

struct WorkbenchPaginationControls: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    let canGoBackward: Bool
    let canGoForward: Bool
    let rangeLabel: String
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button {
                onPrevious()
            } label: {
                Label(wordZText("上一页", "Previous", mode: languageMode), systemImage: "chevron.left")
            }
            .disabled(!canGoBackward)

            Text(rangeLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Button {
                onNext()
            } label: {
                Label(wordZText("下一页", "Next", mode: languageMode), systemImage: "chevron.right")
            }
            .disabled(!canGoForward)
        }
    }
}

struct WorkbenchColumnMenu<Key: Identifiable>: View {
    @Environment(\.wordZLanguageMode) private var languageMode
    let title: String
    let keys: [Key]
    let label: (Key) -> String
    let isVisible: (Key) -> Bool
    let onToggle: (Key) -> Void

    var body: some View {
        Menu(title) {
            ForEach(keys) { key in
                Toggle(
                    isOn: Binding(
                        get: { isVisible(key) },
                        set: { newValue in
                            guard newValue != isVisible(key),
                                  Self.canToggle(key, keys: keys, isVisible: isVisible)
                            else { return }
                            onToggle(key)
                        }
                    )
                ) {
                    Text(label(key))
                }
                .disabled(!Self.canToggle(key, keys: keys, isVisible: isVisible))
                .help(toggleHelp(for: key))
            }
        }
    }

    static func canToggle(
        _ key: Key,
        keys: [Key],
        isVisible: (Key) -> Bool
    ) -> Bool {
        !isVisible(key) || visibleCount(keys: keys, isVisible: isVisible) > 1
    }

    static func visibleCount(
        keys: [Key],
        isVisible: (Key) -> Bool
    ) -> Int {
        keys.filter(isVisible).count
    }

    private func toggleHelp(for key: Key) -> String {
        guard !Self.canToggle(key, keys: keys, isVisible: isVisible) else { return "" }
        return wordZText("至少保留一列可见。", "Keep at least one column visible.", mode: languageMode)
    }
}

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

struct WorkbenchTablePageSizeControls<
    PageSize: InteractiveAllPageSizing & CaseIterable & Identifiable & Hashable
>: View {
    let title: String
    @Binding var selectedPageSize: PageSize
    let totalRows: Int
    let label: (PageSize) -> String

    var body: some View {
        WorkbenchAdaptiveControlCluster {
            WorkbenchGuardedPageSizePicker(
                title: title,
                selection: $selectedPageSize,
                totalRows: totalRows,
                label: label
            )
        }
    }
}

struct WorkbenchTableSecondaryControls<Key: Identifiable, Leading: View, PaginationFallback: View>: View {
    let columnMenuTitle: String
    let keys: [Key]
    let label: (Key) -> String
    let isVisible: (Key) -> Bool
    let onToggle: (Key) -> Void
    let canGoBackward: Bool
    let canGoForward: Bool
    let rangeLabel: String
    let showsPaginationControls: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    private let leading: Leading
    private let paginationFallback: PaginationFallback

    init(
        columnMenuTitle: String,
        keys: [Key],
        label: @escaping (Key) -> String,
        isVisible: @escaping (Key) -> Bool,
        onToggle: @escaping (Key) -> Void,
        canGoBackward: Bool,
        canGoForward: Bool,
        rangeLabel: String,
        showsPaginationControls: Bool = true,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder paginationFallback: () -> PaginationFallback
    ) {
        self.columnMenuTitle = columnMenuTitle
        self.keys = keys
        self.label = label
        self.isVisible = isVisible
        self.onToggle = onToggle
        self.canGoBackward = canGoBackward
        self.canGoForward = canGoForward
        self.rangeLabel = rangeLabel
        self.showsPaginationControls = showsPaginationControls
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.leading = leading()
        self.paginationFallback = paginationFallback()
    }

    var body: some View {
        WorkbenchAdaptiveControlCluster {
            leading

            WorkbenchColumnMenu(
                title: columnMenuTitle,
                keys: keys,
                label: label,
                isVisible: isVisible,
                onToggle: onToggle
            )

            if showsPaginationControls {
                WorkbenchPaginationControls(
                    canGoBackward: canGoBackward,
                    canGoForward: canGoForward,
                    rangeLabel: rangeLabel,
                    onPrevious: onPrevious,
                    onNext: onNext
                )
            } else {
                paginationFallback
            }
        }
    }
}

extension WorkbenchTableSecondaryControls where Leading == EmptyView, PaginationFallback == EmptyView {
    init(
        columnMenuTitle: String,
        keys: [Key],
        label: @escaping (Key) -> String,
        isVisible: @escaping (Key) -> Bool,
        onToggle: @escaping (Key) -> Void,
        canGoBackward: Bool,
        canGoForward: Bool,
        rangeLabel: String,
        showsPaginationControls: Bool = true,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.init(
            columnMenuTitle: columnMenuTitle,
            keys: keys,
            label: label,
            isVisible: isVisible,
            onToggle: onToggle,
            canGoBackward: canGoBackward,
            canGoForward: canGoForward,
            rangeLabel: rangeLabel,
            showsPaginationControls: showsPaginationControls,
            onPrevious: onPrevious,
            onNext: onNext
        ) {
            EmptyView()
        } paginationFallback: {
            EmptyView()
        }
    }
}

extension WorkbenchTableSecondaryControls where Leading == EmptyView {
    init(
        columnMenuTitle: String,
        keys: [Key],
        label: @escaping (Key) -> String,
        isVisible: @escaping (Key) -> Bool,
        onToggle: @escaping (Key) -> Void,
        canGoBackward: Bool,
        canGoForward: Bool,
        rangeLabel: String,
        showsPaginationControls: Bool = true,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        @ViewBuilder paginationFallback: () -> PaginationFallback
    ) {
        self.init(
            columnMenuTitle: columnMenuTitle,
            keys: keys,
            label: label,
            isVisible: isVisible,
            onToggle: onToggle,
            canGoBackward: canGoBackward,
            canGoForward: canGoForward,
            rangeLabel: rangeLabel,
            showsPaginationControls: showsPaginationControls,
            onPrevious: onPrevious,
            onNext: onNext
        ) {
            EmptyView()
        } paginationFallback: {
            paginationFallback()
        }
    }
}

extension WorkbenchTableSecondaryControls where PaginationFallback == EmptyView {
    init(
        columnMenuTitle: String,
        keys: [Key],
        label: @escaping (Key) -> String,
        isVisible: @escaping (Key) -> Bool,
        onToggle: @escaping (Key) -> Void,
        canGoBackward: Bool,
        canGoForward: Bool,
        rangeLabel: String,
        showsPaginationControls: Bool = true,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading
    ) {
        self.init(
            columnMenuTitle: columnMenuTitle,
            keys: keys,
            label: label,
            isVisible: isVisible,
            onToggle: onToggle,
            canGoBackward: canGoBackward,
            canGoForward: canGoForward,
            rangeLabel: rangeLabel,
            showsPaginationControls: showsPaginationControls,
            onPrevious: onPrevious,
            onNext: onNext
        ) {
            leading()
        } paginationFallback: {
            EmptyView()
        }
    }
}

struct WorkbenchResultTrailingControls<Key: Identifiable, Leading: View>: View {
    let columnMenuTitle: String
    let keys: [Key]
    let label: (Key) -> String
    let isVisible: (Key) -> Bool
    let onToggle: (Key) -> Void
    let canGoBackward: Bool
    let canGoForward: Bool
    let rangeLabel: String
    let onPrevious: () -> Void
    let onNext: () -> Void
    private let leading: Leading

    init(
        columnMenuTitle: String,
        keys: [Key],
        label: @escaping (Key) -> String,
        isVisible: @escaping (Key) -> Bool,
        onToggle: @escaping (Key) -> Void,
        canGoBackward: Bool,
        canGoForward: Bool,
        rangeLabel: String,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading
    ) {
        self.columnMenuTitle = columnMenuTitle
        self.keys = keys
        self.label = label
        self.isVisible = isVisible
        self.onToggle = onToggle
        self.canGoBackward = canGoBackward
        self.canGoForward = canGoForward
        self.rangeLabel = rangeLabel
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.leading = leading()
    }

    var body: some View {
        HStack(spacing: 12) {
            leading

            WorkbenchColumnMenu(
                title: columnMenuTitle,
                keys: keys,
                label: label,
                isVisible: isVisible,
                onToggle: onToggle
            )

            WorkbenchPaginationControls(
                canGoBackward: canGoBackward,
                canGoForward: canGoForward,
                rangeLabel: rangeLabel,
                onPrevious: onPrevious,
                onNext: onNext
            )
        }
    }
}

extension WorkbenchResultTrailingControls where Leading == EmptyView {
    init(
        columnMenuTitle: String,
        keys: [Key],
        label: @escaping (Key) -> String,
        isVisible: @escaping (Key) -> Bool,
        onToggle: @escaping (Key) -> Void,
        canGoBackward: Bool,
        canGoForward: Bool,
        rangeLabel: String,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.init(
            columnMenuTitle: columnMenuTitle,
            keys: keys,
            label: label,
            isVisible: isVisible,
            onToggle: onToggle,
            canGoBackward: canGoBackward,
            canGoForward: canGoForward,
            rangeLabel: rangeLabel,
            onPrevious: onPrevious,
            onNext: onNext
        ) {
            EmptyView()
        }
    }
}

struct WorkbenchAdaptiveResultTrailingControls<Key: Identifiable, Leading: View, PaginationFallback: View>: View {
    let columnMenuTitle: String
    let keys: [Key]
    let label: (Key) -> String
    let isVisible: (Key) -> Bool
    let onToggle: (Key) -> Void
    let canGoBackward: Bool
    let canGoForward: Bool
    let rangeLabel: String
    let showsPaginationControls: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    private let leading: Leading
    private let paginationFallback: PaginationFallback

    init(
        columnMenuTitle: String,
        keys: [Key],
        label: @escaping (Key) -> String,
        isVisible: @escaping (Key) -> Bool,
        onToggle: @escaping (Key) -> Void,
        canGoBackward: Bool,
        canGoForward: Bool,
        rangeLabel: String,
        showsPaginationControls: Bool = true,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder paginationFallback: () -> PaginationFallback
    ) {
        self.columnMenuTitle = columnMenuTitle
        self.keys = keys
        self.label = label
        self.isVisible = isVisible
        self.onToggle = onToggle
        self.canGoBackward = canGoBackward
        self.canGoForward = canGoForward
        self.rangeLabel = rangeLabel
        self.showsPaginationControls = showsPaginationControls
        self.onPrevious = onPrevious
        self.onNext = onNext
        self.leading = leading()
        self.paginationFallback = paginationFallback()
    }

    var body: some View {
        WorkbenchAdaptiveControlCluster {
            leading

            WorkbenchColumnMenu(
                title: columnMenuTitle,
                keys: keys,
                label: label,
                isVisible: isVisible,
                onToggle: onToggle
            )

            if showsPaginationControls {
                WorkbenchPaginationControls(
                    canGoBackward: canGoBackward,
                    canGoForward: canGoForward,
                    rangeLabel: rangeLabel,
                    onPrevious: onPrevious,
                    onNext: onNext
                )
            } else {
                paginationFallback
            }
        }
    }
}

extension WorkbenchAdaptiveResultTrailingControls where Leading == EmptyView, PaginationFallback == EmptyView {
    init(
        columnMenuTitle: String,
        keys: [Key],
        label: @escaping (Key) -> String,
        isVisible: @escaping (Key) -> Bool,
        onToggle: @escaping (Key) -> Void,
        canGoBackward: Bool,
        canGoForward: Bool,
        rangeLabel: String,
        showsPaginationControls: Bool = true,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void
    ) {
        self.init(
            columnMenuTitle: columnMenuTitle,
            keys: keys,
            label: label,
            isVisible: isVisible,
            onToggle: onToggle,
            canGoBackward: canGoBackward,
            canGoForward: canGoForward,
            rangeLabel: rangeLabel,
            showsPaginationControls: showsPaginationControls,
            onPrevious: onPrevious,
            onNext: onNext
        ) {
            EmptyView()
        } paginationFallback: {
            EmptyView()
        }
    }
}

extension WorkbenchAdaptiveResultTrailingControls where Leading == EmptyView {
    init(
        columnMenuTitle: String,
        keys: [Key],
        label: @escaping (Key) -> String,
        isVisible: @escaping (Key) -> Bool,
        onToggle: @escaping (Key) -> Void,
        canGoBackward: Bool,
        canGoForward: Bool,
        rangeLabel: String,
        showsPaginationControls: Bool = true,
        onPrevious: @escaping () -> Void,
        onNext: @escaping () -> Void,
        @ViewBuilder paginationFallback: () -> PaginationFallback
    ) {
        self.init(
            columnMenuTitle: columnMenuTitle,
            keys: keys,
            label: label,
            isVisible: isVisible,
            onToggle: onToggle,
            canGoBackward: canGoBackward,
            canGoForward: canGoForward,
            rangeLabel: rangeLabel,
            showsPaginationControls: showsPaginationControls,
            onPrevious: onPrevious,
            onNext: onNext
        ) {
            EmptyView()
        } paginationFallback: {
            paginationFallback()
        }
    }
}
