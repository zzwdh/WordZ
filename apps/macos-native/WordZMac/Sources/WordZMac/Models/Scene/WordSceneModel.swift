import Foundation

enum WordSortMode: String, CaseIterable, Identifiable {
    case frequencyDescending
    case frequencyAscending
    case rankAscending
    case rankDescending
    case rangeDescending
    case rangeAscending
    case alphabeticalAscending
    case alphabeticalDescending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frequencyDescending:
            return "频次降序"
        case .frequencyAscending:
            return "频次升序"
        case .rankAscending:
            return "排名升序"
        case .rankDescending:
            return "排名降序"
        case .rangeDescending:
            return "Range 降序"
        case .rangeAscending:
            return "Range 升序"
        case .alphabeticalAscending:
            return "按词升序"
        case .alphabeticalDescending:
            return "按词降序"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .frequencyDescending:
            return wordZText("频次降序", "Frequency Descending", mode: mode)
        case .frequencyAscending:
            return wordZText("频次升序", "Frequency Ascending", mode: mode)
        case .rankAscending:
            return wordZText("排名升序", "Rank Ascending", mode: mode)
        case .rankDescending:
            return wordZText("排名降序", "Rank Descending", mode: mode)
        case .rangeDescending:
            return wordZText("Range 降序", "Range Descending", mode: mode)
        case .rangeAscending:
            return wordZText("Range 升序", "Range Ascending", mode: mode)
        case .alphabeticalAscending:
            return wordZText("按词升序", "Alphabetical Ascending", mode: mode)
        case .alphabeticalDescending:
            return wordZText("按词降序", "Alphabetical Descending", mode: mode)
        }
    }
}

enum WordPageSize: Int, CaseIterable, Identifiable {
    case fifty = 50
    case oneHundred = 100
    case twoHundredFifty = 250
    case all = -1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .fifty:
            return "50"
        case .oneHundred:
            return "100"
        case .twoHundredFifty:
            return "250"
        case .all:
            return "全部"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .fifty:
            return "50"
        case .oneHundred:
            return "100"
        case .twoHundredFifty:
            return "250"
        case .all:
            return wordZText("全部", "All", mode: mode)
        }
    }

    var rowLimit: Int? { self == .all ? nil : rawValue }
}

enum WordColumnKey: String, CaseIterable, Identifiable, Hashable {
    case rank
    case word
    case count
    case normFrequency
    case range
    case normRange

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rank:
            return "Rank"
        case .word:
            return "词"
        case .count:
            return "频次"
        case .normFrequency:
            return "Norm Frequency"
        case .range:
            return "Range"
        case .normRange:
            return "Norm Range %"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .rank:
            return wordZText("排名", "Rank", mode: mode)
        case .word:
            return wordZText("词", "Word", mode: mode)
        case .count:
            return wordZText("频次", "Count", mode: mode)
        case .normFrequency:
            return wordZText("标准频次", "Norm Frequency", mode: mode)
        case .range:
            return wordZText("Range", "Range", mode: mode)
        case .normRange:
            return wordZText("Norm Range %", "Norm Range %", mode: mode)
        }
    }
}

struct WordSceneRow: Identifiable, Equatable {
    let id: String
    let rankText: String
    let word: String
    let countText: String
    let normFrequencyText: String
    let rangeText: String
    let normRangeText: String
}

struct WordSortingSceneModel: Equatable {
    let selectedSort: WordSortMode
    let selectedPageSize: WordPageSize
}

struct WordSceneModel: Equatable {
    let query: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let annotationSummary: String
    let definition: FrequencyMetricDefinition
    let definitionSummary: String
    let exportMetadataLines: [String]
    let sorting: WordSortingSceneModel
    let pagination: ResultPaginationSceneModel
    let table: NativeTableDescriptor
    let totalRows: Int
    let filteredRows: Int
    let visibleRows: Int
    let rows: [WordSceneRow]
    let tableRows: [NativeTableRowDescriptor]
    let tableSnapshot: ResultTableSnapshot
    let searchError: String

    func column(for key: WordColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func columnTitle(for key: WordColumnKey, mode: AppLanguageMode) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title(in: mode))
    }
}
