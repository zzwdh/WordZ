import Foundation

enum TopicAnalysisGranularity: String, Codable, Sendable {
    case paragraph
}

struct TopicModelManifest: Codable, Equatable, Sendable {
    let modelID: String
    let version: String
    let language: String
    let provider: String
    let dimensions: Int

    static let fallback = TopicModelManifest(
        modelID: "wordz-topics-english",
        version: "1",
        language: "english",
        provider: "system-sentence-embedding",
        dimensions: 256
    )
}

enum TopicAnalysisError: LocalizedError {
    case missingModelManifest
    case invalidModelManifest
    case embeddingUnavailable
    case noEnglishParagraphs
    case noTopicsGenerated
    case unsupportedRepository

    var errorDescription: String? {
        switch self {
        case .missingModelManifest:
            return "Topics 模型清单缺失，无法初始化本地主题模型。"
        case .invalidModelManifest:
            return "Topics 模型清单损坏或格式无效。"
        case .embeddingUnavailable:
            return "当前系统无法提供英文句向量模型。"
        case .noEnglishParagraphs:
            return "当前语料没有可用于英文 Topics 建模的段落。"
        case .noTopicsGenerated:
            return "当前语料未能生成稳定主题，请尝试降低最小主题大小。"
        case .unsupportedRepository:
            return "当前仓储实现不支持 Topics 分析。"
        }
    }
}

struct TopicAnalysisOptions: Equatable, Sendable {
    var granularity: TopicAnalysisGranularity = .paragraph
    var language: String = "english"
    var minTopicSize: Int = 2
    var includeOutliers: Bool = true
    var searchQuery: String = ""
    var searchOptions: SearchOptionsState = .default
    var stopwordFilter: StopwordFilterState = .default
}

struct TopicKeywordCandidate: Equatable, Hashable, Sendable {
    let term: String
    let score: Double
}

struct TopicClusterSummary: Identifiable, Equatable, Sendable {
    let id: String
    let index: Int
    let isOutlier: Bool
    let size: Int
    let keywordCandidates: [TopicKeywordCandidate]
    let representativeSegmentIDs: [String]

    var keywordTerms: [String] {
        keywordCandidates.map(\.term)
    }
}

struct TopicSegmentRow: Identifiable, Equatable, Sendable {
    let id: String
    let topicID: String
    let paragraphIndex: Int
    let text: String
    let similarityScore: Double
    let isOutlier: Bool
}

struct TopicAnalysisResult: Equatable, Sendable {
    static let outlierTopicID = "topics-outliers"

    let modelVersion: String
    let modelProvider: String
    let usesFallbackProvider: Bool
    let clusters: [TopicClusterSummary]
    let segments: [TopicSegmentRow]
    let totalSegments: Int
    let clusteredSegments: Int
    let outlierCount: Int
    let warnings: [String]

    func cluster(for id: String) -> TopicClusterSummary? {
        clusters.first(where: { $0.id == id })
    }

    func representativeSegments(for clusterID: String) -> [TopicSegmentRow] {
        guard let cluster = cluster(for: clusterID) else { return [] }
        return cluster.representativeSegmentIDs.compactMap { representativeID in
            segments.first(where: { $0.id == representativeID })
        }
    }
}

struct TopicAnalysisProgress: Equatable, Sendable {
    enum Stage: String, Sendable {
        case preparing
        case segmenting
        case embedding
        case clustering
        case summarizing
    }

    let stage: Stage
    let detail: String
    let progress: Double?
}

enum TopicSegmentSortMode: String, CaseIterable, Identifiable, Sendable {
    case relevanceDescending
    case relevanceAscending
    case paragraphAscending
    case paragraphDescending
    case alphabeticalAscending
    case alphabeticalDescending

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .relevanceDescending:
            return wordZText("相关度降序", "Relevance Descending", mode: mode)
        case .relevanceAscending:
            return wordZText("相关度升序", "Relevance Ascending", mode: mode)
        case .paragraphAscending:
            return wordZText("段落升序", "Paragraph Ascending", mode: mode)
        case .paragraphDescending:
            return wordZText("段落降序", "Paragraph Descending", mode: mode)
        case .alphabeticalAscending:
            return wordZText("内容升序", "Text Ascending", mode: mode)
        case .alphabeticalDescending:
            return wordZText("内容降序", "Text Descending", mode: mode)
        }
    }
}

enum TopicsPageSize: Int, CaseIterable, Identifiable, Sendable {
    case twentyFive = 25
    case fifty = 50
    case oneHundred = 100
    case all = -1

    var id: Int { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .twentyFive:
            return "25"
        case .fifty:
            return "50"
        case .oneHundred:
            return "100"
        case .all:
            return wordZText("全部", "All", mode: mode)
        }
    }

    var rowLimit: Int? {
        self == .all ? nil : rawValue
    }
}
