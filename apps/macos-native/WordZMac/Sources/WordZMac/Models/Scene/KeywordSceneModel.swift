import Foundation

enum KeywordSortMode: String, CaseIterable, Identifiable {
    case keynessDescending
    case absLogRatioDescending
    case focusFrequencyDescending
    case focusNormFrequencyDescending
    case focusRangeDescending
    case coverageDescending
    case updatedAtDescending
    case alphabeticalAscending

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .keynessDescending:
            return wordZText("显著性降序", "Keyness Descending", mode: mode)
        case .absLogRatioDescending:
            return wordZText("效应值降序", "Abs Log Ratio Descending", mode: mode)
        case .focusFrequencyDescending:
            return wordZText("Focus 频次降序", "Focus Frequency Descending", mode: mode)
        case .focusNormFrequencyDescending:
            return wordZText("Focus 标准频次降序", "Focus Normalized Frequency Descending", mode: mode)
        case .focusRangeDescending:
            return wordZText("Focus 覆盖降序", "Focus Range Descending", mode: mode)
        case .coverageDescending:
            return wordZText("覆盖数降序", "Coverage Descending", mode: mode)
        case .updatedAtDescending:
            return wordZText("最近更新", "Updated Descending", mode: mode)
        case .alphabeticalAscending:
            return wordZText("按词升序", "Alphabetical Ascending", mode: mode)
        }
    }
}

enum KeywordPageSize: Int, CaseIterable, Identifiable {
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

enum KeywordColumnKey: String, CaseIterable, Identifiable, Hashable {
    case rank
    case item
    case direction
    case focusFrequency
    case referenceFrequency
    case focusNormFrequency
    case referenceNormFrequency
    case keyness
    case logRatio
    case pValue
    case focusRange
    case referenceRange
    case example
    case diffStatus
    case leftRank
    case rightRank
    case logRatioDelta
    case coverageCount
    case coverageRate
    case meanKeyness
    case meanAbsLogRatio
    case lastSeenAt

    var id: String { rawValue }

    func title(in mode: AppLanguageMode, statistic: KeywordStatisticMethod) -> String {
        switch self {
        case .rank:
            return wordZText("排名", "Rank", mode: mode)
        case .item:
            return wordZText("词项", "Item", mode: mode)
        case .direction:
            return wordZText("方向", "Direction", mode: mode)
        case .focusFrequency:
            return wordZText("Focus 频次", "Focus Freq", mode: mode)
        case .referenceFrequency:
            return wordZText("Reference 频次", "Reference Freq", mode: mode)
        case .focusNormFrequency:
            return wordZText("Focus 标准频次", "Focus Norm", mode: mode)
        case .referenceNormFrequency:
            return wordZText("Reference 标准频次", "Reference Norm", mode: mode)
        case .keyness:
            return statistic == .logLikelihood
                ? wordZText("Log-Likelihood", "Log-Likelihood", mode: mode)
                : wordZText("Chi-square", "Chi-square", mode: mode)
        case .logRatio:
            return wordZText("Log Ratio", "Log Ratio", mode: mode)
        case .pValue:
            return "p"
        case .focusRange:
            return wordZText("Focus 覆盖", "Focus Range", mode: mode)
        case .referenceRange:
            return wordZText("Reference 覆盖", "Reference Range", mode: mode)
        case .example:
            return wordZText("例句", "Example", mode: mode)
        case .diffStatus:
            return wordZText("状态", "Status", mode: mode)
        case .leftRank:
            return wordZText("左侧排名", "Left Rank", mode: mode)
        case .rightRank:
            return wordZText("右侧排名", "Right Rank", mode: mode)
        case .logRatioDelta:
            return wordZText("Log Ratio 差", "Log Ratio Delta", mode: mode)
        case .coverageCount:
            return wordZText("覆盖词表数", "Coverage Count", mode: mode)
        case .coverageRate:
            return wordZText("覆盖率", "Coverage Rate", mode: mode)
        case .meanKeyness:
            return wordZText("平均显著性", "Mean Keyness", mode: mode)
        case .meanAbsLogRatio:
            return wordZText("平均绝对 Log Ratio", "Mean Abs Log Ratio", mode: mode)
        case .lastSeenAt:
            return wordZText("最近出现", "Last Seen", mode: mode)
        }
    }
}

struct KeywordCorpusOptionSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

struct KeywordCorpusSetOptionSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

struct KeywordSavedListSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let group: KeywordResultGroup
    let updatedAt: String
}

enum KeywordSceneRowKind: Equatable {
    case keyword
    case pairwiseDiff
    case keywordDatabase
}

struct KeywordSceneRow: Identifiable, Equatable {
    let id: String
    let kind: KeywordSceneRowKind
    let rankText: String
    let item: String
    let directionText: String
    let focusFrequencyText: String
    let referenceFrequencyText: String
    let focusNormFrequencyText: String
    let referenceNormFrequencyText: String
    let keynessText: String
    let logRatioText: String
    let pValueText: String
    let focusRangeText: String
    let referenceRangeText: String
    let exampleText: String
    let diffStatusText: String
    let leftRankText: String
    let rightRankText: String
    let logRatioDeltaText: String
    let coverageCountText: String
    let coverageRateText: String
    let meanKeynessText: String
    let meanAbsLogRatioText: String
    let lastSeenAtText: String

    // Compatibility aliases for older views/tests that still use the v1 naming.
    var word: String { item }
    var scoreText: String { keynessText }
    var targetFrequencyText: String { focusFrequencyText }
    var targetNormFrequencyText: String { focusNormFrequencyText }
    var targetRangeText: String { focusRangeText }
}

struct KeywordSortingSceneModel: Equatable {
    let selectedSort: KeywordSortMode
    let selectedPageSize: KeywordPageSize
}

struct KeywordSceneModel: Equatable {
    let activeTab: KeywordSuiteTab
    let listMode: KeywordSavedListViewMode
    let focusSummary: String
    let referenceSummary: String
    let configurationSummary: String
    let methodSummary: String
    let methodNotes: [String]
    let exportMetadataLines: [String]
    let sorting: KeywordSortingSceneModel
    let pagination: ResultPaginationSceneModel
    let table: NativeTableDescriptor
    let totalRows: Int
    let visibleRows: Int
    let wordsCount: Int
    let termsCount: Int
    let ngramsCount: Int
    let savedListsCount: Int
    let rows: [KeywordSceneRow]
    let tableRows: [NativeTableRowDescriptor]
    let emptyStateTitle: String
    let emptyStateMessage: String

    // Compatibility aliases for older views/tests that still use the v1 naming.
    var preprocessingSummary: String { configurationSummary }
    var targetSummary: String { focusSummary }

    func column(for key: KeywordColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func columnTitle(
        for key: KeywordColumnKey,
        mode: AppLanguageMode,
        statistic: KeywordStatisticMethod
    ) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title(in: mode, statistic: statistic))
    }
}
