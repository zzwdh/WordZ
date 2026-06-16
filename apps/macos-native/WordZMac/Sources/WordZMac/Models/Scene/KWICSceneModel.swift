import Foundation
import WordZExport
import WordZShared

enum KWICSortMode: String, CaseIterable, Identifiable {
    case original
    case rightOneAscending
    case rightTwoAscending
    case rightThreeAscending
    case leftOneAscending
    case leftTwoAscending
    case leftThreeAscending
    case keywordAscending
    case sentenceAscending
    case leftContextAscending
    case rightContextAscending
    case sourceAscending
    case metadataAscending

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "原始顺序"
        case .sentenceAscending:
            return "按位置"
        case .leftOneAscending:
            return "按左侧 1 词"
        case .leftTwoAscending:
            return "按左侧 2 词"
        case .leftThreeAscending:
            return "按左侧 3 词"
        case .leftContextAscending:
            return "按左上下文"
        case .keywordAscending:
            return "按节点词"
        case .rightOneAscending:
            return "按右侧 1 词"
        case .rightTwoAscending:
            return "按右侧 2 词"
        case .rightThreeAscending:
            return "按右侧 3 词"
        case .rightContextAscending:
            return "按右上下文"
        case .sourceAscending:
            return "按来源"
        case .metadataAscending:
            return "按元数据"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .original:
            return wordZText("原始顺序", "Original Order", mode: mode)
        case .sentenceAscending:
            return wordZText("按位置", "Position", mode: mode)
        case .leftOneAscending:
            return wordZText("按左侧 1 词", "Left 1", mode: mode)
        case .leftTwoAscending:
            return wordZText("按左侧 2 词", "Left 2", mode: mode)
        case .leftThreeAscending:
            return wordZText("按左侧 3 词", "Left 3", mode: mode)
        case .leftContextAscending:
            return wordZText("按完整左文", "Full Left Context", mode: mode)
        case .keywordAscending:
            return wordZText("按节点词", "Keyword", mode: mode)
        case .rightOneAscending:
            return wordZText("按右侧 1 词", "Right 1", mode: mode)
        case .rightTwoAscending:
            return wordZText("按右侧 2 词", "Right 2", mode: mode)
        case .rightThreeAscending:
            return wordZText("按右侧 3 词", "Right 3", mode: mode)
        case .rightContextAscending:
            return wordZText("按完整右文", "Full Right Context", mode: mode)
        case .sourceAscending:
            return wordZText("按来源", "Source", mode: mode)
        case .metadataAscending:
            return wordZText("按元数据", "Metadata", mode: mode)
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
    case rowNumber
    case source
    case position
    case leftContext
    case keyword
    case rightContext
    case metadata
    case sentenceIndex

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rowNumber:
            return "#"
        case .source:
            return "来源"
        case .position:
            return "位置"
        case .leftContext:
            return "左侧上下文"
        case .keyword:
            return "节点词"
        case .rightContext:
            return "右侧上下文"
        case .metadata:
            return "元数据"
        case .sentenceIndex:
            return "句号"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .rowNumber:
            return "#"
        case .source:
            return wordZText("来源", "Source", mode: mode)
        case .position:
            return wordZText("位置", "Position", mode: mode)
        case .leftContext:
            return wordZText("左侧上下文", "Left Context", mode: mode)
        case .keyword:
            return wordZText("节点词", "Keyword", mode: mode)
        case .rightContext:
            return wordZText("右侧上下文", "Right Context", mode: mode)
        case .metadata:
            return wordZText("元数据", "Metadata", mode: mode)
        case .sentenceIndex:
            return wordZText("句号", "Sentence", mode: mode)
        }
    }
}

struct KWICSceneRow: Identifiable, Equatable {
    let id: String
    let rowNumberText: String
    let sourceID: String
    let sourceTitle: String
    let sourceFilePath: String
    let sourceFileName: String
    let sourceType: String
    let sourceIndex: Int
    let sourceMetadata: CorpusMetadataProfile
    let sourceDisplayText: String
    let sourceMetadataText: String
    let positionText: String
    let leftContext: String
    let keyword: String
    let rightContext: String
    let concordanceText: String
    let citationText: String
    let sentenceIndexText: String
    let sentenceId: Int
    let sourceSentenceId: Int?
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
    let sourceFilterQuery: String
    let annotationSummary: String
    let leftWindow: Int
    let rightWindow: Int
    let sorting: KWICSortingSceneModel
    let pagination: ResultPaginationSceneModel
    let table: NativeTableDescriptor
    let totalRows: Int
    let filteredRows: Int
    let visibleRows: Int
    let rows: [KWICSceneRow]
    let tableSnapshot: ResultTableSnapshot
    let exportMetadataLines: [String]
    let searchError: String

    var tableRows: [NativeTableRowDescriptor] {
        tableSnapshot.rows
    }

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
