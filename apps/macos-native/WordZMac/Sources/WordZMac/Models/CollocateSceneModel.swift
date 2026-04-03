import Foundation

enum CollocateAssociationMetric: String, CaseIterable, Identifiable {
    case logDice
    case mutualInformation
    case tScore
    case rate
    case frequency

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .logDice:
            return wordZText("LogDice", "LogDice", mode: mode)
        case .mutualInformation:
            return wordZText("MI", "MI", mode: mode)
        case .tScore:
            return wordZText("T-Score", "T-Score", mode: mode)
        case .rate:
            return wordZText("共现率", "Rate", mode: mode)
        case .frequency:
            return wordZText("共现频次", "Co-occurrence Frequency", mode: mode)
        }
    }

    func summary(in mode: AppLanguageMode) -> String {
        switch self {
        case .logDice:
            return wordZText("LogDice 对高频词更稳健，适合默认探索搭配。", "LogDice is robust for higher-frequency words and works well as a default discovery metric.", mode: mode)
        case .mutualInformation:
            return wordZText("MI 更强调强关联，但会偏爱低频稀有搭配。", "MI emphasizes exclusivity, but it can favor rare low-frequency collocates.", mode: mode)
        case .tScore:
            return wordZText("T-Score 更偏向稳定、可重复出现的高频搭配。", "T-Score favors stable, repeatedly attested higher-frequency collocates.", mode: mode)
        case .rate:
            return wordZText("共现率便于快速查看节点词周围最常见的邻接词。", "Rate is helpful for a quick view of the most common neighbors around the keyword.", mode: mode)
        case .frequency:
            return wordZText("共现频次适合先做粗排，再结合关联度指标判断。", "Raw co-occurrence frequency is useful for coarse ranking before checking association measures.", mode: mode)
        }
    }
}

enum CollocatePreset: String, CaseIterable, Identifiable {
    case balanced
    case broadDiscovery
    case strictAssociation

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .balanced:
            return wordZText("平衡探索", "Balanced", mode: mode)
        case .broadDiscovery:
            return wordZText("广泛发现", "Broad", mode: mode)
        case .strictAssociation:
            return wordZText("严格关联", "Strict", mode: mode)
        }
    }

    func summary(in mode: AppLanguageMode) -> String {
        switch self {
        case .balanced:
            return wordZText("L5 / R5，最低频次 2，默认看 LogDice。", "L5 / R5, min freq 2, focused on LogDice.", mode: mode)
        case .broadDiscovery:
            return wordZText("L7 / R7，最低频次 1，适合先看共现频次。", "L7 / R7, min freq 1, useful for broad frequency-led discovery.", mode: mode)
        case .strictAssociation:
            return wordZText("L4 / R4，最低频次 3，适合优先看 MI。", "L4 / R4, min freq 3, useful when prioritizing MI.", mode: mode)
        }
    }

    var configuration: (leftWindow: String, rightWindow: String, minFreq: String, metric: CollocateAssociationMetric) {
        switch self {
        case .balanced:
            return ("5", "5", "2", .logDice)
        case .broadDiscovery:
            return ("7", "7", "1", .frequency)
        case .strictAssociation:
            return ("4", "4", "3", .mutualInformation)
        }
    }
}

enum CollocateSortMode: String, CaseIterable, Identifiable {
    case frequencyDescending
    case frequencyAscending
    case alphabeticalAscending
    case rateDescending
    case logDiceDescending
    case mutualInformationDescending
    case tScoreDescending

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
        case .logDiceDescending:
            return "LogDice 降序"
        case .mutualInformationDescending:
            return "MI 降序"
        case .tScoreDescending:
            return "T-Score 降序"
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
        case .logDiceDescending:
            return wordZText("LogDice 降序", "LogDice Descending", mode: mode)
        case .mutualInformationDescending:
            return wordZText("MI 降序", "MI Descending", mode: mode)
        case .tScoreDescending:
            return wordZText("T-Score 降序", "T-Score Descending", mode: mode)
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
    case logDice
    case mutualInformation
    case tScore

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
        case .logDice:
            return "LogDice"
        case .mutualInformation:
            return "MI"
        case .tScore:
            return "T-Score"
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
        case .logDice:
            return "LogDice"
        case .mutualInformation:
            return "MI"
        case .tScore:
            return "T-Score"
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
    let logDiceText: String
    let mutualInformationText: String
    let tScoreText: String
}

struct CollocateSortingSceneModel: Equatable {
    let selectedSort: CollocateSortMode
    let selectedPageSize: CollocatePageSize
}

struct CollocateSceneModel: Equatable {
    let query: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let focusMetric: CollocateAssociationMetric
    let focusMetricSummary: String
    let methodNotes: [String]
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
    let exportMetadataLines: [String]
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
