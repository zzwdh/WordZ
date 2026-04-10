import Foundation

@MainActor
final class WordPageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisStateApplying, AnalysisSceneBuildRevisionControlling {
    static let defaultVisibleColumns: Set<WordColumnKey> = [.word, .count, .normFrequency, .range]
    var isApplyingState = false
    var isApplyingInputState: Bool { isApplyingState }
    var isApplyingStateFlag: Bool {
        get { isApplyingState }
        set { isApplyingState = newValue }
    }

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
    @Published var isEditingStopwords = false
    @Published var scene: WordSceneModel?

    var onInputChange: (() -> Void)?
    var onSceneChange: (() -> Void)?
    var metricDefinition: FrequencyMetricDefinition { definition }

    let sceneBuilder: WordSceneBuilder
    var result: StatsResult?
    var sortMode: WordSortMode = .frequencyDescending
    var pageSize: WordPageSize = .oneHundred
    var currentPage = 1
    var visibleColumns: Set<WordColumnKey> = WordPageViewModel.defaultVisibleColumns
    var definition = FrequencyMetricDefinition.default
    var cachedDisplayableRows: [FrequencyRow]?
    var cachedFilteredRows: [FrequencyRow]?
    var cachedFilteredError = ""
    var cachedFilterQuery = ""
    var cachedFilterOptions = SearchOptionsState.default
    var cachedStopwordFilter = StopwordFilterState.default
    var cachedSortedRows: [FrequencyRow]?
    var cachedSortMode: WordSortMode?
    var cachedDefinition: FrequencyMetricDefinition?
    var sceneBuildRevision = 0
    var resultGeneration = 0
    var sceneResultGeneration = 0

    init(sceneBuilder: WordSceneBuilder = WordSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }
}
