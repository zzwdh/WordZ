import Foundation

extension TopicsPageViewModel {
    func handleInputChange(rebuildScene shouldRebuildScene: Bool) {
        propagateInputChange(rebuildScene: shouldRebuildScene) {
            rebuildScene()
        }
    }

    func rebuildScene() {
        guard let result else {
            scene = nil
            return
        }
        let revision = beginSceneBuildPass()
        let querySnapshot = normalizedQuery
        let searchOptionsSnapshot = searchOptions
        let stopwordSnapshot = stopwordFilter
        let minTopicSizeSnapshot = minTopicSizeValue
        let includeOutliersSnapshot = includeOutliers
        let selectedClusterIDSnapshot = selectedClusterID
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode
        let rowCount = result.totalSegments

        guard rowCount >= LargeResultSceneBuildSupport.asyncThreshold else {
            let clusterComputation = resolvedClusterComputation(
                for: result,
                languageMode: languageModeSnapshot
            )
            let resolvedClusterID = sceneBuilder.resolveSelectedClusterID(
                requested: selectedClusterIDSnapshot,
                available: clusterComputation.clusterItems.map(\.id)
            )
            let sortedSegments = resolvedSortedSegments(
                clusterID: resolvedClusterID,
                visibleSegmentsByCluster: clusterComputation.visibleSegmentsByCluster
            )
            scene = AnalysisPerformanceTelemetry.measureSceneBuild(
                context: .init(page: "topics", rowCount: rowCount, revision: revision, isAsync: false)
            ) {
                sceneBuilder.build(
                    from: result,
                    query: querySnapshot,
                    searchOptions: searchOptionsSnapshot,
                    stopwordFilter: stopwordSnapshot,
                    minTopicSize: minTopicSizeSnapshot,
                    includeOutliers: includeOutliersSnapshot,
                    selectedClusterID: selectedClusterIDSnapshot,
                    sortMode: sortSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    languageMode: languageModeSnapshot,
                    clusterComputation: clusterComputation,
                    sortedSegments: sortedSegments
                )
            }
            currentPage = scene?.pagination.currentPage ?? 1
            selectedClusterID = scene?.selectedClusterID
            return
        }

        let resultSnapshot = result

        AnalysisSceneBuildScheduling.schedule(
            context: .init(page: "topics", rowCount: rowCount, revision: revision, isAsync: true),
            build: { [sceneBuilder] in
                let clusterComputation = sceneBuilder.prepareClusterComputation(
                    from: resultSnapshot,
                    query: querySnapshot,
                    searchOptions: searchOptionsSnapshot,
                    stopwordFilter: stopwordSnapshot,
                    includeOutliers: includeOutliersSnapshot,
                    languageMode: languageModeSnapshot
                )
                let resolvedClusterID = sceneBuilder.resolveSelectedClusterID(
                    requested: selectedClusterIDSnapshot,
                    available: clusterComputation.clusterItems.map(\.id)
                )
                let sortedSegments = sceneBuilder.sortSegments(
                    resolvedClusterID.flatMap { clusterComputation.visibleSegmentsByCluster[$0] } ?? [],
                    mode: sortSnapshot
                )
                let nextScene = sceneBuilder.build(
                    from: resultSnapshot,
                    query: querySnapshot,
                    searchOptions: searchOptionsSnapshot,
                    stopwordFilter: stopwordSnapshot,
                    minTopicSize: minTopicSizeSnapshot,
                    includeOutliers: includeOutliersSnapshot,
                    selectedClusterID: selectedClusterIDSnapshot,
                    sortMode: sortSnapshot,
                    pageSize: pageSizeSnapshot,
                    currentPage: currentPageSnapshot,
                    visibleColumns: visibleColumnsSnapshot,
                    languageMode: languageModeSnapshot,
                    clusterComputation: clusterComputation,
                    sortedSegments: sortedSegments
                )
                return (clusterComputation, resolvedClusterID, sortedSegments, nextScene)
            },
            apply: { payload in
                let (clusterComputation, resolvedClusterID, sortedSegments, nextScene) = payload
                guard self.isCurrentSceneBuild(revision) else { return false }
                self.cachedClusterComputation = clusterComputation
                self.cachedClusterQuery = querySnapshot
                self.cachedClusterOptions = searchOptionsSnapshot
                self.cachedClusterStopwordFilter = stopwordSnapshot
                self.cachedIncludeOutliers = includeOutliersSnapshot
                self.cachedClusterLanguageMode = languageModeSnapshot
                self.cachedSortedSegments = sortedSegments
                self.cachedSortedClusterID = resolvedClusterID ?? ""
                self.cachedSortMode = sortSnapshot
                self.scene = nextScene
                self.currentPage = nextScene.pagination.currentPage
                self.selectedClusterID = nextScene.selectedClusterID
                return true
            }
        )
    }
}
