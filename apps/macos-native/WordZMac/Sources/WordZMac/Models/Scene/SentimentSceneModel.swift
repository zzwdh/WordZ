import Foundation

enum SentimentSortMode: String, CaseIterable, Identifiable {
    case original
    case positivityDescending
    case neutralityDescending
    case negativityDescending
    case netScoreDescending
    case labelAscending
    case reviewStatusAscending
    case sourceAscending

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .original:
            return wordZText("原始顺序", "Original Order", mode: mode)
        case .positivityDescending:
            return wordZText("积极分降序", "Positivity Descending", mode: mode)
        case .neutralityDescending:
            return wordZText("中性分降序", "Neutrality Descending", mode: mode)
        case .negativityDescending:
            return wordZText("消极分降序", "Negativity Descending", mode: mode)
        case .netScoreDescending:
            return wordZText("净分降序", "Net Score Descending", mode: mode)
        case .labelAscending:
            return wordZText("标签分组", "Group by Label", mode: mode)
        case .reviewStatusAscending:
            return wordZText("审校状态分组", "Group by Review Status", mode: mode)
        case .sourceAscending:
            return wordZText("来源分组", "Group by Source", mode: mode)
        }
    }
}

enum SentimentPageSize: Int, CaseIterable, Identifiable {
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

extension SentimentPageSize: InteractiveAllPageSizing {
    var isAllSelection: Bool { self == .all }

    static var safeInteractiveFallback: SentimentPageSize { .oneHundred }
}

enum SentimentChartKind: String, CaseIterable, Identifiable, Codable {
    case distributionBar
    case distributionDonut
    case trendLine

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .distributionBar:
            return wordZText("柱状图", "Bar", mode: mode)
        case .distributionDonut:
            return wordZText("环图", "Donut", mode: mode)
        case .trendLine:
            return wordZText("趋势线", "Trend", mode: mode)
        }
    }
}

enum SentimentColumnKey: String, CaseIterable, Identifiable, Hashable {
    case source
    case text
    case positivity
    case neutrality
    case negativity
    case finalLabel
    case rawLabel
    case reviewStatus
    case netScore
    case evidence

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .source:
            return wordZText("来源", "Source", mode: mode)
        case .text:
            return wordZText("文本", "Text", mode: mode)
        case .positivity:
            return wordZText("积极分", "Positivity", mode: mode)
        case .neutrality:
            return wordZText("中性分", "Neutrality", mode: mode)
        case .negativity:
            return wordZText("消极分", "Negativity", mode: mode)
        case .finalLabel:
            return wordZText("最终标签", "Final Label", mode: mode)
        case .rawLabel:
            return wordZText("原始标签", "Raw Label", mode: mode)
        case .reviewStatus:
            return wordZText("审校状态", "Review Status", mode: mode)
        case .netScore:
            return wordZText("净分", "Net Score", mode: mode)
        case .evidence:
            return wordZText("证据", "Evidence", mode: mode)
        }
    }
}

struct SentimentSceneRow: Identifiable, Equatable {
    let id: String
    let sourceTitle: String
    let groupTitle: String
    let text: String
    let rawPositivityScore: Double
    let rawNeutralityScore: Double
    let rawNegativityScore: Double
    let rawLabel: SentimentLabel
    let rawNetScore: Double
    let effectivePositivityScore: Double
    let effectiveNeutralityScore: Double
    let effectiveNegativityScore: Double
    let effectiveLabel: SentimentLabel
    let effectiveNetScore: Double
    let evidenceCount: Int
    let evidencePreview: String
    let evidence: [SentimentEvidenceHit]
    let diagnostics: SentimentRowDiagnostics
    let sentenceID: Int?
    let tokenIndex: Int?
    let reviewDecision: SentimentReviewDecision?
    let reviewStatus: SentimentReviewStatus
    let reviewNote: String?
    let reviewedAt: String?
    let reviewSampleID: String?

    var mixedEvidence: Bool { diagnostics.mixedEvidence }
    var positivityScore: Double { rawPositivityScore }
    var neutralityScore: Double { rawNeutralityScore }
    var negativityScore: Double { rawNegativityScore }
    var finalLabel: SentimentLabel { effectiveLabel }
    var netScore: Double { rawNetScore }
    var isManuallyOverridden: Bool { reviewStatus == .overridden }
}

struct SentimentChartSegment: Identifiable, Equatable {
    let label: SentimentLabel
    let count: Int
    let ratio: Double

    var id: String { label.id }
}

struct SentimentTrendPoint: Identifiable, Equatable {
    let index: Int
    let label: SentimentLabel
    let netScore: Double
    let title: String

    var id: Int { index }
}

struct SentimentSortingSceneModel: Equatable {
    let selectedSort: SentimentSortMode
    let selectedPageSize: SentimentPageSize
}

struct SentimentSceneModel: Equatable {
    let source: SentimentInputSource
    let unit: SentimentAnalysisUnit
    let contextBasis: SentimentContextBasis
    let backend: SentimentBackendKind
    let domainPackID: SentimentDomainPackID
    let ruleProfileID: String
    let backendRevision: String
    let resourceRevision: String
    let supportsEvidenceHits: Bool
    let thresholdPreset: SentimentThresholdPreset
    let thresholds: SentimentThresholds
    let chartKind: SentimentChartKind
    let filterQuery: String
    let labelFilter: SentimentLabel?
    let reviewFilter: SentimentReviewFilter
    let reviewStatusFilter: SentimentReviewStatusFilter
    let showOnlyHardCases: Bool
    let activePackIDs: [SentimentDomainPackID]
    let summary: SentimentAggregateSummary
    let groupSummaries: [SentimentAggregateSummary]
    let reviewSummary: SentimentReviewSummary
    let sorting: SentimentSortingSceneModel
    let pagination: ResultPaginationSceneModel
    let totalRows: Int
    let filteredRows: Int
    let visibleRows: Int
    let selectedRowID: String?
    let rows: [SentimentSceneRow]
    let positiveExamples: [SentimentSceneRow]
    let neutralExamples: [SentimentSceneRow]
    let negativeExamples: [SentimentSceneRow]
    let chartSegments: [SentimentChartSegment]
    let trendPoints: [SentimentTrendPoint]
    let table: NativeTableDescriptor
    let tableRows: [NativeTableRowDescriptor]
    let tableSnapshot: ResultTableSnapshot
    let exportMetadataLines: [String]

    func column(for key: SentimentColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func columnTitle(for key: SentimentColumnKey, mode: AppLanguageMode) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title(in: mode))
    }
}
