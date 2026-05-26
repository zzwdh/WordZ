import SwiftUI

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
