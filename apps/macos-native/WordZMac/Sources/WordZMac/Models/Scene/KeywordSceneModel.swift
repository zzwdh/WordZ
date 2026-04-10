import Foundation

enum KeywordSortMode: String, CaseIterable, Identifiable {
    case scoreDescending
    case targetFrequencyDescending
    case targetNormFrequencyDescending
    case alphabeticalAscending

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .scoreDescending:
            return wordZText("显著性降序", "Keyness Descending", mode: mode)
        case .targetFrequencyDescending:
            return wordZText("Target 频次降序", "Target Frequency Descending", mode: mode)
        case .targetNormFrequencyDescending:
            return wordZText("Target 标准频次降序", "Target Normalized Frequency Descending", mode: mode)
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
    case word
    case targetFrequency
    case referenceFrequency
    case targetNormFrequency
    case referenceNormFrequency
    case score
    case logRatio
    case pValue

    var id: String { rawValue }

    func title(in mode: AppLanguageMode, statistic: KeywordStatisticMethod) -> String {
        switch self {
        case .rank:
            return wordZText("排名", "Rank", mode: mode)
        case .word:
            return wordZText("词项", "Word", mode: mode)
        case .targetFrequency:
            return wordZText("Target 频次", "Target Freq", mode: mode)
        case .referenceFrequency:
            return wordZText("Reference 频次", "Reference Freq", mode: mode)
        case .targetNormFrequency:
            return wordZText("Target 标准频次", "Target Norm Freq", mode: mode)
        case .referenceNormFrequency:
            return wordZText("Reference 标准频次", "Reference Norm Freq", mode: mode)
        case .score:
            return statistic == .logLikelihood
                ? wordZText("Log-Likelihood", "Log-Likelihood", mode: mode)
                : wordZText("Chi-square", "Chi-square", mode: mode)
        case .logRatio:
            return wordZText("Log Ratio", "Log Ratio", mode: mode)
        case .pValue:
            return "p"
        }
    }
}

struct KeywordCorpusOptionSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

struct KeywordSceneRow: Identifiable, Equatable {
    let id: String
    let rankText: String
    let word: String
    let targetFrequencyText: String
    let referenceFrequencyText: String
    let targetNormFrequencyText: String
    let referenceNormFrequencyText: String
    let scoreText: String
    let logRatioText: String
    let pValueText: String
}

struct KeywordSortingSceneModel: Equatable {
    let selectedSort: KeywordSortMode
    let selectedPageSize: KeywordPageSize
}

struct KeywordSceneModel: Equatable {
    let targetSummary: String
    let referenceSummary: String
    let preprocessingSummary: String
    let methodSummary: String
    let methodNotes: [String]
    let exportMetadataLines: [String]
    let sorting: KeywordSortingSceneModel
    let pagination: ResultPaginationSceneModel
    let table: NativeTableDescriptor
    let totalRows: Int
    let visibleRows: Int
    let rows: [KeywordSceneRow]
    let tableRows: [NativeTableRowDescriptor]

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
