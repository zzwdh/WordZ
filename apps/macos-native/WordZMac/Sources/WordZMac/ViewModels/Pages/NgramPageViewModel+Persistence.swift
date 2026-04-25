import Foundation

extension NgramPageViewModel {
    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        isApplyingState = true
        defer {
            isApplyingState = false
            rebuildScene()
        }
        query = snapshot.searchQuery
        searchOptions = snapshot.searchOptions
        stopwordFilter = snapshot.stopwordFilter
        ngramSize = snapshot.ngramSize
        if let matchedPageSize = NgramPageSize.allCases.first(where: { $0.title == snapshot.ngramPageSize }) {
            pageSize = matchedPageSize
        }
    }

    func apply(_ result: NgramResult) {
        isApplyingState = true
        defer {
            isApplyingState = false
            rebuildScene()
        }
        self.result = result
        ngramSize = "\(result.n)"
        currentPage = 1
        invalidateCaches()
    }

    func reset() {
        invalidatePendingSceneBuilds()
        isApplyingState = true
        defer { isApplyingState = false }
        query = ""
        searchOptions = .default
        stopwordFilter = .default
        ngramSize = "2"
        isEditingStopwords = false
        result = nil
        sortMode = .frequencyDescending
        pageSize = .oneHundred
        currentPage = 1
        visibleColumns = Self.defaultVisibleColumns
        invalidateCaches()
        scene = nil
    }
}
