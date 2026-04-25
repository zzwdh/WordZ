import Foundation

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
        hasExportableContent: Bool,
        runSentimentEnabled: Bool = false
    ) {
        let hasChanged = self.hasSelection != hasSelection ||
            self.hasSourceReaderContext != hasSourceReaderContext ||
            self.hasPreviewableCorpus != hasPreviewableCorpus ||
            self.corpusCount != corpusCount ||
            self.hasLocatorSource != hasLocatorSource ||
            self.hasExportableContent != hasExportableContent ||
            self.runSentimentEnabled != runSentimentEnabled
        guard hasChanged else { return }
        self.hasSelection = hasSelection
        self.hasSourceReaderContext = hasSourceReaderContext
        self.hasPreviewableCorpus = hasPreviewableCorpus
        self.corpusCount = corpusCount
        self.hasLocatorSource = hasLocatorSource
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
                items: [
                    WorkspaceToolbarActionItem(action: .refresh, title: wordZText("刷新", "Refresh", mode: languageMode), isEnabled: actionEnabled),
                    WorkspaceToolbarActionItem(action: .showLibrary, title: wordZText("语料库", "Library", mode: languageMode), isEnabled: actionEnabled),
                    WorkspaceToolbarActionItem(action: .openSelected, title: wordZText("打开选中", "Open Selected", mode: languageMode), isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .openSourceReader, title: wordZText("原文视图", "Open Source View", mode: languageMode), isEnabled: actionEnabled && hasSourceReaderContext),
                    WorkspaceToolbarActionItem(action: .annotationControls, title: wordZText("标注", "Annotation", mode: languageMode), isEnabled: actionEnabled),
                    WorkspaceToolbarActionItem(action: .previewCurrentCorpus, title: wordZText("快速预览", "Quick Look", mode: languageMode), isEnabled: actionEnabled && hasPreviewableCorpus),
                    WorkspaceToolbarActionItem(action: .shareCurrentContent, title: wordZText("分享当前", "Share Current", mode: languageMode), isEnabled: actionEnabled && hasPreviewableCorpus),
                    WorkspaceToolbarActionItem(action: .runStats, title: wordZText("统计", "Stats", mode: languageMode), isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runWord, title: wordZText("词表", "Word", mode: languageMode), isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runTokenize, title: wordZText("分词", "Tokenize", mode: languageMode), isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runTopics, title: wordZText("主题", "Topics", mode: languageMode), isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runCompare, title: wordZText("对比", "Compare", mode: languageMode), isEnabled: actionEnabled && corpusCount >= 2),
                    WorkspaceToolbarActionItem(action: .runSentiment, title: wordZText("情感", "Sentiment", mode: languageMode), isEnabled: actionEnabled && runSentimentEnabled),
                    WorkspaceToolbarActionItem(action: .runKeyword, title: wordZText("关键词", "Keyword", mode: languageMode), isEnabled: actionEnabled && corpusCount >= 2),
                    WorkspaceToolbarActionItem(action: .runChiSquare, title: wordZText("卡方", "Chi-Square", mode: languageMode), isEnabled: actionEnabled),
                    WorkspaceToolbarActionItem(action: .runPlot, title: wordZText("图表", "Plot", mode: languageMode), isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runNgram, title: "N-Gram", isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runCluster, title: wordZText("词串簇", "Cluster", mode: languageMode), isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runKWIC, title: "KWIC", isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runCollocate, title: wordZText("搭配词", "Collocate", mode: languageMode), isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runLocator, title: wordZText("定位", "Locator", mode: languageMode), isEnabled: actionEnabled && hasSelection && hasLocatorSource),
                    WorkspaceToolbarActionItem(action: .exportCurrent, title: wordZText("导出当前", "Export Current", mode: languageMode), isEnabled: actionEnabled && hasExportableContent)
                ]
            )
        )
    }
}
