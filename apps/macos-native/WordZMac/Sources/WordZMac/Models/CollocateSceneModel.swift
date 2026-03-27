import Foundation

enum CollocateSortMode: String, CaseIterable, Identifiable {
    case frequencyDescending
    case frequencyAscending
    case alphabeticalAscending
    case rateDescending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frequencyDescending:
            return "共现降序"
        case .frequencyAscending:
            return "共现升序"
        case .alphabeticalAscending:
            return "按词升序"
        case .rateDescending:
            return "共现率降序"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .frequencyDescending:
            return wordZText("共现降序", "Co-occurrence Descending", mode: mode)
        case .frequencyAscending:
            return wordZText("共现升序", "Co-occurrence Ascending", mode: mode)
        case .alphabeticalAscending:
            return wordZText("按词升序", "Alphabetical Ascending", mode: mode)
        case .rateDescending:
            return wordZText("共现率降序", "Rate Descending", mode: mode)
        }
    }
}

enum CollocatePageSize: Int, CaseIterable, Identifiable {
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

enum CollocateColumnKey: String, CaseIterable, Identifiable, Hashable {
    case rank
    case word
    case total
    case left
    case right
    case wordFreq
    case keywordFreq
    case rate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rank:
            return "Rank"
        case .word:
            return "搭配词"
        case .total:
            return "FreqLR"
        case .left:
            return "FreqL"
        case .right:
            return "FreqR"
        case .wordFreq:
            return "搭配词词频"
        case .keywordFreq:
            return "节点词词频"
        case .rate:
            return "共现率"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .rank:
            return wordZText("排名", "Rank", mode: mode)
        case .word:
            return wordZText("搭配词", "Collocate", mode: mode)
        case .total:
            return "FreqLR"
        case .left:
            return "FreqL"
        case .right:
            return "FreqR"
        case .wordFreq:
            return wordZText("搭配词词频", "Collocate Frequency", mode: mode)
        case .keywordFreq:
            return wordZText("节点词词频", "Keyword Frequency", mode: mode)
        case .rate:
            return wordZText("共现率", "Rate", mode: mode)
        }
    }
}

struct CollocateSceneRow: Identifiable, Equatable {
    let id: String
    let rankText: String
    let word: String
    let totalText: String
    let leftText: String
    let rightText: String
    let wordFreqText: String
    let keywordFreqText: String
    let rateText: String
}

struct CollocateSortingSceneModel: Equatable {
    let selectedSort: CollocateSortMode
    let selectedPageSize: CollocatePageSize
}

struct CollocateSceneModel: Equatable {
    let query: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let leftWindow: Int
    let rightWindow: Int
    let minFreq: Int
    let sorting: CollocateSortingSceneModel
    let pagination: ResultPaginationSceneModel
    let table: NativeTableDescriptor
    let totalRows: Int
    let filteredRows: Int
    let visibleRows: Int
    let rows: [CollocateSceneRow]
    let tableRows: [NativeTableRowDescriptor]
    let searchError: String

    func column(for key: CollocateColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func isColumnVisible(_ key: CollocateColumnKey) -> Bool {
        table.isVisible(key.rawValue)
    }

    func columnTitle(for key: CollocateColumnKey, mode: AppLanguageMode) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title(in: mode))
    }

    func columnTitle(for key: CollocateColumnKey) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title)
    }
}
