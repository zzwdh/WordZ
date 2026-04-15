import Foundation

struct SentimentSelectableCorpusSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let isSelected: Bool
}

struct SentimentReferenceOptionSceneItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
}

@MainActor
final class SentimentPageViewModel: ObservableObject, AnalysisInputStateControlling, AnalysisColumnVisibilityControlling, AnalysisPagingControlling, AnalysisSortingControlling, AnalysisSelectedRowControlling {
    typealias AnalysisPageSize = SentimentPageSize
    typealias AnalysisSortMode = SentimentSortMode

    static let defaultVisibleColumns: Set<SentimentColumnKey> = [
        .source, .text, .positivity, .neutrality, .negativity, .finalLabel
    ]

    var isApplyingState = false
    var isApplyingInputState: Bool { isApplyingState }

    @Published var source: SentimentInputSource = .openedCorpus {
        didSet {
            guard oldValue != source else { return }
            clampUnitForSource()
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var unit: SentimentAnalysisUnit = .sentence {
        didSet {
            guard oldValue != unit else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var contextBasis: SentimentContextBasis = .visibleContext {
        didSet {
            guard oldValue != contextBasis else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var backend: SentimentBackendKind = .lexicon {
        didSet {
            guard oldValue != backend else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var chartKind: SentimentChartKind = .distributionBar {
        didSet {
            guard oldValue != chartKind else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var thresholdPreset: SentimentThresholdPreset = .conservative {
        didSet {
            guard oldValue != thresholdPreset else { return }
            if thresholdPreset != .custom {
                applyThresholds(thresholdPreset.thresholds, rebuildScene: true)
            }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var decisionThreshold: Double = SentimentThresholds.default.decisionThreshold {
        didSet {
            guard oldValue != decisionThreshold else { return }
            markThresholdsCustom()
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var minimumEvidence: Double = SentimentThresholds.default.minimumEvidence {
        didSet {
            guard oldValue != minimumEvidence else { return }
            markThresholdsCustom()
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var neutralBias: Double = SentimentThresholds.default.neutralBias {
        didSet {
            guard oldValue != neutralBias else { return }
            markThresholdsCustom()
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var rowFilterQuery = "" {
        didSet {
            guard oldValue != rowFilterQuery else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var labelFilter: SentimentLabel? {
        didSet {
            guard oldValue != labelFilter else { return }
            handleInputChange(rebuildScene: true)
        }
    }
    @Published var manualText = "" {
        didSet {
            guard oldValue != manualText else { return }
            handleInputChange(rebuildScene: false)
        }
    }
    @Published var selectionItems: [SentimentSelectableCorpusSceneItem] = []
    @Published var referenceOptions: [SentimentReferenceOptionSceneItem] = []
    @Published var scene: SentimentSceneModel?
    @Published var selectedRowID: String?
    @Published var backendNotice: String?

    var onInputChange: (() -> Void)?
    let sceneBuilder: SentimentSceneBuilder
    let availableBackendProvider: () -> [SentimentBackendKind]
    var result: SentimentRunResult?
    var sortMode: SentimentSortMode = .original
    var pageSize: SentimentPageSize = .fifty
    var currentPage = 1
    var visibleColumns: Set<SentimentColumnKey> = SentimentPageViewModel.defaultVisibleColumns
    var availableCorpora: [LibraryCorpusItem] = []
    var availableBackends: [SentimentBackendKind]
    var selectedCorpusIDs: Set<String> = []
    var selectedReferenceCorpusID = ""

    init(
        sceneBuilder: SentimentSceneBuilder = SentimentSceneBuilder(),
        availableBackendProvider: @escaping () -> [SentimentBackendKind] = {
            SentimentBackendCatalog.availableBackends()
        }
    ) {
        self.sceneBuilder = sceneBuilder
        self.availableBackendProvider = availableBackendProvider
        self.availableBackends = availableBackendProvider()
    }

    var currentResultRowCountForPaging: Int? {
        scene?.filteredRows ?? result?.rows.count
    }

    var supportedUnits: [SentimentAnalysisUnit] {
        switch source {
        case .kwicVisible:
            return [.concordanceLine]
        default:
            return [.document, .sentence]
        }
    }

    var thresholds: SentimentThresholds {
        SentimentThresholds(
            decisionThreshold: decisionThreshold,
            minimumEvidence: minimumEvidence,
            neutralBias: neutralBias
        )
    }

    var showsBackendPicker: Bool {
        availableBackends.count > 1
    }

    var selectedSceneRow: SentimentSceneRow? {
        guard let scene else { return nil }
        if let selectedRowID,
           let row = scene.rows.first(where: { $0.id == selectedRowID }) {
            return row
        }
        return scene.rows.first
    }

    var manualTextCharacterCount: Int {
        manualText.count
    }

    var manualTextSentenceCountEstimate: Int {
        let count = manualText.filter { [".", "!", "?"].contains($0) }.count
        return max(count, manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1)
    }

    func canRun(hasOpenedCorpus: Bool, hasKWICRows: Bool) -> Bool {
        switch source {
        case .openedCorpus:
            return hasOpenedCorpus
        case .pastedText:
            return !manualText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .kwicVisible:
            return hasKWICRows
        case .corpusCompare:
            return !selectedTargetCorpusItems().isEmpty
        }
    }

    func selectedTargetCorpusItems() -> [LibraryCorpusItem] {
        availableCorpora.filter {
            selectedCorpusIDs.contains($0.id) && $0.id != selectedReferenceCorpusID
        }
    }

    func selectedReferenceCorpusItem() -> LibraryCorpusItem? {
        guard !selectedReferenceCorpusID.isEmpty else { return nil }
        return availableCorpora.first(where: { $0.id == selectedReferenceCorpusID })
    }

    func currentRunRequest(texts: [SentimentInputText]) -> SentimentRunRequest {
        SentimentRunRequest(
            source: source,
            unit: unit,
            contextBasis: contextBasis,
            thresholds: thresholds,
            texts: texts,
            backend: backend
        )
    }

    func syncLibrarySnapshot(_ snapshot: LibrarySnapshot) {
        refreshAvailableBackends()
        availableCorpora = snapshot.corpora
        let validIDs = Set(snapshot.corpora.map(\.id))
        selectedCorpusIDs = selectedCorpusIDs.intersection(validIDs)
        if !selectedReferenceCorpusID.isEmpty, !validIDs.contains(selectedReferenceCorpusID) {
            selectedReferenceCorpusID = ""
        }
        if selectedCorpusIDs.isEmpty, let firstCorpus = snapshot.corpora.first {
            selectedCorpusIDs.insert(firstCorpus.id)
        }
        rebuildCorpusOptions()
        rebuildScene()
    }

    func handle(_ action: SentimentPageAction) {
        switch action {
        case .run, .exportSummary, .exportStructuredJSON:
            return
        case .changeSource(let nextSource):
            source = nextSource
        case .changeUnit(let nextUnit):
            unit = nextUnit
        case .changeContextBasis(let nextBasis):
            contextBasis = nextBasis
        case .changeBackend(let nextBackend):
            backend = normalizedBackend(nextBackend)
        case .changeChartKind(let nextKind):
            chartKind = nextKind
        case .changeThresholdPreset(let nextPreset):
            thresholdPreset = nextPreset
        case .changeDecisionThreshold(let value):
            decisionThreshold = value
        case .changeMinimumEvidence(let value):
            minimumEvidence = value
        case .changeNeutralBias(let value):
            neutralBias = value
        case .changeFilterQuery(let value):
            rowFilterQuery = value
        case .changeLabelFilter(let nextFilter):
            labelFilter = nextFilter
        case .changeSort(let nextSort):
            applySortModeChange(nextSort)
        case .sortByColumn(let column):
            sortByColumn(column)
        case .changePageSize(let nextPageSize):
            applyPageSizeChange(nextPageSize)
        case .toggleColumn(let column):
            toggleVisibleColumnAndRebuild(column)
        case .selectRow(let rowID):
            selectedRowID = rowID
            rebuildScene()
        case .changeManualText(let text):
            manualText = text
        case .toggleCorpusSelection(let corpusID):
            if selectedCorpusIDs.contains(corpusID) {
                selectedCorpusIDs.remove(corpusID)
            } else {
                selectedCorpusIDs.insert(corpusID)
            }
            rebuildCorpusOptions()
            handleInputChange(rebuildScene: false)
        case .changeReferenceCorpus(let corpusID):
            selectedReferenceCorpusID = corpusID ?? ""
            rebuildCorpusOptions()
            handleInputChange(rebuildScene: false)
        }
    }

    func rebuildScene() {
        guard let result else {
            scene = nil
            return
        }
        let rowsForSelection = result.rows.filter { row in
            (labelFilter == nil || row.finalLabel == labelFilter) &&
                (rowFilterQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                 row.text.localizedCaseInsensitiveContains(rowFilterQuery))
        }
        syncSelectedRow(within: rowsForSelection)
        scene = sceneBuilder.build(
            from: result,
            thresholdPreset: thresholdPreset,
            filterQuery: rowFilterQuery,
            labelFilter: labelFilter,
            sortMode: sortMode,
            pageSize: pageSize,
            currentPage: currentPage,
            visibleColumns: visibleColumns,
            selectedRowID: selectedRowID,
            chartKind: chartKind,
            languageMode: WordZLocalization.shared.effectiveMode
        )
        currentPage = scene?.pagination.currentPage ?? 1
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary) {
        isApplyingState = true
        defer {
            isApplyingState = false
            refreshAvailableBackends()
            clampUnitForSource()
            rebuildCorpusOptions()
            rebuildScene()
        }

        source = snapshot.sentimentSource
        unit = snapshot.sentimentUnit
        contextBasis = snapshot.sentimentContextBasis
        backend = normalizedBackend(snapshot.sentimentBackend)
        chartKind = snapshot.sentimentChartKind
        thresholdPreset = snapshot.sentimentThresholdPreset
        decisionThreshold = snapshot.sentimentDecisionThreshold
        minimumEvidence = snapshot.sentimentMinimumEvidence
        neutralBias = snapshot.sentimentNeutralBias
        rowFilterQuery = snapshot.sentimentRowFilterQuery
        labelFilter = snapshot.sentimentLabelFilter
        let snapshotSelection = Set(snapshot.sentimentSelectedCorpusIDs)
        if !snapshotSelection.isEmpty {
            selectedCorpusIDs = snapshotSelection
        }
        selectedReferenceCorpusID = snapshot.sentimentReferenceCorpusID
    }

    func apply(_ result: SentimentRunResult) {
        isApplyingState = true
        defer {
            isApplyingState = false
            refreshAvailableBackends()
            rebuildScene()
        }
        self.result = result
        source = result.request.source
        unit = result.request.unit
        contextBasis = result.request.contextBasis
        backend = normalizedBackend(result.backendKind)
        if result.request.backend != result.backendKind {
            backendNotice = wordZText(
                "当前所选模型后端不可用，已自动回退到词典规则后端。",
                "The requested model backend is unavailable, so WordZ fell back to the lexicon backend.",
                mode: .system
            )
        } else {
            backendNotice = nil
        }
        applyThresholds(result.request.thresholds, rebuildScene: false)
        currentPage = 1
        selectedRowID = result.rows.first?.id
    }

    func reset() {
        isApplyingState = true
        defer { isApplyingState = false }
        source = .openedCorpus
        unit = .sentence
        contextBasis = .visibleContext
        backend = .lexicon
        chartKind = .distributionBar
        thresholdPreset = .conservative
        applyThresholds(.default, rebuildScene: false)
        rowFilterQuery = ""
        labelFilter = nil
        manualText = ""
        sortMode = .original
        pageSize = .fifty
        currentPage = 1
        visibleColumns = Self.defaultVisibleColumns
        selectedRowID = nil
        result = nil
        scene = nil
        backendNotice = nil
        selectedReferenceCorpusID = ""
        selectedCorpusIDs = selectedCorpusIDs.isEmpty ? [] : selectedCorpusIDs
        refreshAvailableBackends()
        rebuildCorpusOptions()
    }

    private func rebuildCorpusOptions() {
        selectionItems = availableCorpora.map { corpus in
            SentimentSelectableCorpusSceneItem(
                id: corpus.id,
                title: corpus.name,
                subtitle: corpus.folderName,
                isSelected: selectedCorpusIDs.contains(corpus.id)
            )
        }
        referenceOptions = availableCorpora
            .filter { !selectedCorpusIDs.contains($0.id) || $0.id == selectedReferenceCorpusID }
            .map {
                SentimentReferenceOptionSceneItem(
                    id: $0.id,
                    title: $0.name,
                    subtitle: $0.folderName
                )
            }
        if !selectedReferenceCorpusID.isEmpty,
           !referenceOptions.contains(where: { $0.id == selectedReferenceCorpusID }) {
            selectedReferenceCorpusID = ""
        }
    }

    private func clampUnitForSource() {
        if !supportedUnits.contains(unit) {
            unit = supportedUnits.first ?? .sentence
        }
    }

    private func refreshAvailableBackends() {
        availableBackends = availableBackendProvider()
        backend = normalizedBackend(backend)
    }

    private func normalizedBackend(_ candidate: SentimentBackendKind) -> SentimentBackendKind {
        if availableBackends.contains(candidate) {
            return candidate
        }
        if candidate == .coreML {
            backendNotice = wordZText(
                "本机当前没有可用的本地情感模型，已使用词典规则后端。",
                "No local sentiment model is currently available, so WordZ is using the lexicon backend.",
                mode: .system
            )
        }
        return .lexicon
    }

    private func handleInputChange(rebuildScene shouldRebuildScene: Bool) {
        propagateInputChange(rebuildScene: shouldRebuildScene) {
            rebuildScene()
        }
    }

    private func sortByColumn(_ column: SentimentColumnKey) {
        let nextSort: SentimentSortMode
        switch column {
        case .positivity:
            nextSort = .positivityDescending
        case .neutrality:
            nextSort = .neutralityDescending
        case .negativity:
            nextSort = .negativityDescending
        case .netScore:
            nextSort = .netScoreDescending
        case .finalLabel:
            nextSort = .labelAscending
        case .source:
            nextSort = .sourceAscending
        case .text, .evidence:
            nextSort = .original
        }
        applySortModeChange(nextSort)
    }

    private func markThresholdsCustom() {
        guard !isApplyingState else { return }
        if thresholdPreset != .custom,
           thresholds != thresholdPreset.thresholds {
            thresholdPreset = .custom
        }
    }

    private func applyThresholds(_ thresholds: SentimentThresholds, rebuildScene: Bool) {
        decisionThreshold = thresholds.decisionThreshold
        minimumEvidence = thresholds.minimumEvidence
        neutralBias = thresholds.neutralBias
        if rebuildScene {
            self.rebuildScene()
        }
    }
}
