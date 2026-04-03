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
        let languageMode = WordZLocalization.shared.effectiveMode
        let matcher = SearchTextMatcher(query: query, options: searchOptions)
        guard matcher.error.isEmpty else {
            return emptyScene(
                from: result,
                query: query,
                searchOptions: searchOptions,
                stopwordFilter: stopwordFilter,
                minTopicSize: minTopicSize,
                includeOutliers: includeOutliers,
                sortMode: sortMode,
                pageSize: pageSize,
                languageMode: languageMode
            )
        }

        let eligibleClusters = result.clusters.filter { includeOutliers || !$0.isOutlier }
        let clusterItems = eligibleClusters.map { cluster in
            let visibleSegments = filteredSegments(
                for: cluster.id,
                in: result,
                matcher: matcher,
                stopwordFilter: stopwordFilter
            )
            let preview = result.representativeSegments(for: cluster.id).first?.text ?? ""
            let summaryTerms = TopicFilterSupport.summaryTerms(
                from: cluster.keywordCandidates,
                filter: stopwordFilter,
                limit: 5
            )
            return TopicClusterSceneItem(
                id: cluster.id,
                title: clusterTitle(for: cluster, mode: languageMode),
                keywordsText: summaryTerms.isEmpty
                    ? wordZText("暂无关键词", "No keywords yet", mode: languageMode)
                    : summaryTerms.map(\.term).joined(separator: " · "),
                sizeText: "\(wordZText("片段", "Segments", mode: languageMode)) \(cluster.size)",
                isOutlier: cluster.isOutlier,
                representativePreview: preview,
                visibleSegments: visibleSegments.count
            )
        }

        let resolvedClusterID = resolveSelectedClusterID(
            requested: selectedClusterID,
            available: clusterItems.map(\.id)
        )
        let selectedClusterSummary = resolvedClusterID.flatMap { result.cluster(for: $0) }
        let selectedClusterSegments = resolvedClusterID.map {
            filteredSegments(for: $0, in: result, matcher: matcher, stopwordFilter: stopwordFilter)
        } ?? []
        let sortedSegments = sortSegments(selectedClusterSegments, mode: sortMode)
        let pagination = buildPagination(
            totalRows: sortedSegments.count,
            currentPage: currentPage,
            pageSize: pageSize,
            languageMode: languageMode
        )
        let pageSegments = sliceRows(sortedSegments, currentPage: pagination.currentPage, pageSize: pageSize)
        let tableRows = pageSegments.map { segment in
            NativeTableRowDescriptor(
                id: segment.id,
                values: [
                    TopicsColumnKey.paragraph.rawValue: "\(segment.paragraphIndex)",
                    TopicsColumnKey.score.rawValue: String(format: "%.3f", segment.similarityScore),
                    TopicsColumnKey.excerpt.rawValue: segment.text
                ]
            )
        }

        let selectedCluster = selectedClusterSummary.map { cluster in
            TopicsSelectedClusterSceneModel(
                id: cluster.id,
                title: clusterTitle(for: cluster, mode: languageMode),
                summary: clusterSummaryText(
                    cluster: cluster,
                    visibleSegments: selectedClusterSegments.count,
                    totalSegments: result.segments.filter { $0.topicID == cluster.id }.count,
                    mode: languageMode
                ),
                keywords: TopicFilterSupport.summaryTerms(
                    from: cluster.keywordCandidates,
                    filter: stopwordFilter,
                    limit: 8
                ).map {
                    TopicKeywordSceneItem(
                        id: $0.term,
                        term: $0.term,
                        scoreText: String(format: "%.3f", $0.score)
                    )
                },
                representativeSegments: result.representativeSegments(for: cluster.id).map(\.text),
                isOutlier: cluster.isOutlier
            )
        }

        let summaryRows = clusterItems.map { item in
            NativeTableRowDescriptor(
                id: item.id,
                values: [
                    "topic": item.title,
                    "size": item.sizeText,
                    "keywords": item.keywordsText,
                    "type": item.isOutlier
                        ? wordZText("离群", "Outlier", mode: languageMode)
                        : wordZText("主题", "Topic", mode: languageMode)
                ]
            )
        }

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
            clusters: clusterItems,
            selectedClusterID: resolvedClusterID,
            selectedCluster: selectedCluster,
            tableRows: tableRows,
            table: NativeTableDescriptor(
                storageKey: "topics-segments",
                columns: TopicsColumnKey.allCases.map { key in
                    NativeTableColumnDescriptor(
                        id: key.rawValue,
                        title: key.title(in: languageMode),
                        isVisible: visibleColumns.contains(key),
                        sortIndicator: sortIndicator(for: key, sortMode: sortMode),
                        presentation: presentation(for: key),
                        widthPolicy: widthPolicy(for: key),
                        isPinned: key == .paragraph
                    )
                },
                defaultDensity: .reading
            ),
            summaryRows: summaryRows,
            summaryTable: NativeTableDescriptor(
                storageKey: "topics-summary",
                columns: [
                    NativeTableColumnDescriptor(id: "topic", title: wordZText("主题", "Topic", mode: languageMode), isVisible: true, sortIndicator: nil, presentation: .keyword, widthPolicy: .keyword, isPinned: true),
                    NativeTableColumnDescriptor(id: "size", title: wordZText("规模", "Size", mode: languageMode), isVisible: true, sortIndicator: nil, presentation: .label, widthPolicy: .standard),
                    NativeTableColumnDescriptor(id: "keywords", title: wordZText("关键词", "Keywords", mode: languageMode), isVisible: true, sortIndicator: nil, presentation: .summary, widthPolicy: .summary),
                    NativeTableColumnDescriptor(id: "type", title: wordZText("类型", "Type", mode: languageMode), isVisible: true, sortIndicator: nil, presentation: .label, widthPolicy: .compact)
                ],
                defaultDensity: .standard
            ),
            pagination: pagination,
            totalClusters: result.clusters.count,
            visibleClusters: clusterItems.count,
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

    private func emptyScene(
        from result: TopicAnalysisResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        minTopicSize: Int,
        includeOutliers: Bool,
        sortMode: TopicSegmentSortMode,
        pageSize: TopicsPageSize,
        languageMode: AppLanguageMode
    ) -> TopicsSceneModel {
        TopicsSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            controls: TopicsControlsSceneModel(
                minTopicSize: minTopicSize,
                includeOutliers: includeOutliers,
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            clusters: [],
            selectedClusterID: nil,
            selectedCluster: nil,
            tableRows: [],
            table: NativeTableDescriptor(
                storageKey: "topics-segments",
                columns: TopicsColumnKey.allCases.map {
                    NativeTableColumnDescriptor(
                        id: $0.rawValue,
                        title: $0.title(in: languageMode),
                        isVisible: true,
                        sortIndicator: nil,
                        presentation: presentation(for: $0),
                        widthPolicy: widthPolicy(for: $0),
                        isPinned: $0 == .paragraph
                    )
                },
                defaultDensity: .reading
            ),
            summaryRows: [],
            summaryTable: NativeTableDescriptor(
                storageKey: "topics-summary",
                columns: [
                    NativeTableColumnDescriptor(id: "topic", title: wordZText("主题", "Topic", mode: languageMode), isVisible: true, sortIndicator: nil, presentation: .keyword, widthPolicy: .keyword, isPinned: true)
                ],
                defaultDensity: .standard
            ),
            pagination: .singlePage,
            totalClusters: result.clusters.count,
            visibleClusters: 0,
            totalSegments: result.totalSegments,
            visibleSegments: 0,
            clusteredSegments: result.clusteredSegments,
            outlierCount: result.outlierCount,
            modelProvider: result.modelProvider,
            modelVersion: result.modelVersion,
            usesFallbackProvider: result.usesFallbackProvider,
            searchError: SearchTextMatcher(query: query, options: searchOptions).error
        )
    }

    private func presentation(for key: TopicsColumnKey) -> NativeTableColumnPresentation {
        switch key {
        case .paragraph:
            return .numeric(precision: 0)
        case .score:
            return .numeric(precision: 3)
        case .excerpt:
            return .summary
        }
    }

    private func widthPolicy(for key: TopicsColumnKey) -> NativeTableColumnWidthPolicy {
        switch key {
        case .paragraph:
            return .compact
        case .score:
            return .numeric
        case .excerpt:
            return .summary
        }
    }

    private func filteredSegments(
        for clusterID: String,
        in result: TopicAnalysisResult,
        matcher: SearchTextMatcher,
        stopwordFilter: StopwordFilterState
    ) -> [TopicSegmentRow] {
        guard matcher.error.isEmpty else { return [] }
        let cluster = result.cluster(for: clusterID)
        let keywords = cluster.map { TopicFilterSupport.summaryTerms(from: $0.keywordCandidates, filter: stopwordFilter, limit: 8).map(\.term) } ?? []
        return result.segments.filter { segment in
            guard segment.topicID == clusterID else { return false }
            return TopicFilterSupport.matchesSegment(
                text: segment.text,
                query: matcher.normalizedQuery,
                options: matcher.options,
                stopword: stopwordFilter,
                keywords: keywords
            ).matches
        }
    }

    private func sortSegments(_ rows: [TopicSegmentRow], mode: TopicSegmentSortMode) -> [TopicSegmentRow] {
        switch mode {
        case .relevanceDescending:
            return rows.sorted {
                if $0.similarityScore == $1.similarityScore {
                    return $0.paragraphIndex < $1.paragraphIndex
                }
                return $0.similarityScore > $1.similarityScore
            }
        case .relevanceAscending:
            return rows.sorted {
                if $0.similarityScore == $1.similarityScore {
                    return $0.paragraphIndex < $1.paragraphIndex
                }
                return $0.similarityScore < $1.similarityScore
            }
        case .paragraphAscending:
            return rows.sorted { $0.paragraphIndex < $1.paragraphIndex }
        case .paragraphDescending:
            return rows.sorted { $0.paragraphIndex > $1.paragraphIndex }
        case .alphabeticalAscending:
            return rows.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedAscending }
        case .alphabeticalDescending:
            return rows.sorted { $0.text.localizedCaseInsensitiveCompare($1.text) == .orderedDescending }
        }
    }

    private func buildPagination(
        totalRows: Int,
        currentPage: Int,
        pageSize: TopicsPageSize,
        languageMode: AppLanguageMode
    ) -> ResultPaginationSceneModel {
        guard totalRows > 0 else {
            return ResultPaginationSceneModel(
                currentPage: 1,
                totalPages: 1,
                pageSizeLabel: pageSize.title(in: languageMode),
                rangeLabel: "0 / 0",
                canGoBackward: false,
                canGoForward: false
            )
        }

        let totalPages: Int
        if let rowLimit = pageSize.rowLimit {
            totalPages = max(1, Int(ceil(Double(totalRows) / Double(rowLimit))))
        } else {
            totalPages = 1
        }

        let safePage = min(max(currentPage, 1), totalPages)
        let rangeLabel: String
        if let rowLimit = pageSize.rowLimit {
            let startIndex = ((safePage - 1) * rowLimit) + 1
            let endIndex = min(safePage * rowLimit, totalRows)
            rangeLabel = "\(startIndex)-\(endIndex) / \(totalRows)"
        } else {
            rangeLabel = "1-\(totalRows) / \(totalRows)"
        }

        return ResultPaginationSceneModel(
            currentPage: safePage,
            totalPages: totalPages,
            pageSizeLabel: pageSize.title(in: languageMode),
            rangeLabel: rangeLabel,
            canGoBackward: safePage > 1,
            canGoForward: safePage < totalPages
        )
    }

    private func sliceRows(
        _ rows: [TopicSegmentRow],
        currentPage: Int,
        pageSize: TopicsPageSize
    ) -> [TopicSegmentRow] {
        guard let rowLimit = pageSize.rowLimit else { return rows }
        let startIndex = max(0, (currentPage - 1) * rowLimit)
        guard startIndex < rows.count else { return [] }
        let endIndex = min(startIndex + rowLimit, rows.count)
        return Array(rows[startIndex..<endIndex])
    }

    private func sortIndicator(for key: TopicsColumnKey, sortMode: TopicSegmentSortMode) -> String? {
        switch (key, sortMode) {
        case (.paragraph, .paragraphAscending):
            return "↑"
        case (.paragraph, .paragraphDescending):
            return "↓"
        case (.score, .relevanceAscending):
            return "↑"
        case (.score, .relevanceDescending):
            return "↓"
        case (.excerpt, .alphabeticalAscending):
            return "↑"
        case (.excerpt, .alphabeticalDescending):
            return "↓"
        default:
            return nil
        }
    }

    private func resolveSelectedClusterID(requested: String?, available: [String]) -> String? {
        if let requested, available.contains(requested) {
            return requested
        }
        return available.first
    }

    private func clusterTitle(for cluster: TopicClusterSummary, mode: AppLanguageMode) -> String {
        if cluster.isOutlier {
            return wordZText("离群片段", "Outliers", mode: mode)
        }
        return "\(wordZText("主题", "Topic", mode: mode)) \(cluster.index)"
    }

    private func clusterSummaryText(
        cluster: TopicClusterSummary,
        visibleSegments: Int,
        totalSegments: Int,
        mode: AppLanguageMode
    ) -> String {
        let visibleText = "\(wordZText("显示", "Showing", mode: mode)) \(visibleSegments) / \(totalSegments)"
        let sizeText = "\(wordZText("规模", "Size", mode: mode)) \(cluster.size)"
        return "\(sizeText) · \(visibleText)"
    }
}
