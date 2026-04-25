import Foundation

extension TopicsPageViewModel {
    func resolvedClusterComputation(
        for result: TopicAnalysisResult,
        languageMode: AppLanguageMode
    ) -> TopicsClusterComputation {
        let normalizedQuery = normalizedQuery
        if let cachedClusterComputation,
           cachedClusterQuery == normalizedQuery,
           cachedClusterOptions == searchOptions,
           cachedClusterStopwordFilter == stopwordFilter,
           cachedIncludeOutliers == includeOutliers,
           cachedKeywordDisplayCount == keywordDisplayCountValue,
           cachedCompareDrilldownContext == compareDrilldownContext,
           cachedClusterLanguageMode == languageMode {
            return cachedClusterComputation
        }
        let clusterComputation = sceneBuilder.prepareClusterComputation(
            from: result,
            query: normalizedQuery,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            includeOutliers: includeOutliers,
            keywordDisplayCount: keywordDisplayCountValue,
            compareDrilldownContext: compareDrilldownContext,
            languageMode: languageMode
        )
        cachedClusterComputation = clusterComputation
        cachedClusterQuery = normalizedQuery
        cachedClusterOptions = searchOptions
        cachedClusterStopwordFilter = stopwordFilter
        cachedIncludeOutliers = includeOutliers
        cachedKeywordDisplayCount = keywordDisplayCountValue
        cachedCompareDrilldownContext = compareDrilldownContext
        cachedClusterLanguageMode = languageMode
        invalidateSortedSegmentsCache()
        return clusterComputation
    }

    func resolvedSortedSegments(
        clusterID: String?,
        visibleSegmentsByCluster: [String: [TopicSegmentRow]]
    ) -> [TopicSegmentRow] {
        let clusterKey = clusterID ?? ""
        if let cachedSortedSegments,
           cachedSortedClusterID == clusterKey,
           cachedSortMode == sortMode {
            return cachedSortedSegments
        }
        let sortedSegments = sceneBuilder.sortSegments(
            clusterID.flatMap { visibleSegmentsByCluster[$0] } ?? [],
            mode: sortMode
        )
        cachedSortedSegments = sortedSegments
        cachedSortedClusterID = clusterKey
        cachedSortMode = sortMode
        return sortedSegments
    }

    func invalidateCaches() {
        cachedClusterComputation = nil
        cachedClusterQuery = ""
        cachedClusterOptions = .default
        cachedClusterStopwordFilter = .default
        cachedIncludeOutliers = true
        cachedKeywordDisplayCount = 5
        cachedCompareDrilldownContext = nil
        cachedClusterLanguageMode = nil
        invalidateSortedSegmentsCache()
    }

    func invalidateSortedSegmentsCache() {
        cachedSortedSegments = nil
        cachedSortedClusterID = nil
        cachedSortMode = nil
    }
}
