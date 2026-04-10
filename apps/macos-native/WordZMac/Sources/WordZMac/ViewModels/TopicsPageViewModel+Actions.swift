import Foundation

extension TopicsPageViewModel {
    var currentResultRowCountForPaging: Int? {
        scene?.totalSegments ?? result?.segments.count
    }

    func handle(_ action: TopicsPageAction) {
        switch action {
        case .run, .exportSummary, .exportSegments:
            return
        case .selectCluster(let clusterID):
            selectedClusterID = clusterID
            resetToFirstPageAndRebuild()
        case .changeSort(let nextSort):
            applySortModeChange(nextSort)
        case .sortByColumn(let column):
            sortByColumn(column)
        case .changePageSize(let nextPageSize):
            applyPageSizeChange(nextPageSize)
        case .toggleColumn(let column):
            toggleColumn(column)
        case .previousPage:
            goToPreviousPage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextPage(canGoForward: scene?.pagination.canGoForward == true)
        }
    }

    func toggleColumn(_ column: TopicsColumnKey) {
        toggleVisibleColumnAndRebuild(column)
    }

    func sortByColumn(_ column: TopicsColumnKey) {
        let nextSort: TopicSegmentSortMode
        switch column {
        case .paragraph:
            nextSort = sortMode == .paragraphAscending ? .paragraphDescending : .paragraphAscending
        case .score:
            nextSort = sortMode == .relevanceDescending ? .relevanceAscending : .relevanceDescending
        case .excerpt:
            nextSort = sortMode == .alphabeticalAscending ? .alphabeticalDescending : .alphabeticalAscending
        }
        applySortModeChange(nextSort)
    }
}
