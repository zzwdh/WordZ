import Foundation

enum KWICSortMode: String, CaseIterable, Identifiable {
    case original
    case sentenceAscending
    case leftContextAscending
    case keywordAscending
    case rightContextAscending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "原始顺序"
        case .sentenceAscending:
            return "按句号"
        case .leftContextAscending:
            return "按左上下文"
        case .keywordAscending:
            return "按节点词"
        case .rightContextAscending:
            return "按右上下文"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .original:
            return wordZText("原始顺序", "Original Order", mode: mode)
        case .sentenceAscending:
            return wordZText("按句号", "Sentence Order", mode: mode)
        case .leftContextAscending:
            return wordZText("按左上下文", "Left Context", mode: mode)
        case .keywordAscending:
            return wordZText("按节点词", "Keyword", mode: mode)
        case .rightContextAscending:
            return wordZText("按右上下文", "Right Context", mode: mode)
        }
    }
}

enum KWICPageSize: Int, CaseIterable, Identifiable {
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

enum KWICColumnKey: String, CaseIterable, Identifiable, Hashable {
    case leftContext
    case keyword
    case rightContext
    case sentenceIndex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .leftContext:
            return "左侧上下文"
        case .keyword:
            return "节点词"
        case .rightContext:
            return "右侧上下文"
        case .sentenceIndex:
            return "句号"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .leftContext:
            return wordZText("左侧上下文", "Left Context", mode: mode)
        case .keyword:
            return wordZText("节点词", "Keyword", mode: mode)
        case .rightContext:
            return wordZText("右侧上下文", "Right Context", mode: mode)
        case .sentenceIndex:
            return wordZText("句号", "Sentence", mode: mode)
        }
    }
}

struct KWICSceneRow: Identifiable, Equatable {
    let id: String
    let leftContext: String
    let keyword: String
    let rightContext: String
    let concordanceText: String
    let citationText: String
    let sentenceIndexText: String
    let sentenceId: Int
    let sentenceTokenIndex: Int
}

struct KWICSortingSceneModel: Equatable {
    let selectedSort: KWICSortMode
    let selectedPageSize: KWICPageSize
}

struct KWICSceneModel: Equatable {
    let query: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let leftWindow: Int
    let rightWindow: Int
    let sorting: KWICSortingSceneModel
    let pagination: ResultPaginationSceneModel
    let table: NativeTableDescriptor
    let totalRows: Int
    let filteredRows: Int
    let visibleRows: Int
    let rows: [KWICSceneRow]
    let tableRows: [NativeTableRowDescriptor]
    let exportMetadataLines: [String]
    let searchError: String

    func column(for key: KWICColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func isColumnVisible(_ key: KWICColumnKey) -> Bool {
        table.isVisible(key.rawValue)
    }

    func columnTitle(for key: KWICColumnKey, mode: AppLanguageMode) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title(in: mode))
    }

    func columnTitle(for key: KWICColumnKey) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title)
    }
}
