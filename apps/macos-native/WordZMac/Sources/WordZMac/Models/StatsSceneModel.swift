import Foundation

enum StatsSortMode: String, CaseIterable, Identifiable {
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

enum StatsPageSize: Int, CaseIterable, Identifiable {
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

enum StatsColumnKey: String, CaseIterable, Identifiable, Hashable {
    case word
    case count

    var id: String { rawValue }

    var title: String {
        switch self {
        case .word:
            return "词"
        case .count:
            return "频次"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .word:
            return wordZText("词", "Word", mode: mode)
        case .count:
            return wordZText("频次", "Count", mode: mode)
        }
    }
}

struct StatsMetricSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
}

struct StatsFrequencySceneRow: Identifiable, Equatable {
    let id: String
    let word: String
    let countText: String
}

struct StatsSortingSceneModel: Equatable {
    let selectedSort: StatsSortMode
    let selectedPageSize: StatsPageSize
}

struct StatsSceneModel: Equatable {
    let metrics: [StatsMetricSceneItem]
    let rows: [StatsFrequencySceneRow]
    let tableRows: [NativeTableRowDescriptor]
    let sorting: StatsSortingSceneModel
    let pagination: ResultPaginationSceneModel
    let table: NativeTableDescriptor
    let totalRows: Int
    let visibleRows: Int

    func column(for key: StatsColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func isColumnVisible(_ key: StatsColumnKey) -> Bool {
        table.isVisible(key.rawValue)
    }

    func columnTitle(for key: StatsColumnKey, mode: AppLanguageMode) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title(in: mode))
    }

    func columnTitle(for key: StatsColumnKey) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title)
    }
}
