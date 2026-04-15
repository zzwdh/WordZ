import Foundation

extension CollocatePageViewModel {
    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        applyStateChange(rebuildScene: rebuildScene) {
            keyword = snapshot.searchQuery
            leftWindow = snapshot.collocateLeftWindow
            rightWindow = snapshot.collocateRightWindow
            minFreq = snapshot.collocateMinFreq
            searchOptions = snapshot.searchOptions
            stopwordFilter = snapshot.stopwordFilter
        }
    }

    func apply(_ result: CollocateResult) {
        applyStateChange(rebuildScene: rebuildScene) {
            self.result = result
            currentPage = 1
            invalidateCaches()
        }
    }

    func recordPendingRunConfiguration() {
        lastRunConfiguration = currentRunConfiguration
    }

    func reset() {
        resetState(cancelPendingSceneBuilds: invalidatePendingSceneBuilds) {
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
}
