import Foundation

enum NgramSortMode: String, CaseIterable, Identifiable {
    case frequencyDescending
    case frequencyAscending
    case alphabeticalAscending
    case alphabeticalDescending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .frequencyDescending:
            return "频次降序"
        case .frequencyAscending:
            return "频次升序"
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
        case .alphabeticalAscending:
            return wordZText("按词升序", "Alphabetical Ascending", mode: mode)
        case .alphabeticalDescending:
            return wordZText("按词降序", "Alphabetical Descending", mode: mode)
        }
    }
}

enum NgramPageSize: Int, CaseIterable, Identifiable {
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

    var rowLimit: Int? {
        self == .all ? nil : rawValue
    }
}

enum NgramColumnKey: String, CaseIterable, Identifiable, Hashable {
    case rank
    case phrase
    case count

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rank:
            return "Rank"
        case .phrase:
            return "N-Gram"
        case .count:
            return "频次"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .rank:
            return wordZText("排名", "Rank", mode: mode)
        case .phrase:
            return wordZText("N-Gram", "N-Gram", mode: mode)
        case .count:
            return wordZText("频次", "Count", mode: mode)
        }
    }
}

struct NgramSceneRow: Identifiable, Equatable {
    let id: String
    let rankText: String
    let phrase: String
    let countText: String
}

struct NgramSortingSceneModel: Equatable {
    let selectedSort: NgramSortMode
    let selectedPageSize: NgramPageSize
}

struct NgramSceneModel: Equatable {
    let query: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let n: Int
    let sorting: NgramSortingSceneModel
    let pagination: ResultPaginationSceneModel
    let table: NativeTableDescriptor
    let totalRows: Int
    let visibleRows: Int
    let filteredRows: Int
    let rows: [NgramSceneRow]
    let tableRows: [NativeTableRowDescriptor]
    let tableSnapshot: ResultTableSnapshot
    let exportMetadataLines: [String]
    let searchError: String

    func column(for key: NgramColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func isColumnVisible(_ key: NgramColumnKey) -> Bool {
        table.isVisible(key.rawValue)
    }

    func columnTitle(for key: NgramColumnKey, mode: AppLanguageMode) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title(in: mode))
    }

    func columnTitle(for key: NgramColumnKey) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title)
    }
}
