import Foundation

struct LocatorSource: Equatable {
    let keyword: String
    let sentenceId: Int
    let nodeIndex: Int
}

enum LocatorPageSize: Int, CaseIterable, Identifiable {
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

enum LocatorColumnKey: String, CaseIterable, Identifiable, Hashable {
    case sentenceId
    case status
    case leftWords
    case nodeWord
    case rightWords
    case text

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sentenceId:
            return "句号"
        case .status:
            return "状态"
        case .leftWords:
            return "左窗口"
        case .nodeWord:
            return "节点词"
        case .rightWords:
            return "右窗口"
        case .text:
            return "原句"
        }
    }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .sentenceId:
            return wordZText("句号", "Sentence", mode: mode)
        case .status:
            return wordZText("状态", "Status", mode: mode)
        case .leftWords:
            return wordZText("左窗口", "Left Window", mode: mode)
        case .nodeWord:
            return wordZText("节点词", "Node", mode: mode)
        case .rightWords:
            return wordZText("右窗口", "Right Window", mode: mode)
        case .text:
            return wordZText("原句", "Sentence Text", mode: mode)
        }
    }
}

struct LocatorSceneRow: Identifiable, Equatable {
    let id: String
    let sentenceId: Int
    let sentenceIdText: String
    let status: String
    let leftWords: String
    let nodeWord: String
    let rightWords: String
    let concordanceText: String
    let citationText: String
    let text: String
    let sourceCandidate: LocatorSource
}

struct LocatorSceneModel: Equatable {
    let source: LocatorSource
    let sentenceCount: Int
    let leftWindow: Int
    let rightWindow: Int
    let selectedPageSize: LocatorPageSize
    let pagination: ResultPaginationSceneModel
    let table: NativeTableDescriptor
    let totalRows: Int
    let visibleRows: Int
    let rows: [LocatorSceneRow]
    let tableRows: [NativeTableRowDescriptor]
    let tableSnapshot: ResultTableSnapshot

    func column(for key: LocatorColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func isColumnVisible(_ key: LocatorColumnKey) -> Bool {
        table.isVisible(key.rawValue)
    }

    func columnTitle(for key: LocatorColumnKey, mode: AppLanguageMode) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title(in: mode))
    }

    func columnTitle(for key: LocatorColumnKey) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title)
    }
}
