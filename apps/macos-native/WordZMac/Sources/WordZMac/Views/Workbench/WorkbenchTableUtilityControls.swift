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
    let title: String
    let keys: [Key]
    let label: (Key) -> String
    let isVisible: (Key) -> Bool
    let onToggle: (Key) -> Void

    var body: some View {
        Menu(title) {
            ForEach(keys) { key in
                Button {
                    onToggle(key)
                } label: {
                    Label(
                        label(key),
                        systemImage: isVisible(key) ? "checkmark.circle.fill" : "circle"
                    )
                }
            }
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
