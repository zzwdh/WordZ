import Foundation

extension CollocatePageViewModel {
    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        isApplyingState = true
        defer {
            isApplyingState = false
            rebuildScene()
        }
        keyword = snapshot.searchQuery
        leftWindow = snapshot.collocateLeftWindow
        rightWindow = snapshot.collocateRightWindow
        minFreq = snapshot.collocateMinFreq
        searchOptions = snapshot.searchOptions
        stopwordFilter = snapshot.stopwordFilter
    }

    func apply(_ result: CollocateResult) {
        self.result = result
        currentPage = 1
        invalidateCaches()
        rebuildScene()
    }

    func recordPendingRunConfiguration() {
        lastRunConfiguration = currentRunConfiguration
    }

    func reset() {
        isApplyingState = true
        defer { isApplyingState = false }
        keyword = ""
        leftWindow = "5"
        rightWindow = "5"
        minFreq = "1"
        searchOptions = .default
        stopwordFilter = .default
        isEditingStopwords = false
        result = nil
        sortMode = .logDiceDescending
        pageSize = .fifty
        currentPage = 1
        visibleColumns = Self.defaultVisibleColumns
        focusMetric = .logDice
        selectedRowID = nil
        lastRunConfiguration = nil
        invalidateCaches()
        scene = nil
    }
}
