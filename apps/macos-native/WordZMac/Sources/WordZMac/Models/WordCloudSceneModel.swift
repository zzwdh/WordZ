import Foundation

enum WordCloudColumnKey: String, CaseIterable, Identifiable, Hashable {
    case word
    case count
    case prominence

    var id: String { rawValue }

    var title: String {
        switch self {
        case .word:
            return "词"
        case .count:
            return "频次"
        case .prominence:
            return "权重"
        }
    }
}

struct WordCloudTermSceneItem: Identifiable, Equatable {
    let id: String
    let word: String
    let countText: String
    let prominenceText: String
    let fontScale: Double
    let isAccent: Bool
}

struct WordCloudSceneModel: Equatable {
    let query: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let limit: Int
    let totalRows: Int
    let filteredRows: Int
    let visibleRows: Int
    let table: NativeTableDescriptor
    let tableRows: [NativeTableRowDescriptor]
    let cloudItems: [WordCloudTermSceneItem]
    let exportMetadataLines: [String]
    let searchError: String

    func column(for key: WordCloudColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func isColumnVisible(_ key: WordCloudColumnKey) -> Bool {
        table.isVisible(key.rawValue)
    }
}
