import XCTest
@testable import WordZWorkspaceCore

@MainActor
final class TopicsSceneBuilderTests: XCTestCase {
    func testTopicsSceneBuilderBuildsClustersAndSelectedTopicDetails() {
        let result = makeTopicAnalysisResult()
        let scene = TopicsSceneBuilder().build(
            from: result,
            query: "",
            searchOptions: .default,
            stopwordFilter: .default,
            minTopicSize: 3,
            keywordDisplayCount: 5,
            includeOutliers: true,
            selectedClusterID: "topic-1",
            sortMode: .relevanceDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(TopicsColumnKey.allCases)
        )

        XCTAssertEqual(scene.totalClusters, 2)
        XCTAssertEqual(scene.visibleClusters, 2)
        XCTAssertEqual(scene.selectedClusterID, "topic-1")
        XCTAssertEqual(scene.selectedCluster?.keywords.first?.term, "security")
        XCTAssertEqual(scene.visibleSegments, 2)
        XCTAssertTrue(scene.table.isVisible(TopicsColumnKey.excerpt.rawValue))
    }

    func testTopicsSceneBuilderCanHideOutliers() {
        let result = makeTopicAnalysisResult()
        let scene = TopicsSceneBuilder().build(
            from: result,
            query: "",
            searchOptions: .default,
            stopwordFilter: .default,
            minTopicSize: 3,
            keywordDisplayCount: 5,
            includeOutliers: false,
            selectedClusterID: nil,
            sortMode: .relevanceDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(TopicsColumnKey.allCases)
        )

        XCTAssertEqual(scene.totalClusters, 2)
        XCTAssertEqual(scene.visibleClusters, 1)
        XCTAssertFalse(scene.clusters.contains(where: \.isOutlier))
    }

    func testTopicsSceneBuilderFiltersSegmentsByWildcardQuery() {
        let result = makeTopicAnalysisResult()
        let scene = TopicsSceneBuilder().build(
            from: result,
            query: "hack*",
            searchOptions: .default,
            stopwordFilter: .default,
            minTopicSize: 3,
            keywordDisplayCount: 5,
            includeOutliers: true,
            selectedClusterID: "topic-1",
            sortMode: .relevanceDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(TopicsColumnKey.allCases)
        )

        XCTAssertEqual(scene.visibleSegments, 2)
        XCTAssertTrue(scene.tableRows.allSatisfy { ($0.values[TopicsColumnKey.excerpt.rawValue] ?? "").localizedCaseInsensitiveContains("hack") })
    }

    func testTopicsSceneBuilderPropagatesWarningsIntoSceneAndExports() {
        let base = makeTopicAnalysisResult()
        let result = TopicAnalysisResult(
            modelVersion: base.modelVersion,
            modelProvider: base.modelProvider,
            usesFallbackProvider: base.usesFallbackProvider,
            clusters: base.clusters,
            segments: base.segments,
            totalSegments: base.totalSegments,
            clusteredSegments: base.clusteredSegments,
            outlierCount: base.outlierCount,
            warnings: [
                "Topics 内置本地向量模型不可用，已回退到系统句向量。",
                "Topics 聚类质量较低，结果已保守收缩为单主题加离群片段。"
            ]
        )
        let scene = TopicsSceneBuilder().build(
            from: result,
            query: "hack*",
            searchOptions: .default,
            stopwordFilter: .default,
            minTopicSize: 3,
            keywordDisplayCount: 3,
            includeOutliers: true,
            selectedClusterID: "topic-1",
            sortMode: .relevanceDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(TopicsColumnKey.allCases)
        )

        XCTAssertEqual(scene.warnings, result.warnings)
        XCTAssertTrue(scene.summaryExportSnapshot?.metadataLines.contains(where: {
            $0.contains("系统句向量")
        }) ?? false)
        XCTAssertTrue(scene.summaryExportSnapshot?.metadataLines.contains(where: {
            $0.contains("单词") || $0.contains("Single-word")
        }) ?? false)
        XCTAssertTrue(scene.summaryExportSnapshot?.metadataLines.contains(where: {
            $0.contains("3")
        }) ?? false)
        XCTAssertTrue(scene.segmentsExportSnapshot?.metadataLines.contains(where: {
            $0.contains("保守收缩")
        }) ?? false)
    }

    func testTopicsSceneBuilderHandlesDuplicateSegmentIDsWithoutCrashing() {
        let base = makeTopicAnalysisResult()
        let duplicateSegments = [
            TopicSegmentRow(
                id: "slice-dup",
                topicID: "topic-1",
                paragraphIndex: 1,
                text: "Repeated topic slice one.",
                similarityScore: 0.91,
                isOutlier: false
            ),
            TopicSegmentRow(
                id: "slice-dup",
                topicID: "topic-1",
                paragraphIndex: 2,
                text: "Repeated topic slice two.",
                similarityScore: 0.89,
                isOutlier: false
            )
        ]
        let result = TopicAnalysisResult(
            modelVersion: base.modelVersion,
            modelProvider: base.modelProvider,
            usesFallbackProvider: base.usesFallbackProvider,
            clusters: [
                TopicClusterSummary(
                    id: "topic-1",
                    index: 1,
                    isOutlier: false,
                    size: duplicateSegments.count,
                    keywordCandidates: [
                        TopicKeywordCandidate(term: "security", score: 1.1)
                    ],
                    representativeSegmentIDs: ["slice-dup"]
                )
            ],
            segments: duplicateSegments,
            totalSegments: duplicateSegments.count,
            clusteredSegments: duplicateSegments.count,
            outlierCount: 0,
            warnings: []
        )

        let scene = TopicsSceneBuilder().build(
            from: result,
            query: "",
            searchOptions: .default,
            stopwordFilter: .default,
            minTopicSize: 2,
            keywordDisplayCount: 5,
            includeOutliers: true,
            selectedClusterID: "topic-1",
            sortMode: .relevanceDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(TopicsColumnKey.allCases)
        )

        XCTAssertEqual(scene.visibleSegments, 2)
        XCTAssertEqual(scene.tableRows.count, 2)
        XCTAssertEqual(scene.selectedCluster?.representativeSegments.first, "Repeated topic slice one.")
    }

    func testTopicsSceneBuilderRespectsKeywordDisplayCountAcrossCardsAndDetails() {
        let result = makeKeywordRichTopicAnalysisResult()

        let scene = TopicsSceneBuilder().build(
            from: result,
            query: "",
            searchOptions: .default,
            stopwordFilter: .default,
            minTopicSize: 2,
            keywordDisplayCount: 3,
            includeOutliers: true,
            selectedClusterID: "topic-1",
            sortMode: .relevanceDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(TopicsColumnKey.allCases)
        )

        XCTAssertEqual(scene.controls.keywordDisplayCount, 3)
        XCTAssertEqual(scene.clusters.first?.keywordsText, "alpha · beta · gamma")
        XCTAssertEqual(scene.selectedCluster?.keywords.map(\.term), ["alpha", "beta", "gamma"])
    }

    func testTopicsSceneBuilderSearchUsesFullKeywordSetBeyondDisplayedKeywords() {
        let result = makeKeywordRichTopicAnalysisResult()

        let scene = TopicsSceneBuilder().build(
            from: result,
            query: "malware",
            searchOptions: .default,
            stopwordFilter: .default,
            minTopicSize: 2,
            keywordDisplayCount: 3,
            includeOutliers: true,
            selectedClusterID: "topic-1",
            sortMode: .relevanceDescending,
            pageSize: .fifty,
            currentPage: 1,
            visibleColumns: Set(TopicsColumnKey.allCases)
        )

        XCTAssertEqual(scene.selectedCluster?.keywords.map(\.term), ["alpha", "beta", "gamma"])
        XCTAssertEqual(scene.visibleSegments, 1)
        XCTAssertEqual(scene.tableRows.first?.values[TopicsColumnKey.excerpt.rawValue], "Operators rotated infrastructure across campaigns.")
    }
}

private func makeKeywordRichTopicAnalysisResult() -> TopicAnalysisResult {
    TopicAnalysisResult(
        modelVersion: "wordz-topics-english-1",
        modelProvider: "system-sentence-embedding",
        usesFallbackProvider: false,
        clusters: [
            TopicClusterSummary(
                id: "topic-1",
                index: 1,
                isOutlier: false,
                size: 1,
                keywordCandidates: [
                    TopicKeywordCandidate(term: "alpha", score: 1.6),
                    TopicKeywordCandidate(term: "beta", score: 1.4),
                    TopicKeywordCandidate(term: "gamma", score: 1.2),
                    TopicKeywordCandidate(term: "malware", score: 1.0),
                    TopicKeywordCandidate(term: "delta", score: 0.9)
                ],
                representativeSegmentIDs: ["segment-1"]
            )
        ],
        segments: [
            TopicSegmentRow(
                id: "segment-1",
                topicID: "topic-1",
                paragraphIndex: 1,
                text: "Operators rotated infrastructure across campaigns.",
                similarityScore: 0.91,
                isOutlier: false
            )
        ],
        totalSegments: 1,
        clusteredSegments: 1,
        outlierCount: 0,
        warnings: []
    )
}
