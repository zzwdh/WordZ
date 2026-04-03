import Foundation

enum TokenizeSortMode: String, CaseIterable, Identifiable {
    case sequenceAscending
    case sequenceDescending
    case originalAscending
    case originalDescending
    case normalizedAscending
    case normalizedDescending

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .sequenceAscending:
            return wordZText("按顺序升序", "Sequence Ascending", mode: mode)
        case .sequenceDescending:
            return wordZText("按顺序降序", "Sequence Descending", mode: mode)
        case .originalAscending:
            return wordZText("原词升序", "Original Ascending", mode: mode)
        case .originalDescending:
            return wordZText("原词降序", "Original Descending", mode: mode)
        case .normalizedAscending:
            return wordZText("规范词升序", "Normalized Ascending", mode: mode)
        case .normalizedDescending:
            return wordZText("规范词降序", "Normalized Descending", mode: mode)
        }
    }
}

enum TokenizePageSize: Int, CaseIterable, Identifiable {
    case fifty = 50
    case oneHundred = 100
    case twoHundredFifty = 250
    case all = -1

    var id: Int { rawValue }

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

enum TokenizeColumnKey: String, CaseIterable, Identifiable, Hashable {
    case sentence
    case position
    case original
    case normalized

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .sentence:
            return wordZText("句号", "Sentence", mode: mode)
        case .position:
            return wordZText("位置", "Position", mode: mode)
        case .original:
            return wordZText("原词", "Original", mode: mode)
        case .normalized:
            return wordZText("规范词", "Normalized", mode: mode)
        }
    }
}

struct TokenizeMetricSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let value: String
}

struct TokenizeSceneRow: Identifiable, Equatable {
    let id: String
    let sentenceText: String
    let sentenceLabel: String
    let positionLabel: String
    let original: String
    let normalized: String
}

struct TokenizeSortingSceneModel: Equatable {
    let selectedSort: TokenizeSortMode
    let selectedPageSize: TokenizePageSize
}

struct TokenizeSceneModel: Equatable {
    let query: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let metrics: [TokenizeMetricSceneItem]
    let sorting: TokenizeSortingSceneModel
    let pagination: ResultPaginationSceneModel
    let table: NativeTableDescriptor
    let totalTokens: Int
    let filteredTokens: Int
    let visibleTokens: Int
    let totalSentences: Int
    let visibleSentences: Int
    let rows: [TokenizeSceneRow]
    let tableRows: [NativeTableRowDescriptor]
    let searchError: String
    let exportDocument: PlainTextExportDocument?

    func column(for key: TokenizeColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func columnTitle(for key: TokenizeColumnKey, mode: AppLanguageMode) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title(in: mode))
    }
}
