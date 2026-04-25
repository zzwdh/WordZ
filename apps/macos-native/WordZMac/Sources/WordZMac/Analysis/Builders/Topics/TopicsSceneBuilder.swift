import Foundation

struct TopicsSceneBuilder {
    @MainActor
    func build(
        from result: TopicAnalysisResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        annotationState: WorkspaceAnnotationState = .default,
        compareDrilldownContext: TopicsCompareDrilldownContext? = nil,
        sentimentExplainer: TopicsSentimentExplainer? = nil,
        minTopicSize: Int,
        keywordDisplayCount: Int = 5,
        includeOutliers: Bool,
        selectedClusterID: String?,
        selectedRowID: String? = nil,
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
            annotationState: annotationState,
            compareDrilldownContext: compareDrilldownContext,
            sentimentExplainer: sentimentExplainer,
            minTopicSize: minTopicSize,
            keywordDisplayCount: keywordDisplayCount,
            includeOutliers: includeOutliers,
            selectedClusterID: selectedClusterID,
            selectedRowID: selectedRowID,
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
        annotationState: WorkspaceAnnotationState = .default,
        compareDrilldownContext: TopicsCompareDrilldownContext? = nil,
        sentimentExplainer: TopicsSentimentExplainer? = nil,
        minTopicSize: Int,
        keywordDisplayCount: Int = 5,
        includeOutliers: Bool,
        selectedClusterID: String?,
        selectedRowID: String? = nil,
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
            keywordDisplayCount: keywordDisplayCount,
            compareDrilldownContext: compareDrilldownContext,
            languageMode: languageMode
        )
        let resolvedClusterID = resolveSelectedClusterID(
            requested: selectedClusterID,
            available: clusterComputation.clusterItems.map { $0.id }
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
            annotationState: annotationState,
            compareDrilldownContext: compareDrilldownContext,
            sentimentExplainer: sentimentExplainer,
            minTopicSize: minTopicSize,
            keywordDisplayCount: keywordDisplayCount,
            includeOutliers: includeOutliers,
            selectedClusterID: selectedClusterID,
            selectedRowID: selectedRowID,
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
        annotationState: WorkspaceAnnotationState = .default,
        compareDrilldownContext: TopicsCompareDrilldownContext? = nil,
        sentimentExplainer: TopicsSentimentExplainer? = nil,
        minTopicSize: Int,
        keywordDisplayCount: Int = 5,
        includeOutliers: Bool,
        selectedClusterID: String?,
        selectedRowID: String? = nil,
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
                annotationState: annotationState,
                sentimentExplainer: sentimentExplainer,
                minTopicSize: minTopicSize,
                keywordDisplayCount: keywordDisplayCount,
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
            available: clusterComputation.clusterItems.map { $0.id }
        )
        let contrastSummariesByCluster = buildContrastSummariesByCluster(
            from: result,
            compareDrilldownContext: compareDrilldownContext,
            languageMode: languageMode
        )
        let showsContrastColumn = !contrastSummariesByCluster.isEmpty
        let selectedClusterSummary = resolvedClusterID.flatMap { result.cluster(for: $0) }
        let selectedClusterSegments = resolvedClusterID.flatMap { clusterComputation.visibleSegmentsByCluster[$0] } ?? []
        let pagination = buildPagination(
            totalRows: sortedSegments.count,
            currentPage: currentPage,
            pageSize: pageSize,
            languageMode: languageMode
        )
        let pageSegments = Array(
            sliceRows(
                sortedSegments,
                currentPage: pagination.currentPage,
                pageSize: pageSize
            )
        )
        let resolvedSelectedRowID: String?
        if let selectedRowID,
           pageSegments.contains(where: { $0.id == selectedRowID }) {
            resolvedSelectedRowID = selectedRowID
        } else {
            resolvedSelectedRowID = pageSegments.first?.id
        }
        let tableRows = buildTableRows(from: pageSegments)
        let selectedCluster = selectedClusterSummary.map {
            buildSelectedCluster(
                cluster: $0,
                selectedClusterSegments: selectedClusterSegments,
                totalSegments: clusterComputation.totalSegmentsByCluster[$0.id] ?? 0,
                summaryTerms: clusterComputation.displayTermsByCluster[$0.id] ?? [],
                representativeSegments: clusterComputation.representativeSegmentsByCluster[$0.id] ?? [],
                contrastSummary: contrastSummariesByCluster[$0.id],
                languageMode: languageMode
            )
        }
        let summaryRows = buildSummaryRows(
            from: clusterComputation.clusterItems,
            showsContrastColumn: showsContrastColumn,
            languageMode: languageMode
        )
        let crossAnalysisMetadataLines = compareDrilldownContext?.exportMetadataLines(in: languageMode) ?? []
        let summaryExportMetadataLines = exportMetadataLines(
            from: result,
            languageMode: languageMode,
            visibleRows: summaryRows.count,
            totalRows: result.clusters.count,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            annotationState: annotationState,
            keywordDisplayCount: keywordDisplayCount,
            sentimentExplainer: sentimentExplainer,
            crossAnalysisMetadataLines: crossAnalysisMetadataLines
        )
        let segmentsExportMetadataLines = exportMetadataLines(
            from: result,
            languageMode: languageMode,
            visibleRows: tableRows.count,
            totalRows: selectedClusterSegments.count,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            annotationState: annotationState,
            keywordDisplayCount: keywordDisplayCount,
            sentimentExplainer: sentimentExplainer,
            crossAnalysisMetadataLines: crossAnalysisMetadataLines
        )

        return TopicsSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            crossAnalysisSummary: compareDrilldownContext?.summaryLine(in: languageMode),
            sentimentExplainer: sentimentExplainer,
            controls: TopicsControlsSceneModel(
                minTopicSize: minTopicSize,
                keywordDisplayCount: keywordDisplayCount,
                includeOutliers: includeOutliers,
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            clusters: clusterComputation.clusterItems,
            selectedClusterID: resolvedClusterID,
            selectedCluster: selectedCluster,
            segmentRows: pageSegments,
            selectedSegmentID: resolvedSelectedRowID,
            tableRows: tableRows,
            table: makeSegmentsTable(
                languageMode: languageMode,
                visibleColumns: visibleColumns,
                sortMode: sortMode
            ),
            summaryRows: summaryRows,
            summaryTable: makeSummaryTable(
                languageMode: languageMode,
                showsContrastColumn: showsContrastColumn
            ),
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
            warnings: result.warnings,
            searchError: "",
            summaryExportMetadataLines: summaryExportMetadataLines,
            segmentsExportMetadataLines: segmentsExportMetadataLines
        )
    }
}
