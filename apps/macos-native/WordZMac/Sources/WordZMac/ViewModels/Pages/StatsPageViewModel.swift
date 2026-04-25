import Foundation

@MainActor
final class StatsPageViewModel: ObservableObject, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisSceneBuildRevisionControlling {
    static let defaultVisibleColumns: Set<StatsColumnKey> = [.word, .count, .normFrequency, .range]

    @Published var scene: StatsSceneModel?

    var metricDefinition: FrequencyMetricDefinition { definition }
    var onSceneChange: (() -> Void)?

    let sceneBuilder: StatsSceneBuilder
    var result: StatsResult?
    var sortMode: StatsSortMode = .frequencyDescending
    var pageSize: StatsPageSize = .oneHundred
    var currentPage = 1
    var visibleColumns: Set<StatsColumnKey> = StatsPageViewModel.defaultVisibleColumns
    var definition = FrequencyMetricDefinition.default
    var cachedSortedRows: [FrequencyRow]?
    var cachedSortMode: StatsSortMode?
    var cachedDefinition: FrequencyMetricDefinition?
    var sceneBuildRevision = 0
    var resultGeneration = 0
    var sceneResultGeneration = 0

    init(sceneBuilder: StatsSceneBuilder = StatsSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }
}
