import Foundation

struct CollocateRunConfiguration: Equatable {
    let query: String
    let searchOptions: SearchOptionsState
    let leftWindow: Int
    let rightWindow: Int
    let minFreq: Int
}

@MainActor
final class CollocatePageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisStateApplying, AnalysisSceneBuildRevisionControlling {
    static let defaultVisibleColumns: Set<CollocateColumnKey> = [.word, .total, .logDice, .rate]
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
    @Published var minFreq = "1" {
        didSet {
            guard oldValue != minFreq else { return }
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
    @Published var scene: CollocateSceneModel?
    @Published var selectedRowID: String?

    var onInputChange: (() -> Void)?
    let sceneBuilder: CollocateSceneBuilder
    var result: CollocateResult?
    var sortMode: CollocateSortMode = .logDiceDescending
    var pageSize: CollocatePageSize = .fifty
    var currentPage = 1
    var visibleColumns: Set<CollocateColumnKey> = CollocatePageViewModel.defaultVisibleColumns
    var annotationState = WorkspaceAnnotationState.default
    var focusMetric: CollocateAssociationMetric = .logDice
    var lastRunConfiguration: CollocateRunConfiguration?
    var sceneBuildRevision = 0
    var cachedFilteredRows: [CollocateRow]?
    var cachedStopwordFilter = StopwordFilterState.default
    var cachedSortedRows: [CollocateRow]?
    var cachedSortMode: CollocateSortMode?

    init(sceneBuilder: CollocateSceneBuilder = CollocateSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var normalizedKeyword: String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var leftWindowValue: Int {
        Int(leftWindow) ?? 5
    }

    var rightWindowValue: Int {
        Int(rightWindow) ?? 5
    }

    var minFreqValue: Int {
        Int(minFreq) ?? 1
    }

    var focusMetricValue: CollocateAssociationMetric {
        focusMetric
    }

    var hasPendingRunChanges: Bool {
        guard let lastRunConfiguration else { return false }
        return lastRunConfiguration.query != normalizedKeyword
            || lastRunConfiguration.leftWindow != leftWindowValue
            || lastRunConfiguration.rightWindow != rightWindowValue
            || lastRunConfiguration.minFreq != minFreqValue
            || lastRunConfiguration.searchOptions != searchOptions
    }

    var selectedSceneRow: CollocateSceneRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.rows.first
    }

    func applyWorkspaceAnnotationState(_ state: WorkspaceAnnotationState) {
        guard annotationState != state else { return }
        annotationState = state
        rebuildScene()
    }
}
