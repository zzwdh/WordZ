import Foundation

extension TopicsPageViewModel {
    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        applyStateChange(rebuildScene: rebuildScene) {
            query = snapshot.searchQuery
            searchOptions = snapshot.searchOptions
            stopwordFilter = snapshot.stopwordFilter
            minTopicSize = snapshot.topicsMinTopicSize
            includeOutliers = snapshot.topicsIncludeOutliers
            if let matchedPageSize = TopicsPageSize.allCases.first(where: { "\($0.rawValue)" == snapshot.topicsPageSize || $0.title(in: .system) == snapshot.topicsPageSize }) {
                pageSize = matchedPageSize
            }
            selectedClusterID = snapshot.topicsActiveTopicID.isEmpty ? nil : snapshot.topicsActiveTopicID
        }
    }

    func apply(_ result: TopicAnalysisResult) {
        applyStateChange(rebuildScene: rebuildScene) {
            self.result = result
            currentPage = 1
            invalidateCaches()
        }
    }

    func reset() {
        resetState(cancelPendingSceneBuilds: invalidatePendingSceneBuilds) {
            query = ""
            searchOptions = .default
            stopwordFilter = .default
            minTopicSize = "2"
            includeOutliers = true
            isEditingStopwords = false
            result = nil
            selectedClusterID = nil
            sortMode = .relevanceDescending
            pageSize = .fifty
            currentPage = 1
            visibleColumns = Self.defaultVisibleColumns
            invalidateCaches()
            scene = nil
        }
    }
}
