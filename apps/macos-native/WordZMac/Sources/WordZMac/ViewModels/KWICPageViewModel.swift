import Foundation

@MainActor
final class KWICPageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisStateApplying, AnalysisSelectedRowControlling, AnalysisSceneBuildRevisionControlling {
    static let defaultVisibleColumns: Set<KWICColumnKey> = [.leftContext, .keyword, .rightContext]
    var isApplyingState = false
    var isApplyingInputState: Bool { isApplyingState }
    var isApplyingStateFlag: Bool {
        get { isApplyingState }
        set { isApplyingState = newValue }
    }

    @Published var keyword = "" {
        didSet {
            guard oldValue != keyword else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var leftWindow = "5" {
        didSet {
            guard oldValue != leftWindow else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var rightWindow = "5" {
        didSet {
            guard oldValue != rightWindow else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var searchOptions = SearchOptionsState.default {
        didSet {
            guard oldValue != searchOptions else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var stopwordFilter = StopwordFilterState.default {
        didSet {
            guard oldValue != stopwordFilter else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var isEditingStopwords = false
    @Published var scene: KWICSceneModel?
    @Published var selectedRowID: String?

    var onInputChange: (() -> Void)?
    let sceneBuilder: KWICSceneBuilder
    var result: KWICResult?
    var sortMode: KWICSortMode = .original
    var pageSize: KWICPageSize = .fifty
    var currentPage = 1
    var visibleColumns: Set<KWICColumnKey> = KWICPageViewModel.defaultVisibleColumns
    var sceneBuildRevision = 0
    var cachedFilteredRows: [KWICRow]?
    var cachedStopwordFilter = StopwordFilterState.default
    var cachedSortedRows: [KWICRow]?
    var cachedSortMode: KWICSortMode?

    init(sceneBuilder: KWICSceneBuilder = KWICSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var normalizedKeyword: String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var primaryLocatorSource: LocatorSource? {
        guard let row = selectedSceneRow ?? scene?.rows.first else { return nil }
        return LocatorSource(
            keyword: row.keyword.isEmpty ? normalizedKeyword : row.keyword,
            sentenceId: row.sentenceId,
            nodeIndex: row.sentenceTokenIndex
        )
    }

    var selectedSceneRow: KWICSceneRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.rows.first
    }

    var leftWindowValue: Int {
        Int(leftWindow) ?? 5
    }

    var rightWindowValue: Int {
        Int(rightWindow) ?? 5
    }
}
