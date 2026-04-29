import Foundation

enum ClusterPageSize: Int, CaseIterable, Identifiable {
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

extension ClusterPageSize: InteractiveAllPageSizing {
    var isAllSelection: Bool { self == .all }

    static var safeInteractiveFallback: ClusterPageSize { .oneHundred }
}

enum ClusterColumnKey: String, CaseIterable, Identifiable, Hashable {
    case rank
    case phrase
    case n
    case frequency
    case normalizedFrequency
    case range
    case rangePercentage
    case referenceFrequency
    case referenceNormalizedFrequency
    case referenceRange
    case logRatio

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .rank:
            return wordZText("排名", "Rank", mode: mode)
        case .phrase:
            return wordZText("词串", "Cluster", mode: mode)
        case .n:
            return "N"
        case .frequency:
            return wordZText("频次", "Frequency", mode: mode)
        case .normalizedFrequency:
            return wordZText("标准化频率", "NormFreq", mode: mode)
        case .range:
            return "Range"
        case .rangePercentage:
            return "Range%"
        case .referenceFrequency:
            return wordZText("参考频次", "Ref Freq", mode: mode)
        case .referenceNormalizedFrequency:
            return wordZText("参考标准化频率", "Ref NormFreq", mode: mode)
        case .referenceRange:
            return wordZText("参考范围", "Ref Range", mode: mode)
        case .logRatio:
            return "LogRatio"
        }
    }
}

struct ClusterSceneRow: Identifiable, Equatable {
    let id: String
    let phrase: String
    let n: Int
    let frequency: Int
    let normalizedFrequency: Double
    let range: Int
    let rangePercentage: Double
    let referenceFrequency: Int?
    let referenceNormalizedFrequency: Double?
    let referenceRange: Int?
    let logRatio: Double?
}

struct ClusterSortingSceneModel: Equatable {
    let selectedSort: ClusterSortMode
    let selectedPageSize: ClusterPageSize
}

struct ClusterSceneModel: Equatable {
    let query: String
    let searchOptions: SearchOptionsState
    let stopwordFilter: StopwordFilterState
    let annotationSummary: String
    let mode: ClusterMode
    let selectedN: Int
    let minimumFrequency: Int
    let caseSensitive: Bool
    let punctuationMode: ClusterPunctuationMode
    let sorting: ClusterSortingSceneModel
    let pagination: ResultPaginationSceneModel
    let totalRows: Int
    let visibleRows: Int
    let filteredRows: Int
    let selectedRowID: String?
    let rows: [ClusterSceneRow]
    let table: NativeTableDescriptor
    let tableRows: [NativeTableRowDescriptor]
    let tableSnapshot: ResultTableSnapshot
    let exportMetadataLines: [String]
    let searchError: String

    func column(for key: ClusterColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func columnTitle(for key: ClusterColumnKey, mode: AppLanguageMode) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title(in: mode))
    }
}
