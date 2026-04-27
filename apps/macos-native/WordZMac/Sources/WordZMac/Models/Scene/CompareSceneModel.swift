import Foundation

enum CompareSortMode: String, CaseIterable, Identifiable {
    case keynessDescending
    case spreadDescending
    case totalDescending
    case rangeDescending
    case effectDescending
    case alphabeticalAscending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keynessDescending:
            return "Keyness 降序"
        case .spreadDescending:
            return "覆盖降序"
        case .totalDescending:
            return "总频降序"
        case .rangeDescending:
            return "差异降序"
        case .effectDescending:
            return "效应值降序"
        case .alphabeticalAscending:
            return "按词升序"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .keynessDescending:
            return wordZText("Keyness 降序", "Keyness Descending", mode: mode)
        case .spreadDescending:
            return wordZText("覆盖降序", "Spread Descending", mode: mode)
        case .totalDescending:
            return wordZText("总频降序", "Total Descending", mode: mode)
        case .rangeDescending:
            return wordZText("差异降序", "Range Descending", mode: mode)
        case .effectDescending:
            return wordZText("效应值降序", "Effect Descending", mode: mode)
        case .alphabeticalAscending:
            return wordZText("按词升序", "Alphabetical Ascending", mode: mode)
        }
    }
}

enum ComparePageSize: Int, CaseIterable, Identifiable {
    case twentyFive = 25
    case fifty = 50
    case oneHundred = 100
    case all = -1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .twentyFive:
            return "25"
        case .fifty:
            return "50"
        case .oneHundred:
            return "100"
        case .all:
            return "全部"
        }
    }

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

enum CompareColumnKey: String, CaseIterable, Identifiable, Hashable {
    case word
    case keyness
    case effect
    case spread
    case total
    case range
    case dominantCorpus
    case distribution

    var id: String { rawValue }

    var title: String {
        switch self {
        case .word:
            return "词"
        case .keyness:
            return "Keyness"
        case .effect:
            return "Log Ratio"
        case .spread:
            return "覆盖语料"
        case .total:
            return "总频次"
        case .range:
            return "差异"
        case .dominantCorpus:
            return "主导语料"
        case .distribution:
            return "分布"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .word:
            return wordZText("词", "Word", mode: mode)
        case .keyness:
            return wordZText("Keyness", "Keyness", mode: mode)
        case .effect:
            return wordZText("Log Ratio", "Log Ratio", mode: mode)
        case .spread:
            return wordZText("覆盖语料", "Spread", mode: mode)
        case .total:
            return wordZText("总频次", "Total", mode: mode)
        case .range:
            return wordZText("差异", "Range", mode: mode)
        case .dominantCorpus:
            return wordZText("主导语料", "Dominant Corpus", mode: mode)
        case .distribution:
            return wordZText("分布", "Distribution", mode: mode)
        }
    }
}

struct CompareSelectableCorpusSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let isSelected: Bool
}

struct CompareReferenceOptionSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
}

struct CompareCorpusSummarySceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let tokenCountText: String
    let typeCountText: String
    let ttrText: String
    let sttrText: String
    let topWordText: String
}

struct CompareSceneRow: Identifiable, Equatable {
    let id: String
    let word: String
    let keynessText: String
    let effectText: String
    let pValueText: String
    let spreadText: String
    let totalText: String
    let rangeText: String
    let referenceNormFreqText: String
    let referenceLabelText: String
    let dominantCorpus: String
    let distributionText: String
}

struct CompareSortingSceneModel: Equatable {
    let selectedSort: CompareSortMode
    let selectedPageSize: ComparePageSize
}

struct CompareSceneModel: Equatable {
    let selection: [CompareSelectableCorpusSceneItem]
    let corpusSummaries: [CompareCorpusSummarySceneItem]
    let query: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let annotationSummary: String
    let referenceSummary: String
    let methodSummary: String
    let methodNotes: [String]
    let sentimentSummary: CompareSentimentSummary?
    let sentimentExplainer: CompareSentimentExplainer?
    let topicsSummary: CompareTopicsSummary?
    let exportMetadataLines: [String]
    let sorting: CompareSortingSceneModel
    let pagination: ResultPaginationSceneModel
    let table: NativeTableDescriptor
    let totalRows: Int
    let filteredRows: Int
    let visibleRows: Int
    let rows: [CompareSceneRow]
    let tableSnapshot: ResultTableSnapshot
    let searchError: String

    var tableRows: [NativeTableRowDescriptor] {
        tableSnapshot.rows
    }

    func column(for key: CompareColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func isColumnVisible(_ key: CompareColumnKey) -> Bool {
        table.isVisible(key.rawValue)
    }

    func columnTitle(for key: CompareColumnKey, mode: AppLanguageMode) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title(in: mode))
    }

    func columnTitle(for key: CompareColumnKey) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title)
    }
}
