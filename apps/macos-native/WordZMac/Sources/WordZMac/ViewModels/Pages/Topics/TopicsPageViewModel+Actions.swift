import Foundation

extension TopicsPageViewModel {
    var currentResultRowCountForPaging: Int? {
        scene?.totalSegments ?? result?.segments.count
    }

    var crossAnalysisSummary: String? {
        compareDrilldownContext?.summaryLine(in: WordZLocalization.shared.effectiveMode)
    }

    var canAnalyzeVisibleTopicsInSentiment: Bool {
        guard let result else { return false }
        return !visibleTopicSegmentsForSentiment(from: result).isEmpty
    }

    var canAnalyzeSelectedTopicInSentiment: Bool {
        guard let result,
              let selectedClusterID
        else { return false }
        return !visibleTopicSegmentsForSentiment(from: result, focusedClusterID: selectedClusterID).isEmpty
    }

    var canOpenSelectedTopicInKWIC: Bool {
        guard let result,
              let selectedClusterID,
              kwicDrilldownKeyword() != nil
        else { return false }
        return !visibleTopicSegmentsForSentiment(from: result, focusedClusterID: selectedClusterID).isEmpty
    }

    func handle(_ action: TopicsPageAction) {
        switch action {
        case .run, .activateRow, .openSourceReader, .openKWIC, .openSentiment, .openSentimentExemplar, .openSentimentSourceReader, .exportSummary, .exportSegments:
            return
        case .selectCluster(let clusterID):
            selectedClusterID = clusterID
            selectedRowID = nil
            resetTableToFirstPageAndRebuild()
        case .selectRow(let rowID):
            selectedRowID = rowID
        case .changeSort(let nextSort):
            applyTableSortModeChange(nextSort)
        case .sortByColumn(let column):
            sortTableByColumn(column)
        case .changePageSize(let nextPageSize):
            applyTablePageSizeChange(nextPageSize)
        case .toggleColumn(let column):
            toggleTableColumnAndRebuild(column)
        case .previousPage:
            goToPreviousTablePage(canGoBackward: scene?.pagination.canGoBackward == true)
        case .nextPage:
            goToNextTablePage(canGoForward: scene?.pagination.canGoForward == true)
        }
    }

    func tablePresentationDidChange(_ mutation: AnalysisTablePresentationMutation) {
        guard mutation == .sort || mutation == .pageReset else { return }
        invalidateSortedSegmentsCache()
    }

    func nextSortMode(
        for column: TopicsColumnKey,
        currentSortMode: TopicSegmentSortMode
    ) -> TopicSegmentSortMode? {
        switch column {
        case .paragraph:
            return currentSortMode == .paragraphAscending ? .paragraphDescending : .paragraphAscending
        case .score:
            return currentSortMode == .relevanceDescending ? .relevanceAscending : .relevanceDescending
        case .excerpt:
            return currentSortMode == .alphabeticalAscending ? .alphabeticalDescending : .alphabeticalAscending
        }
    }

    func visibleTopicSegmentsForSentiment(
        from result: TopicAnalysisResult,
        focusedClusterID: String? = nil
    ) -> [TopicSegmentRow] {
        let languageMode = WordZLocalization.shared.effectiveMode
        let clusterComputation = resolvedClusterComputation(for: result, languageMode: languageMode)
        let clusterIDs: [String]
        if let focusedClusterID,
           clusterComputation.clusterItems.contains(where: { $0.id == focusedClusterID }) {
            clusterIDs = [focusedClusterID]
        } else {
            clusterIDs = clusterComputation.clusterItems.map(\.id)
        }

        var visibleSegments: [TopicSegmentRow] = []
        for clusterID in clusterIDs {
            visibleSegments.append(contentsOf: clusterComputation.visibleSegmentsByCluster[clusterID] ?? [])
        }
        if !visibleSegments.isEmpty {
            return visibleSegments
        }

        let hasActiveVisibilityFilters = !normalizedQuery.isEmpty || stopwordFilter.enabled
        guard !hasActiveVisibilityFilters else { return [] }

        let eligibleClusterIDs = Set(clusterIDs)
        return result.segments.filter { segment in
            eligibleClusterIDs.contains(segment.topicID) && (includeOutliers || !segment.isOutlier)
        }
    }

    func kwicDrilldownKeyword() -> String? {
        let trimmedQuery = normalizedQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            return trimmedQuery
        }

        if let keyword = scene?.selectedCluster?.keywords.first?.term {
            let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedKeyword.isEmpty {
                return trimmedKeyword
            }
        }

        return nil
    }

    func kwicDrilldownRow(from result: TopicAnalysisResult) -> TopicSegmentRow? {
        if let selectedSceneRow {
            return selectedSceneRow
        }
        guard let selectedClusterID else { return nil }
        return visibleTopicSegmentsForSentiment(
            from: result,
            focusedClusterID: selectedClusterID
        )
        .first
    }
}
