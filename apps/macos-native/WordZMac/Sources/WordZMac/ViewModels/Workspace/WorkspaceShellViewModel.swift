import Foundation
import WordZShared

@MainActor
final class WorkspaceShellViewModel: ObservableObject {
    @Published var selectedTab: WorkspaceDetailTab = .stats {
        didSet {
            guard oldValue != selectedTab else { return }
            guard suppressedTabChangeDepth == 0 else { return }
            onTabChange?()
        }
    }
    @Published var isBusy = false {
        didSet { syncScene() }
    }
    @Published private(set) var blockingOperationCount = 0
    @Published private(set) var scene = WorkspaceShellSceneModel(
        workspaceSummary: WorkspaceSceneContext.empty.workspaceSummary,
        buildSummary: WorkspaceSceneContext.empty.buildSummary,
        annotationSummary: WorkspaceAnnotationState.default.summary(in: .system),
        toolbar: WorkspaceToolbarSceneModel(items: [])
    )

    var onTabChange: (() -> Void)?
    private var hasSelection = false
    private var hasSourceReaderContext = false
    private var hasPreviewableCorpus = false
    private var corpusCount = 0
    private var hasLocatorSource = false
    private var hasCopyableContent = false
    private var hasExportableContent = false
    private var runSentimentEnabled = false
    private var annotationState = WorkspaceAnnotationState.default
    private var context = WorkspaceSceneContext.empty
    private var suppressedTabChangeDepth = 0

    private var languageMode: AppLanguageMode {
        WordZLocalization.shared.effectiveMode
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary?) {
        guard let snapshot,
              let restoredTab = WorkspaceDetailTab.fromSnapshotValue(snapshot.currentTab)
        else { return }
        selectedTab = restoredTab.mainWorkspaceTab
    }

    func setSelectedTab(
        _ tab: WorkspaceDetailTab,
        notifyTabChange: Bool
    ) {
        guard !notifyTabChange else {
            selectedTab = tab
            return
        }
        suppressedTabChangeDepth += 1
        defer { suppressedTabChangeDepth -= 1 }
        selectedTab = tab
    }

    func applyContext(_ context: WorkspaceSceneContext) {
        self.context = context
        syncScene()
    }

    func updateSelectionAvailability(
        hasSelection: Bool,
        hasSourceReaderContext: Bool,
        hasPreviewableCorpus: Bool,
        corpusCount: Int,
        hasLocatorSource: Bool,
        hasCopyableContent: Bool = false,
        hasExportableContent: Bool,
        runSentimentEnabled: Bool = false
    ) {
        let hasChanged = self.hasSelection != hasSelection ||
            self.hasSourceReaderContext != hasSourceReaderContext ||
            self.hasPreviewableCorpus != hasPreviewableCorpus ||
            self.corpusCount != corpusCount ||
            self.hasLocatorSource != hasLocatorSource ||
            self.hasCopyableContent != hasCopyableContent ||
            self.hasExportableContent != hasExportableContent ||
            self.runSentimentEnabled != runSentimentEnabled
        guard hasChanged else { return }
        self.hasSelection = hasSelection
        self.hasSourceReaderContext = hasSourceReaderContext
        self.hasPreviewableCorpus = hasPreviewableCorpus
        self.corpusCount = corpusCount
        self.hasLocatorSource = hasLocatorSource
        self.hasCopyableContent = hasCopyableContent
        self.hasExportableContent = hasExportableContent
        self.runSentimentEnabled = runSentimentEnabled
        syncScene()
    }

    func applyAnnotationState(_ annotationState: WorkspaceAnnotationState) {
        guard self.annotationState != annotationState else { return }
        self.annotationState = annotationState
        syncScene()
    }

    func setBlockingOperationCount(_ count: Int) {
        let nextCount = max(0, count)
        guard blockingOperationCount != nextCount || isBusy != (nextCount > 0) else {
            return
        }
        blockingOperationCount = nextCount
        isBusy = nextCount > 0
    }

    private func syncScene() {
        let actionEnabled = !isBusy
        scene = WorkspaceShellSceneModel(
            workspaceSummary: context.workspaceSummary,
            buildSummary: context.buildSummary,
            annotationSummary: annotationState.summary(in: languageMode),
            toolbar: WorkspaceToolbarSceneModel(
                items: WorkspaceActionRegistry.toolbarItems(
                    languageMode: languageMode,
                    availability: WorkspaceToolbarAvailabilityContext(
                        actionEnabled: actionEnabled,
                        hasSelection: hasSelection,
                        hasSourceReaderContext: hasSourceReaderContext,
                        hasPreviewableContent: hasPreviewableCorpus,
                        corpusCount: corpusCount,
                        hasLocatorSource: hasLocatorSource,
                        hasCopyableContent: hasCopyableContent,
                        hasExportableContent: hasExportableContent,
                        runSentimentEnabled: runSentimentEnabled
                    )
                )
            )
        )
    }
}
