import Foundation

enum TopicsColumnKey: String, CaseIterable, Identifiable, Hashable {
    case paragraph
    case score
    case excerpt

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .paragraph:
            return wordZText("段落", "Paragraph", mode: mode)
        case .score:
            return wordZText("相关度", "Relevance", mode: mode)
        case .excerpt:
            return wordZText("内容", "Excerpt", mode: mode)
        }
    }
}

struct TopicClusterSceneItem: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let keywordsText: String
    let sizeText: String
    let contrastText: String?
    let isOutlier: Bool
    let representativePreview: String
    let visibleSegments: Int
}

struct TopicKeywordSceneItem: Identifiable, Equatable {
    let id: String
    let term: String
    let scoreText: String
}

struct TopicsSelectedClusterSceneModel: Equatable {
    let id: String
    let title: String
    let summary: String
    let contrastSummary: String?
    let keywords: [TopicKeywordSceneItem]
    let representativeSegments: [String]
    let isOutlier: Bool
}

struct TopicsControlsSceneModel: Equatable {
    let minTopicSize: Int
    let keywordDisplayCount: Int
    let includeOutliers: Bool
    let selectedSort: TopicSegmentSortMode
    let selectedPageSize: TopicsPageSize
}

struct TopicsSceneModel: Equatable {
    let query: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let crossAnalysisSummary: String?
    let sentimentExplainer: TopicsSentimentExplainer?
    let controls: TopicsControlsSceneModel
    let clusters: [TopicClusterSceneItem]
    let selectedClusterID: String?
    let selectedCluster: TopicsSelectedClusterSceneModel?
    let segmentRows: [TopicSegmentRow]
    let selectedSegmentID: String?
    let tableRows: [NativeTableRowDescriptor]
    let table: NativeTableDescriptor
    let summaryRows: [NativeTableRowDescriptor]
    let summaryTable: NativeTableDescriptor
    let pagination: ResultPaginationSceneModel
    let totalClusters: Int
    let visibleClusters: Int
    let totalSegments: Int
    let visibleSegments: Int
    let clusteredSegments: Int
    let outlierCount: Int
    let modelProvider: String
    let modelVersion: String
    let usesFallbackProvider: Bool
    let warnings: [String]
    let searchError: String
    let summaryExportMetadataLines: [String]
    let segmentsExportMetadataLines: [String]

    func column(for key: TopicsColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func isColumnVisible(_ key: TopicsColumnKey) -> Bool {
        table.isVisible(key.rawValue)
    }

    func columnTitle(for key: TopicsColumnKey, mode: AppLanguageMode) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title(in: mode))
    }

    var summaryExportSnapshot: NativeTableExportSnapshot? {
        guard !summaryRows.isEmpty else { return nil }
        return NativeTableExportSnapshot(
            suggestedBaseName: "topics-summary",
            table: summaryTable,
            rows: summaryRows,
            metadataLines: summaryExportMetadataLines
        )
    }

    var segmentsExportSnapshot: NativeTableExportSnapshot? {
        guard !tableRows.isEmpty else { return nil }
        return NativeTableExportSnapshot(
            suggestedBaseName: "topics-segments",
            table: table,
            rows: tableRows,
            metadataLines: segmentsExportMetadataLines
        )
    }
}
