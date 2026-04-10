import Foundation

struct KeywordRunConfiguration: Equatable {
    let targetCorpusID: String?
    let referenceCorpusID: String?
    let options: KeywordPreprocessingOptions
}

@MainActor
final class KeywordPageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisStateApplying, AnalysisSceneBuildRevisionControlling, AnalysisSelectedRowControlling {
    static let defaultVisibleColumns: Set<KeywordColumnKey> = [
        .rank, .word, .targetFrequency, .referenceFrequency, .targetNormFrequency, .referenceNormFrequency, .score
    ]

    var isApplyingState = false
    var sceneBuildRevision = 0
    var isApplyingInputState: Bool { isApplyingState }
    var isApplyingStateFlag: Bool {
        get { isApplyingState }
        set { isApplyingState = newValue }
    }

    @Published var lowercased = true {
        didSet {
            guard oldValue != lowercased else { return }
            handleInputChange()
        }
    }
    @Published var removePunctuation = true {
        didSet {
            guard oldValue != removePunctuation else { return }
            handleInputChange()
        }
    }
    @Published var minimumFrequency = "2" {
        didSet {
            guard oldValue != minimumFrequency else { return }
            handleInputChange()
        }
    }
    @Published var statistic: KeywordStatisticMethod = .logLikelihood {
        didSet {
            guard oldValue != statistic else { return }
            handleInputChange()
        }
    }
    @Published var stopwordFilter = StopwordFilterState.default {
        didSet {
            guard oldValue != stopwordFilter else { return }
            handleInputChange()
        }
    }
    @Published var isEditingStopwords = false
    @Published var corpusOptions: [KeywordCorpusOptionSceneItem] = []
    @Published var scene: KeywordSceneModel?
    @Published var selectedRowID: String?

    var onInputChange: (() -> Void)?

    let sceneBuilder: KeywordSceneBuilder
    var result: KeywordResult?
    var sortMode: KeywordSortMode = .scoreDescending
    var pageSize: KeywordPageSize = .fifty
    var currentPage = 1
    var visibleColumns: Set<KeywordColumnKey> = KeywordPageViewModel.defaultVisibleColumns
    var availableCorpora: [LibraryCorpusItem] = []
    var selectedTargetCorpusID: String?
    var selectedReferenceCorpusID: String?
    var lastRunConfiguration: KeywordRunConfiguration?
    var cachedSortedRows: [KeywordResultRow]?
    var cachedSortMode: KeywordSortMode?

    init(sceneBuilder: KeywordSceneBuilder = KeywordSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var canRun: Bool {
        guard let selectedTargetCorpusID, let selectedReferenceCorpusID else { return false }
        return selectedTargetCorpusID != selectedReferenceCorpusID
    }

    var targetCorpusIDSnapshot: String {
        selectedTargetCorpusID ?? ""
    }

    var referenceCorpusIDSnapshot: String {
        selectedReferenceCorpusID ?? ""
    }

    var minimumFrequencyValue: Int {
        max(1, Int(minimumFrequency) ?? 2)
    }

    var preprocessingOptions: KeywordPreprocessingOptions {
        KeywordPreprocessingOptions(
            lowercased: lowercased,
            removePunctuation: removePunctuation,
            stopwordFilter: stopwordFilter,
            minimumFrequency: minimumFrequencyValue,
            statistic: statistic
        )
    }

    var hasPendingRunChanges: Bool {
        guard let lastRunConfiguration else { return false }
        return lastRunConfiguration != currentRunConfiguration
    }

    var selectedSceneRow: KeywordSceneRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.rows.first
    }

    func selectedTargetCorpusItem() -> LibraryCorpusItem? {
        guard let selectedTargetCorpusID else { return nil }
        return availableCorpora.first(where: { $0.id == selectedTargetCorpusID })
    }

    func selectedReferenceCorpusItem() -> LibraryCorpusItem? {
        guard let selectedReferenceCorpusID else { return nil }
        return availableCorpora.first(where: { $0.id == selectedReferenceCorpusID })
    }
}
