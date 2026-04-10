import Foundation

struct TopicsSceneBuilder {
    @MainActor
    func build(
        from result: TopicAnalysisResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        minTopicSize: Int,
        includeOutliers: Bool,
        selectedClusterID: String?,
        sortMode: TopicSegmentSortMode,
        pageSize: TopicsPageSize,
        currentPage: Int,
        visibleColumns: Set<TopicsColumnKey>
    ) -> TopicsSceneModel {
        build(
            from: result,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            minTopicSize: minTopicSize,
            includeOutliers: includeOutliers,
            selectedClusterID: selectedClusterID,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns,
            languageMode: WordZLocalization.shared.effectiveMode
        )
    }

    func build(
        from result: TopicAnalysisResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        minTopicSize: Int,
        includeOutliers: Bool,
        selectedClusterID: String?,
        sortMode: TopicSegmentSortMode,
        pageSize: TopicsPageSize,
        currentPage: Int,
        visibleColumns: Set<TopicsColumnKey>,
        languageMode: AppLanguageMode
    ) -> TopicsSceneModel {
        let clusterComputation = prepareClusterComputation(
            from: result,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            includeOutliers: includeOutliers,
            languageMode: languageMode
        )
        let resolvedClusterID = resolveSelectedClusterID(
            requested: selectedClusterID,
            available: clusterComputation.clusterItems.map(\.id)
        )
        let sortedSegments = sortSegments(
            resolvedClusterID.flatMap { clusterComputation.visibleSegmentsByCluster[$0] } ?? [],
            mode: sortMode
        )
        return build(
            from: result,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            minTopicSize: minTopicSize,
            includeOutliers: includeOutliers,
            selectedClusterID: selectedClusterID,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns,
            languageMode: languageMode,
            clusterComputation: clusterComputation,
            sortedSegments: sortedSegments
        )
    }

    func build(
        from result: TopicAnalysisResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        minTopicSize: Int,
        includeOutliers: Bool,
        selectedClusterID: String?,
        sortMode: TopicSegmentSortMode,
        pageSize: TopicsPageSize,
        currentPage: Int,
        visibleColumns: Set<TopicsColumnKey>,
        languageMode: AppLanguageMode,
        clusterComputation: TopicsClusterComputation,
        sortedSegments: [TopicSegmentRow]
    ) -> TopicsSceneModel {
        guard clusterComputation.searchError.isEmpty else {
            return emptyScene(
                from: result,
                query: query,
                searchOptions: searchOptions,
                stopwordFilter: stopwordFilter,
                minTopicSize: minTopicSize,
                includeOutliers: includeOutliers,
                sortMode: sortMode,
                pageSize: pageSize,
                languageMode: languageMode,
                visibleColumns: visibleColumns,
                searchError: clusterComputation.searchError
            )
        }

        let resolvedClusterID = resolveSelectedClusterID(
            requested: selectedClusterID,
            available: clusterComputation.clusterItems.map(\.id)
        )
        let selectedClusterSummary = resolvedClusterID.flatMap { result.cluster(for: $0) }
        let selectedClusterSegments = resolvedClusterID.flatMap { clusterComputation.visibleSegmentsByCluster[$0] } ?? []
        let pagination = buildPagination(
            totalRows: sortedSegments.count,
            currentPage: currentPage,
            pageSize: pageSize,
            languageMode: languageMode
        )
        let pageSegments = sliceRows(sortedSegments, currentPage: pagination.currentPage, pageSize: pageSize)
        let tableRows = buildTableRows(from: pageSegments)
        let selectedCluster = selectedClusterSummary.map {
            buildSelectedCluster(
                cluster: $0,
                selectedClusterSegments: selectedClusterSegments,
                totalSegments: clusterComputation.totalSegmentsByCluster[$0.id] ?? 0,
                summaryTerms: clusterComputation.summaryTermsByCluster[$0.id] ?? [],
                representativeSegments: clusterComputation.representativeSegmentsByCluster[$0.id] ?? [],
                languageMode: languageMode
            )
        }
        let summaryRows = buildSummaryRows(from: clusterComputation.clusterItems, languageMode: languageMode)

        return TopicsSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            controls: TopicsControlsSceneModel(
                minTopicSize: minTopicSize,
                includeOutliers: includeOutliers,
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            clusters: clusterComputation.clusterItems,
            selectedClusterID: resolvedClusterID,
            selectedCluster: selectedCluster,
            tableRows: tableRows,
            table: makeSegmentsTable(
                languageMode: languageMode,
                visibleColumns: visibleColumns,
                sortMode: sortMode
            ),
            summaryRows: summaryRows,
            summaryTable: makeSummaryTable(languageMode: languageMode),
            pagination: pagination,
            totalClusters: result.clusters.count,
            visibleClusters: clusterComputation.clusterItems.count,
            totalSegments: result.totalSegments,
            visibleSegments: selectedClusterSegments.count,
            clusteredSegments: result.clusteredSegments,
            outlierCount: result.outlierCount,
            modelProvider: result.modelProvider,
            modelVersion: result.modelVersion,
            usesFallbackProvider: result.usesFallbackProvider,
            searchError: ""
        )
    }
}
