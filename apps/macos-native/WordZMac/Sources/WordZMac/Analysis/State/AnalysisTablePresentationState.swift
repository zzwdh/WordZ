import Foundation

struct AnalysisTablePresentationState<Column: Hashable, SortMode: Equatable, PageSize: Equatable> {
    var sortMode: SortMode
    var pageSize: PageSize
    var currentPage: Int
    var visibleColumns: Set<Column>
    var sceneBuildRevision: Int

    init(
        sortMode: SortMode,
        pageSize: PageSize,
        currentPage: Int = 1,
        visibleColumns: Set<Column>,
        sceneBuildRevision: Int = 0
    ) {
        self.sortMode = sortMode
        self.pageSize = pageSize
        self.currentPage = currentPage
        self.visibleColumns = visibleColumns
        self.sceneBuildRevision = sceneBuildRevision
    }

    mutating func reset(
        sortMode: SortMode,
        pageSize: PageSize,
        visibleColumns: Set<Column>
    ) {
        self.sortMode = sortMode
        self.pageSize = pageSize
        self.currentPage = 1
        self.visibleColumns = visibleColumns
    }

    @discardableResult
    mutating func applySortModeChange(_ nextSort: SortMode) -> Bool {
        guard sortMode != nextSort else { return false }
        sortMode = nextSort
        currentPage = 1
        return true
    }

    @discardableResult
    mutating func applyPageSizeChange(_ nextPageSize: PageSize) -> Bool {
        guard pageSize != nextPageSize else { return false }
        pageSize = nextPageSize
        currentPage = 1
        return true
    }

    @discardableResult
    mutating func applyResolvedPageSizeChange(
        _ nextPageSize: PageSize,
        totalRows: Int?
    ) -> Bool where PageSize: InteractiveAllPageSizing {
        applyPageSizeChange(nextPageSize.resolvedInteractivePageSize(totalRows: totalRows))
    }

    @discardableResult
    mutating func toggleColumn(_ column: Column) -> Bool {
        AnalysisViewModelSupport.toggleVisibleColumn(column, in: &visibleColumns)
    }

    @discardableResult
    mutating func goToPreviousPage(canGoBackward: Bool) -> Bool {
        guard canGoBackward else { return false }
        currentPage = max(1, currentPage - 1)
        return true
    }

    @discardableResult
    mutating func goToNextPage(canGoForward: Bool) -> Bool {
        guard canGoForward else { return false }
        currentPage += 1
        return true
    }

    mutating func resetToFirstPage() {
        currentPage = 1
    }
}

struct AnalysisPagedPresentationState<Column: Hashable, PageSize: Equatable> {
    var pageSize: PageSize
    var currentPage: Int
    var visibleColumns: Set<Column>
    var sceneBuildRevision: Int

    init(
        pageSize: PageSize,
        currentPage: Int = 1,
        visibleColumns: Set<Column>,
        sceneBuildRevision: Int = 0
    ) {
        self.pageSize = pageSize
        self.currentPage = currentPage
        self.visibleColumns = visibleColumns
        self.sceneBuildRevision = sceneBuildRevision
    }

    mutating func reset(
        pageSize: PageSize,
        visibleColumns: Set<Column>
    ) {
        self.pageSize = pageSize
        self.currentPage = 1
        self.visibleColumns = visibleColumns
    }

    @discardableResult
    mutating func applyPageSizeChange(_ nextPageSize: PageSize) -> Bool {
        guard pageSize != nextPageSize else { return false }
        pageSize = nextPageSize
        currentPage = 1
        return true
    }

    @discardableResult
    mutating func applyResolvedPageSizeChange(
        _ nextPageSize: PageSize,
        totalRows: Int?
    ) -> Bool where PageSize: InteractiveAllPageSizing {
        applyPageSizeChange(nextPageSize.resolvedInteractivePageSize(totalRows: totalRows))
    }

    @discardableResult
    mutating func toggleColumn(_ column: Column) -> Bool {
        AnalysisViewModelSupport.toggleVisibleColumn(column, in: &visibleColumns)
    }

    @discardableResult
    mutating func goToPreviousPage(canGoBackward: Bool) -> Bool {
        guard canGoBackward else { return false }
        currentPage = max(1, currentPage - 1)
        return true
    }

    @discardableResult
    mutating func goToNextPage(canGoForward: Bool) -> Bool {
        guard canGoForward else { return false }
        currentPage += 1
        return true
    }

    mutating func resetToFirstPage() {
        currentPage = 1
    }
}

enum AnalysisTablePresentationMutation: Equatable {
    case sort
    case pageSize
    case pageNavigation
    case pageReset
    case columnVisibility
}

@MainActor
protocol AnalysisTablePresentationProviding: AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling {
    var tablePresentation: AnalysisTablePresentationState<AnalysisColumn, AnalysisSortMode, AnalysisPageSize> { get set }

    func tablePresentationDidChange(_ mutation: AnalysisTablePresentationMutation)
    func rebuildScene(for updateScope: AnalysisSceneUpdateScope)
}

@MainActor
extension AnalysisTablePresentationProviding {
    func tablePresentationDidChange(_ mutation: AnalysisTablePresentationMutation) {}

    func rebuildScene(for updateScope: AnalysisSceneUpdateScope) {
        guard updateScope.requiresSceneBuild else { return }
        rebuildScene()
    }

    var sortMode: AnalysisSortMode {
        get { tablePresentation.sortMode }
        set { tablePresentation.sortMode = newValue }
    }

    var pageSize: AnalysisPageSize {
        get { tablePresentation.pageSize }
        set { tablePresentation.pageSize = newValue }
    }

    var currentPage: Int {
        get { tablePresentation.currentPage }
        set { tablePresentation.currentPage = newValue }
    }

    var visibleColumns: Set<AnalysisColumn> {
        get { tablePresentation.visibleColumns }
        set { tablePresentation.visibleColumns = newValue }
    }

    func applyTableSortModeChange(_ nextSort: AnalysisSortMode) {
        guard tablePresentation.applySortModeChange(nextSort) else { return }
        let mutation = AnalysisTablePresentationMutation.sort
        tablePresentationDidChange(mutation)
        rebuildScene(for: AnalysisSceneUpdatePlanner.scope(for: mutation))
    }

    func toggleTableColumnAndRebuild(_ column: AnalysisColumn) {
        guard tablePresentation.toggleColumn(column) else { return }
        let mutation = AnalysisTablePresentationMutation.columnVisibility
        tablePresentationDidChange(mutation)
        rebuildScene(for: AnalysisSceneUpdatePlanner.scope(for: mutation))
    }

    func goToPreviousTablePage(canGoBackward: Bool) {
        guard tablePresentation.goToPreviousPage(canGoBackward: canGoBackward) else { return }
        let mutation = AnalysisTablePresentationMutation.pageNavigation
        tablePresentationDidChange(mutation)
        rebuildScene(for: AnalysisSceneUpdatePlanner.scope(for: mutation))
    }

    func goToNextTablePage(canGoForward: Bool) {
        guard tablePresentation.goToNextPage(canGoForward: canGoForward) else { return }
        let mutation = AnalysisTablePresentationMutation.pageNavigation
        tablePresentationDidChange(mutation)
        rebuildScene(for: AnalysisSceneUpdatePlanner.scope(for: mutation))
    }

    func resetTableToFirstPageAndRebuild() {
        tablePresentation.resetToFirstPage()
        let mutation = AnalysisTablePresentationMutation.pageReset
        tablePresentationDidChange(mutation)
        rebuildScene(for: AnalysisSceneUpdatePlanner.scope(for: mutation))
    }
}

@MainActor
extension AnalysisTablePresentationProviding where AnalysisPageSize: InteractiveAllPageSizing {
    func applyTablePageSizeChange(_ nextPageSize: AnalysisPageSize) {
        guard tablePresentation.applyResolvedPageSizeChange(
            nextPageSize,
            totalRows: currentResultRowCountForPaging
        ) else { return }
        let mutation = AnalysisTablePresentationMutation.pageSize
        tablePresentationDidChange(mutation)
        rebuildScene(for: AnalysisSceneUpdatePlanner.scope(for: mutation))
    }
}

@MainActor
protocol AnalysisTableColumnSortResolving: AnalysisTablePresentationProviding {
    func nextSortMode(
        for column: AnalysisColumn,
        currentSortMode: AnalysisSortMode
    ) -> AnalysisSortMode?
}

@MainActor
extension AnalysisTableColumnSortResolving {
    func sortTableByColumn(_ column: AnalysisColumn) {
        guard let nextSort = nextSortMode(for: column, currentSortMode: sortMode) else { return }
        applyTableSortModeChange(nextSort)
    }
}

@MainActor
protocol AnalysisVersionedTablePresentationProviding: AnalysisTablePresentationProviding, AnalysisSceneBuildRevisionControlling {}

@MainActor
extension AnalysisVersionedTablePresentationProviding {
    var sceneBuildRevision: Int {
        get { tablePresentation.sceneBuildRevision }
        set { tablePresentation.sceneBuildRevision = newValue }
    }
}

@MainActor
protocol AnalysisPagedPresentationProviding: AnalysisColumnVisibilityControlling, AnalysisPagingControlling {
    var tablePresentation: AnalysisPagedPresentationState<AnalysisColumn, AnalysisPageSize> { get set }

    func tablePresentationDidChange(_ mutation: AnalysisTablePresentationMutation)
    func rebuildScene(for updateScope: AnalysisSceneUpdateScope)
}

@MainActor
extension AnalysisPagedPresentationProviding {
    func tablePresentationDidChange(_ mutation: AnalysisTablePresentationMutation) {}

    func rebuildScene(for updateScope: AnalysisSceneUpdateScope) {
        guard updateScope.requiresSceneBuild else { return }
        rebuildScene()
    }

    var pageSize: AnalysisPageSize {
        get { tablePresentation.pageSize }
        set { tablePresentation.pageSize = newValue }
    }

    var currentPage: Int {
        get { tablePresentation.currentPage }
        set { tablePresentation.currentPage = newValue }
    }

    var visibleColumns: Set<AnalysisColumn> {
        get { tablePresentation.visibleColumns }
        set { tablePresentation.visibleColumns = newValue }
    }

    func togglePagedColumnAndRebuild(_ column: AnalysisColumn) {
        guard tablePresentation.toggleColumn(column) else { return }
        let mutation = AnalysisTablePresentationMutation.columnVisibility
        tablePresentationDidChange(mutation)
        rebuildScene(for: AnalysisSceneUpdatePlanner.scope(for: mutation))
    }

    func goToPreviousPagedPage(canGoBackward: Bool) {
        guard tablePresentation.goToPreviousPage(canGoBackward: canGoBackward) else { return }
        let mutation = AnalysisTablePresentationMutation.pageNavigation
        tablePresentationDidChange(mutation)
        rebuildScene(for: AnalysisSceneUpdatePlanner.scope(for: mutation))
    }

    func goToNextPagedPage(canGoForward: Bool) {
        guard tablePresentation.goToNextPage(canGoForward: canGoForward) else { return }
        let mutation = AnalysisTablePresentationMutation.pageNavigation
        tablePresentationDidChange(mutation)
        rebuildScene(for: AnalysisSceneUpdatePlanner.scope(for: mutation))
    }

    func resetPagedToFirstPageAndRebuild() {
        tablePresentation.resetToFirstPage()
        let mutation = AnalysisTablePresentationMutation.pageReset
        tablePresentationDidChange(mutation)
        rebuildScene(for: AnalysisSceneUpdatePlanner.scope(for: mutation))
    }
}

@MainActor
extension AnalysisPagedPresentationProviding where AnalysisPageSize: InteractiveAllPageSizing {
    func applyPagedPageSizeChange(_ nextPageSize: AnalysisPageSize) {
        guard tablePresentation.applyResolvedPageSizeChange(
            nextPageSize,
            totalRows: currentResultRowCountForPaging
        ) else { return }
        let mutation = AnalysisTablePresentationMutation.pageSize
        tablePresentationDidChange(mutation)
        rebuildScene(for: AnalysisSceneUpdatePlanner.scope(for: mutation))
    }
}

@MainActor
protocol AnalysisVersionedPagedPresentationProviding: AnalysisPagedPresentationProviding, AnalysisSceneBuildRevisionControlling {}

@MainActor
extension AnalysisVersionedPagedPresentationProviding {
    var sceneBuildRevision: Int {
        get { tablePresentation.sceneBuildRevision }
        set { tablePresentation.sceneBuildRevision = newValue }
    }
}
