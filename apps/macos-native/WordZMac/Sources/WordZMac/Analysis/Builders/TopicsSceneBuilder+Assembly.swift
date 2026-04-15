import Foundation

struct TopicsClusterComputation: Equatable, Sendable {
    let clusterItems: [TopicClusterSceneItem]
    let visibleSegmentsByCluster: [String: [TopicSegmentRow]]
    let totalSegmentsByCluster: [String: Int]
    let representativeSegmentsByCluster: [String: [String]]
    let searchTermsByCluster: [String: [TopicKeywordCandidate]]
    let displayTermsByCluster: [String: [TopicKeywordCandidate]]
    let searchError: String
}

extension TopicsSceneBuilder {
    func exportMetadataLines(
        from result: TopicAnalysisResult,
        languageMode: AppLanguageMode,
        visibleRows: Int,
        totalRows: Int,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        keywordDisplayCount: Int
    ) -> [String] {
        var additionalLines = [
            "\(wordZText("模型来源", "Model Provider", mode: languageMode)): \(providerLabel(for: result.modelProvider, languageMode: languageMode))",
            "\(wordZText("模型版本", "Model Version", mode: languageMode)): \(result.modelVersion)",
            "\(wordZText("关键词样式", "Keyword Style", mode: languageMode)): \(wordZText("单词", "Single-word only", mode: languageMode))",
            "\(wordZText("每主题关键词数", "Keywords per Topic", mode: languageMode)): \(keywordDisplayCount)"
        ]
        additionalLines.append(
            contentsOf: result.warnings.enumerated().map { index, warning in
                "\(wordZText("结果提示", "Result Note", mode: languageMode)) \(index + 1): \(warning)"
            }
        )

        return AnalysisExportMetadataSupport.notes(
            analysisTitle: wordZText("主题", "Topics", mode: languageMode),
            languageMode: languageMode,
            visibleRows: visibleRows,
            totalRows: totalRows,
            query: query,
            queryLabel: wordZText("搜索条件", "Search Query", mode: languageMode),
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            additionalLines: additionalLines
        )
    }

    func providerLabel(for provider: String, languageMode: AppLanguageMode) -> String {
        switch provider {
        case "bundled-local-embedding", "bundled-lexical-embedding":
            return wordZText("内置主题向量", "Bundled Topic Embedding", mode: languageMode)
        case "system-sentence-embedding":
            return wordZText("系统句向量", "System Embedding", mode: languageMode)
        case "hashed-fallback":
            return wordZText("稳定兜底", "Stable Fallback", mode: languageMode)
        default:
            return provider
        }
    }

    func prepareClusterComputation(
        from result: TopicAnalysisResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        includeOutliers: Bool,
        keywordDisplayCount: Int,
        languageMode: AppLanguageMode
    ) -> TopicsClusterComputation {
        let matcher = SearchTextMatcher(query: query, options: searchOptions)
        guard matcher.error.isEmpty else {
            return TopicsClusterComputation(
                clusterItems: [],
                visibleSegmentsByCluster: [:],
                totalSegmentsByCluster: [:],
                representativeSegmentsByCluster: [:],
                searchTermsByCluster: [:],
                displayTermsByCluster: [:],
                searchError: matcher.error
            )
        }

        let searchTermsByCluster = Dictionary(uniqueKeysWithValues: result.clusters.map { cluster in
            (
                cluster.id,
                TopicFilterSupport.summaryTerms(
                    from: cluster.keywordCandidates,
                    filter: stopwordFilter,
                    limit: 12
                )
            )
        })
        let displayTermsByCluster = Dictionary(uniqueKeysWithValues: searchTermsByCluster.map { clusterID, candidates in
            (clusterID, Array(candidates.prefix(max(1, keywordDisplayCount))))
        })
        let visibleSegmentsByCluster = buildVisibleSegmentsByCluster(
            from: result,
            matcher: matcher,
            stopwordFilter: stopwordFilter,
            searchTermsByCluster: searchTermsByCluster
        )
        let totalSegmentsByCluster = buildTotalSegmentsByCluster(from: result)
        let representativeSegmentsByCluster = buildRepresentativeSegmentsByCluster(from: result)
        let clusterItems = buildClusterItems(
            from: result,
            visibleSegmentsByCluster: visibleSegmentsByCluster,
            displayTermsByCluster: displayTermsByCluster,
            representativeSegmentsByCluster: representativeSegmentsByCluster,
            includeOutliers: includeOutliers,
            languageMode: languageMode
        )

        return TopicsClusterComputation(
            clusterItems: clusterItems,
            visibleSegmentsByCluster: visibleSegmentsByCluster,
            totalSegmentsByCluster: totalSegmentsByCluster,
            representativeSegmentsByCluster: representativeSegmentsByCluster,
            searchTermsByCluster: searchTermsByCluster,
            displayTermsByCluster: displayTermsByCluster,
            searchError: ""
        )
    }

    func buildClusterItems(
        from result: TopicAnalysisResult,
        visibleSegmentsByCluster: [String: [TopicSegmentRow]],
        displayTermsByCluster: [String: [TopicKeywordCandidate]],
        representativeSegmentsByCluster: [String: [String]],
        includeOutliers: Bool,
        languageMode: AppLanguageMode
    ) -> [TopicClusterSceneItem] {
        let eligibleClusters = result.clusters.filter { includeOutliers || !$0.isOutlier }
        return eligibleClusters.map { cluster in
            let visibleSegments = visibleSegmentsByCluster[cluster.id] ?? []
            let preview = representativeSegmentsByCluster[cluster.id]?.first ?? ""
            let displayTerms = displayTermsByCluster[cluster.id] ?? []
            return TopicClusterSceneItem(
                id: cluster.id,
                title: clusterTitle(for: cluster, mode: languageMode),
                keywordsText: displayTerms.isEmpty
                    ? wordZText("暂无关键词", "No keywords yet", mode: languageMode)
                    : displayTerms.map(\.term).joined(separator: " · "),
                sizeText: "\(wordZText("片段", "Segments", mode: languageMode)) \(cluster.size)",
                isOutlier: cluster.isOutlier,
                representativePreview: preview,
                visibleSegments: visibleSegments.count
            )
        }
    }

    func buildTableRows(from segments: [TopicSegmentRow]) -> [NativeTableRowDescriptor] {
        segments.map { segment in
            NativeTableRowDescriptor(
                id: segment.id,
                values: [
                    TopicsColumnKey.paragraph.rawValue: "\(segment.paragraphIndex)",
                    TopicsColumnKey.score.rawValue: String(format: "%.3f", segment.similarityScore),
                    TopicsColumnKey.excerpt.rawValue: segment.text
                ]
            )
        }
    }

    func buildSelectedCluster(
        cluster: TopicClusterSummary,
        selectedClusterSegments: [TopicSegmentRow],
        totalSegments: Int,
        summaryTerms: [TopicKeywordCandidate],
        representativeSegments: [String],
        languageMode: AppLanguageMode
    ) -> TopicsSelectedClusterSceneModel {
        TopicsSelectedClusterSceneModel(
            id: cluster.id,
            title: clusterTitle(for: cluster, mode: languageMode),
            summary: clusterSummaryText(
                cluster: cluster,
                visibleSegments: selectedClusterSegments.count,
                totalSegments: totalSegments,
                mode: languageMode
            ),
            keywords: summaryTerms.map {
                TopicKeywordSceneItem(
                    id: $0.term,
                    term: $0.term,
                    scoreText: String(format: "%.3f", $0.score)
                )
            },
            representativeSegments: representativeSegments,
            isOutlier: cluster.isOutlier
        )
    }

    func buildSummaryRows(
        from clusterItems: [TopicClusterSceneItem],
        languageMode: AppLanguageMode
    ) -> [NativeTableRowDescriptor] {
        clusterItems.map { item in
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
    }

    func makeSegmentsTable(
        languageMode: AppLanguageMode,
        visibleColumns: Set<TopicsColumnKey>,
        sortMode: TopicSegmentSortMode
    ) -> NativeTableDescriptor {
        NativeTableDescriptor(
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
        )
    }

    func makeSummaryTable(languageMode: AppLanguageMode) -> NativeTableDescriptor {
        NativeTableDescriptor(
            storageKey: "topics-summary",
            columns: [
                NativeTableColumnDescriptor(id: "topic", title: wordZText("主题", "Topic", mode: languageMode), isVisible: true, sortIndicator: nil, presentation: .keyword, widthPolicy: .keyword, isPinned: true),
                NativeTableColumnDescriptor(id: "size", title: wordZText("规模", "Size", mode: languageMode), isVisible: true, sortIndicator: nil, presentation: .label, widthPolicy: .standard),
                NativeTableColumnDescriptor(id: "keywords", title: wordZText("关键词", "Keywords", mode: languageMode), isVisible: true, sortIndicator: nil, presentation: .summary, widthPolicy: .summary),
                NativeTableColumnDescriptor(id: "type", title: wordZText("类型", "Type", mode: languageMode), isVisible: true, sortIndicator: nil, presentation: .label, widthPolicy: .compact)
            ],
            defaultDensity: .standard
        )
    }

    func emptyScene(
        from result: TopicAnalysisResult,
        query: String,
        searchOptions: SearchOptionsState,
        stopwordFilter: StopwordFilterState,
        minTopicSize: Int,
        keywordDisplayCount: Int,
        includeOutliers: Bool,
        sortMode: TopicSegmentSortMode,
        pageSize: TopicsPageSize,
        languageMode: AppLanguageMode,
        visibleColumns: Set<TopicsColumnKey>,
        searchError: String
    ) -> TopicsSceneModel {
        let summaryExportMetadataLines = exportMetadataLines(
            from: result,
            languageMode: languageMode,
            visibleRows: 0,
            totalRows: result.clusters.count,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            keywordDisplayCount: keywordDisplayCount
        )
        let segmentsExportMetadataLines = exportMetadataLines(
            from: result,
            languageMode: languageMode,
            visibleRows: 0,
            totalRows: result.totalSegments,
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            keywordDisplayCount: keywordDisplayCount
        )
        return TopicsSceneModel(
            query: query,
            searchOptions: searchOptions,
            stopwordFilter: stopwordFilter,
            controls: TopicsControlsSceneModel(
                minTopicSize: minTopicSize,
                keywordDisplayCount: keywordDisplayCount,
                includeOutliers: includeOutliers,
                selectedSort: sortMode,
                selectedPageSize: pageSize
            ),
            clusters: [],
            selectedClusterID: nil,
            selectedCluster: nil,
            tableRows: [],
            table: makeSegmentsTable(
                languageMode: languageMode,
                visibleColumns: visibleColumns,
                sortMode: sortMode
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
            warnings: result.warnings,
            searchError: searchError,
            summaryExportMetadataLines: summaryExportMetadataLines,
            segmentsExportMetadataLines: segmentsExportMetadataLines
        )
    }
}
