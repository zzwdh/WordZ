import Foundation

@MainActor
final class NgramPageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisSceneBuildRevisionControlling {
    static let defaultVisibleColumns: Set<NgramColumnKey> = [.phrase, .count]
    var isApplyingState = false
    var isApplyingInputState: Bool { isApplyingState }

    @Published var query = "" {
        didSet {
            guard oldValue != query else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var searchOptions = SearchOptionsState.default {
        didSet {
            guard oldValue != searchOptions else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var stopwordFilter = StopwordFilterState.default {
        didSet {
            guard oldValue != stopwordFilter else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var ngramSize = "2" {
        didSet {
            guard oldValue != ngramSize else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var isEditingStopwords = false
    @Published var scene: NgramSceneModel?

    var onInputChange: (() -> Void)?
    let sceneBuilder: NgramSceneBuilder
    var result: NgramResult?
    var sortMode: NgramSortMode = .frequencyDescending
    var pageSize: NgramPageSize = .oneHundred
    var currentPage = 1
    var visibleColumns: Set<NgramColumnKey> = NgramPageViewModel.defaultVisibleColumns
    var sceneBuildRevision = 0
    var cachedFilteredRows: [NgramRow]?
    var cachedFilteredError = ""
    var cachedFilterQuery = ""
    var cachedFilterOptions = SearchOptionsState.default
    var cachedStopwordFilter = StopwordFilterState.default
    var cachedSortedRows: [NgramRow]?
    var cachedSortMode: NgramSortMode?

    init(sceneBuilder: NgramSceneBuilder = NgramSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var normalizedQuery: String {
        AnalysisViewModelSupport.normalizedQuery(query)
    }

    var ngramSizeValue: Int {
        max(2, Int(ngramSize) ?? 2)
    }

    var pageSizeSnapshotValue: String {
        pageSize.title
    }
}
