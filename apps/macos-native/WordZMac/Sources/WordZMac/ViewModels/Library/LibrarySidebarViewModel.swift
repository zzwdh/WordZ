import Foundation

@MainActor
final class LibrarySidebarViewModel: ObservableObject {
    @Published var librarySnapshot = LibrarySnapshot.empty {
        didSet {
            if let selectedCorpusSetID, !librarySnapshot.corpusSets.contains(where: { $0.id == selectedCorpusSetID }) {
                self.selectedCorpusSetID = nil
            }
            _ = normalizeSelectionForCurrentFilters()
            syncScene()
        }
    }
    @Published var selectedCorpusSetID: String? {
        didSet { syncScene() }
    }
    @Published var selectedCorpusID: String? {
        didSet {
            guard oldValue != selectedCorpusID else { return }
            syncScene()
            onSelectionStateChange?()
            if !isApplyingMetadataFilterSelection && suppressedSelectionChangeDepth == 0 {
                onSelectionChange?()
            }
        }
    }
    @Published var metadataSourceQuery = "" {
        didSet { handleMetadataFilterEdit(oldValue: oldValue, newValue: metadataSourceQuery) }
    }
    @Published var metadataYearFromQuery = "" {
        didSet { handleYearFilterEdit(oldValue: oldValue, newValue: metadataYearFromQuery) }
    }
    @Published var metadataYearToQuery = "" {
        didSet { handleYearFilterEdit(oldValue: oldValue, newValue: metadataYearToQuery) }
    }
    @Published var metadataGenreQuery = "" {
        didSet { handleMetadataFilterEdit(oldValue: oldValue, newValue: metadataGenreQuery) }
    }
    @Published var metadataTagsQuery = "" {
        didSet { handleMetadataFilterEdit(oldValue: oldValue, newValue: metadataTagsQuery) }
    }
    @Published var engineStatus = wordZText("正在连接本地引擎...", "Connecting to local engine…", mode: .system)
    @Published var lastErrorMessage = ""
    @Published var scene = WorkspaceSidebarSceneModel.empty
    @Published private(set) var recentMetadataSourceLabels: [String] = [] {
        didSet { syncScene() }
    }
    @Published private(set) var recentCorpusSetIDs: [String] = []

    var onSelectionChange: (() -> Void)?
    var onSelectionStateChange: (() -> Void)?
    var onMetadataFilterChange: ((Bool) -> Void)?

    var context = WorkspaceSceneContext.empty
    var isBusy = false
    var isApplyingMetadataFilterSelection = false
    var isApplyingMetadataFilterState = false
    var engineState: WorkspaceSidebarEngineState = .connecting
    var activeAnalysisTab: WorkspaceDetailTab = .stats
    var workflowTargetCorpusID: String?
    var workflowReferenceCorpusID: String?
    var workflowReferenceSummaryOverride: String?
    var workflowReferenceDetailOverride: String?
    var workflowKeywordEnabledOverride: Bool?
    var resultsSummary: WorkspaceSidebarResultsSceneModel?
    var legacyMetadataYearQuery = ""
    var metadataSuggestionCalendar: Calendar = .current
    var metadataSuggestionDateProvider: () -> Date = Date.init
    private var suppressedSelectionChangeDepth = 0

    var selectedCorpus: LibraryCorpusItem? {
        guard let selectedCorpusID else { return nil }
        return librarySnapshot.corpora.first(where: { $0.id == selectedCorpusID })
    }

    var selectedCorpusSet: LibraryCorpusSetItem? {
        guard let selectedCorpusSetID else { return nil }
        return librarySnapshot.corpusSets.first(where: { $0.id == selectedCorpusSetID })
    }

    var recentCorpusSets: [LibraryCorpusSetItem] {
        CorpusSetRecentsSupport.recentCorpusSets(
            from: librarySnapshot.corpusSets,
            recentIDs: recentCorpusSetIDs
        )
    }

    var hasAnyMetadataFilterInput: Bool {
        [metadataSourceQuery, metadataYearFromQuery, metadataYearToQuery, metadataGenreQuery, metadataTagsQuery, legacyMetadataYearQuery]
            .contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var metadataSourcePresetLabels: [String] {
        MetadataSourcePresetSupport.builtInSourceLabels
    }

    var metadataRecentSourceMenuLabels: [String] {
        MetadataSourcePresetSupport.menuRecentSourceLabels(from: recentMetadataSourceLabels)
    }

    var metadataQuickYearLabels: [String] {
        MetadataYearSuggestionSupport.quickYearLabels(
            referenceDate: metadataSuggestionDateProvider(),
            calendar: metadataSuggestionCalendar
        )
    }

    var metadataSuggestedYearLabels: [String] {
        MetadataYearSuggestionSupport.suggestedYears(from: librarySnapshot.corpora)
    }

    var metadataCommonYearLabels: [String] {
        MetadataYearSuggestionSupport.commonYearLabels(from: librarySnapshot.corpora)
    }

    var metadataYearRangeShortcuts: [MetadataYearRangeShortcut] {
        MetadataYearSuggestionSupport.rangeShortcuts(
            referenceDate: metadataSuggestionDateProvider(),
            calendar: metadataSuggestionCalendar
        )
    }

    func setSelectedCorpusID(
        _ corpusID: String?,
        notifySelectionChange: Bool
    ) {
        guard !notifySelectionChange else {
            selectedCorpusID = corpusID
            return
        }
        suppressedSelectionChangeDepth += 1
        defer { suppressedSelectionChangeDepth -= 1 }
        selectedCorpusID = corpusID
    }

    func applyRecentMetadataSourceLabels(_ labels: [String]) {
        recentMetadataSourceLabels = MetadataSourcePresetSupport.normalizedRecentSourceLabels(labels)
    }

    func applyRecentCorpusSetIDs(_ corpusSetIDs: [String]) {
        recentCorpusSetIDs = CorpusSetRecentsSupport.normalizedRecentCorpusSetIDs(corpusSetIDs)
    }

    func applyMetadataSourcePreset(_ label: String) {
        metadataSourceQuery = label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func applyMetadataYearSuggestion(_ year: String, isLowerBound: Bool) {
        if isLowerBound {
            metadataYearFromQuery = year
        } else {
            metadataYearToQuery = year
        }
    }

    func applyMetadataYearRangeShortcut(_ shortcut: MetadataYearRangeShortcut) {
        metadataYearFromQuery = shortcut.from
        metadataYearToQuery = shortcut.to
    }
}
