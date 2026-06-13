import Foundation

enum PlotColumnKey: String, CaseIterable, Identifiable, Hashable {
    case row
    case fileID
    case filePath
    case fileTokens
    case frequency
    case normalizedFrequency
    case plot

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .row:
            return wordZText("行", "Row", mode: mode)
        case .fileID:
            return wordZText("文件", "File", mode: mode)
        case .filePath:
            return wordZText("文件路径", "File Path", mode: mode)
        case .fileTokens:
            return wordZText("文件词数", "File Tokens", mode: mode)
        case .frequency:
            return wordZText("频次", "Frequency", mode: mode)
        case .normalizedFrequency:
            return wordZText("标准频次", "Normalized Frequency", mode: mode)
        case .plot:
            return wordZText("分布", "Plot", mode: mode)
        }
    }
}

struct PlotSceneMarker: Identifiable, Equatable {
    let id: String
    let sentenceId: Int
    let tokenIndex: Int
    let normalizedPosition: Double
}

struct PlotSceneRow: Identifiable, Equatable {
    let id: String
    let corpusId: String
    let rowNumber: Int
    let fileID: Int
    let filePath: String
    let displayName: String
    let fileTokens: Int
    let frequency: Int
    let normalizedFrequency: Double
    let normalizedFrequencyText: String
    let plotText: String
    let markers: [PlotSceneMarker]

    var displayPath: String {
        filePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? displayName : filePath
    }
}

struct PlotSceneModel: Equatable {
    let query: String
    let searchOptions: SearchOptionsState
    let scope: PlotScopeResolution
    let totalHits: Int
    let totalFilesWithHits: Int
    let totalFiles: Int
    let selectedRowID: String?
    let selectedMarkerID: String?
    let rows: [PlotSceneRow]
    let table: NativeTableDescriptor
    let tableRows: [NativeTableRowDescriptor]
    let tableSnapshot: ResultTableSnapshot
    let exportMetadataLines: [String]

    func column(for key: PlotColumnKey) -> NativeTableColumnDescriptor? {
        table.column(id: key.rawValue)
    }

    func columnTitle(for key: PlotColumnKey, mode: AppLanguageMode) -> String {
        table.displayTitle(for: key.rawValue, fallback: key.title(in: mode))
    }
}
