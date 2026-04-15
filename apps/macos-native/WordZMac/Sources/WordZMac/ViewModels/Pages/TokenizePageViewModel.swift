import Foundation

@MainActor
final class TokenizePageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisStateApplying, AnalysisSelectedRowControlling, AnalysisSceneBuildRevisionControlling {
    static let defaultVisibleColumns: Set<TokenizeColumnKey> = [.sentence, .original, .normalized, .lemma]
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
    @Published var languagePreset: TokenizeLanguagePreset = .mixedChineseEnglish {
        didSet {
            guard oldValue != languagePreset else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var lemmaStrategy: TokenLemmaStrategy = .normalizedSurface {
        didSet {
            guard oldValue != lemmaStrategy else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var isEditingStopwords = false
    @Published var scene: TokenizeSceneModel?
    @Published var selectedRowID: String?

    var onInputChange: (() -> Void)?

    let sceneBuilder: TokenizeSceneBuilder
    var result: TokenizeResult?
    var sortMode: TokenizeSortMode = .sequenceAscending
    var pageSize: TokenizePageSize = .oneHundred
    var currentPage = 1
    var visibleColumns: Set<TokenizeColumnKey> = TokenizePageViewModel.defaultVisibleColumns
    var sceneBuildRevision = 0
    var cachedPresetFilteredTokens: [TokenizedToken]?
    var cachedLanguagePreset: TokenizeLanguagePreset?
    var cachedFilteredTokens: [TokenizedToken]?
    var cachedFilteredError = ""
    var cachedFilterQuery = ""
    var cachedFilterOptions = SearchOptionsState.default
    var cachedStopwordFilter = StopwordFilterState.default
    var cachedFilterLemmaStrategy = TokenLemmaStrategy.normalizedSurface
    var cachedSortedTokens: [TokenizedToken]?
    var cachedSortMode: TokenizeSortMode?
    var cachedSortLemmaStrategy = TokenLemmaStrategy.normalizedSurface

    init(sceneBuilder: TokenizeSceneBuilder = TokenizeSceneBuilder()) {
        self.sceneBuilder = sceneBuilder
    }

    var exportDocument: PlainTextExportDocument? {
        scene?.exportDocument
    }

    var selectedSceneRow: TokenizeSceneRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.rows.first
    }
}
