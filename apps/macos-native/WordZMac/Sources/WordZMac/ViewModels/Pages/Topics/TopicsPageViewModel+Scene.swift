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
        let keywordDisplayCountSnapshot = keywordDisplayCountValue
        let includeOutliersSnapshot = includeOutliers
        let selectedClusterIDSnapshot = selectedClusterID
        let selectedRowIDSnapshot = selectedRowID
        let sortSnapshot = sortMode
        let pageSizeSnapshot = pageSize
        let currentPageSnapshot = currentPage
        let visibleColumnsSnapshot = visibleColumns
        let languageModeSnapshot = WordZLocalization.shared.effectiveMode
        let annotationStateSnapshot = annotationState
        let compareDrilldownContextSnapshot = compareDrilldownContext
        let sentimentExplainerSnapshot = sentimentExplainer
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
                    annotationState: annotationStateSnapshot,
                    compareDrilldownContext: compareDrilldownContextSnapshot,
                    sentimentExplainer: sentimentExplainerSnapshot,
                    minTopicSize: minTopicSizeSnapshot,
                    keywordDisplayCount: keywordDisplayCountSnapshot,
                    includeOutliers: includeOutliersSnapshot,
                    selectedClusterID: selectedClusterIDSnapshot,
                    selectedRowID: selectedRowIDSnapshot,
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
            selectedRowID = scene?.selectedSegmentID
            return
        }

        let resultSnapshot = result

        AnalysisSceneBuildScheduling.schedule(
            owner: self,
            context: .init(page: "topics", rowCount: rowCount, revision: revision, isAsync: true),
            build: { [sceneBuilder] in
                try Task.checkCancellation()
                let clusterComputation = sceneBuilder.prepareClusterComputation(
                    from: resultSnapshot,
                    query: querySnapshot,
                    searchOptions: searchOptionsSnapshot,
                    stopwordFilter: stopwordSnapshot,
                    includeOutliers: includeOutliersSnapshot,
                    keywordDisplayCount: keywordDisplayCountSnapshot,
                    compareDrilldownContext: compareDrilldownContextSnapshot,
                    languageMode: languageModeSnapshot
                )
                try Task.checkCancellation()
                let resolvedClusterID = sceneBuilder.resolveSelectedClusterID(
                    requested: selectedClusterIDSnapshot,
                    available: clusterComputation.clusterItems.map(\.id)
                )
                try Task.checkCancellation()
                let sortedSegments = sceneBuilder.sortSegments(
                    resolvedClusterID.flatMap { clusterComputation.visibleSegmentsByCluster[$0] } ?? [],
                    mode: sortSnapshot
                )
                try Task.checkCancellation()
                let nextScene = sceneBuilder.build(
                    from: resultSnapshot,
                    query: querySnapshot,
                    searchOptions: searchOptionsSnapshot,
                    stopwordFilter: stopwordSnapshot,
                    annotationState: annotationStateSnapshot,
                    compareDrilldownContext: compareDrilldownContextSnapshot,
                    sentimentExplainer: sentimentExplainerSnapshot,
                    minTopicSize: minTopicSizeSnapshot,
                    keywordDisplayCount: keywordDisplayCountSnapshot,
                    includeOutliers: includeOutliersSnapshot,
                    selectedClusterID: selectedClusterIDSnapshot,
                    selectedRowID: selectedRowIDSnapshot,
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
                self.cachedKeywordDisplayCount = keywordDisplayCountSnapshot
                self.cachedClusterLanguageMode = languageModeSnapshot
                self.cachedSortedSegments = sortedSegments
                self.cachedSortedClusterID = resolvedClusterID ?? ""
                self.cachedSortMode = sortSnapshot
                self.scene = nextScene
                self.currentPage = nextScene.pagination.currentPage
                self.selectedClusterID = nextScene.selectedClusterID
                self.selectedRowID = nextScene.selectedSegmentID
                return true
            }
        )
    }
}
