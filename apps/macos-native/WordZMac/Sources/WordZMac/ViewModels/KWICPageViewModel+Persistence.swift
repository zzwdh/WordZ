import Foundation

extension KWICPageViewModel {
    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        applyStateChange(rebuildScene: rebuildScene) {
            keyword = snapshot.searchQuery
            leftWindow = snapshot.kwicLeftWindow
            rightWindow = snapshot.kwicRightWindow
            searchOptions = snapshot.searchOptions
            stopwordFilter = snapshot.stopwordFilter
        }
    }

    func apply(_ result: KWICResult) {
        applyStateChange(rebuildScene: rebuildScene) {
            self.result = result
            currentPage = 1
            invalidateCaches()
        }
    }

    func reset() {
        resetState {
            keyword = ""
            leftWindow = "5"
            rightWindow = "5"
            searchOptions = .default
            stopwordFilter = .default
            isEditingStopwords = false
            result = nil
            sortMode = .original
            pageSize = .fifty
            currentPage = 1
            visibleColumns = Self.defaultVisibleColumns
            selectedRowID = nil
            invalidateCaches()
            scene = nil
        }
    }
}
