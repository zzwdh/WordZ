import Foundation

@MainActor
final class WorkspaceShellViewModel: ObservableObject {
    @Published var selectedTab: WorkspaceDetailTab = .stats {
        didSet {
            guard oldValue != selectedTab else { return }
            onTabChange?()
        }
    }
    @Published var isBusy = false {
        didSet { syncScene() }
    }
    @Published private(set) var scene = WorkspaceShellSceneModel(
        workspaceSummary: WorkspaceSceneContext.empty.workspaceSummary,
        buildSummary: WorkspaceSceneContext.empty.buildSummary,
        toolbar: WorkspaceToolbarSceneModel(items: [])
    )

    var onTabChange: (() -> Void)?
    private var hasSelection = false {
        didSet { syncScene() }
    }
    private var corpusCount = 0 {
        didSet { syncScene() }
    }
    private var hasLocatorSource = false {
        didSet { syncScene() }
    }
    private var hasExportableContent = false {
        didSet { syncScene() }
    }
    private var context = WorkspaceSceneContext.empty

    private var languageMode: AppLanguageMode {
        WordZLocalization.shared.effectiveMode
    }

    func apply(_ snapshot: WorkspaceSnapshotSummary?) {
        guard let snapshot,
              let restoredTab = WorkspaceDetailTab.fromSnapshotValue(snapshot.currentTab)
        else { return }
        selectedTab = restoredTab
    }

    func applyContext(_ context: WorkspaceSceneContext) {
        self.context = context
        syncScene()
    }

    func updateSelectionAvailability(
        hasSelection: Bool,
        corpusCount: Int,
        hasLocatorSource: Bool,
        hasExportableContent: Bool
    ) {
        self.hasSelection = hasSelection
        self.corpusCount = corpusCount
        self.hasLocatorSource = hasLocatorSource
        self.hasExportableContent = hasExportableContent
    }

    private func syncScene() {
        let actionEnabled = !isBusy
        scene = WorkspaceShellSceneModel(
            workspaceSummary: context.workspaceSummary,
            buildSummary: context.buildSummary,
            toolbar: WorkspaceToolbarSceneModel(
                items: [
                    WorkspaceToolbarActionItem(action: .refresh, title: wordZText("刷新", "Refresh", mode: languageMode), isEnabled: actionEnabled),
                    WorkspaceToolbarActionItem(action: .showLibrary, title: wordZText("语料库", "Library", mode: languageMode), isEnabled: actionEnabled),
                    WorkspaceToolbarActionItem(action: .openSelected, title: wordZText("打开选中", "Open Selected", mode: languageMode), isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runStats, title: wordZText("统计", "Stats", mode: languageMode), isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runWord, title: wordZText("词表", "Word", mode: languageMode), isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runCompare, title: wordZText("对比", "Compare", mode: languageMode), isEnabled: actionEnabled && corpusCount >= 2),
                    WorkspaceToolbarActionItem(action: .runChiSquare, title: wordZText("卡方", "Chi-Square", mode: languageMode), isEnabled: actionEnabled),
                    WorkspaceToolbarActionItem(action: .runNgram, title: "N-Gram", isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runWordCloud, title: wordZText("词云", "Word Cloud", mode: languageMode), isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runKWIC, title: "KWIC", isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runCollocate, title: wordZText("搭配词", "Collocate", mode: languageMode), isEnabled: actionEnabled && hasSelection),
                    WorkspaceToolbarActionItem(action: .runLocator, title: wordZText("定位", "Locator", mode: languageMode), isEnabled: actionEnabled && hasSelection && hasLocatorSource),
                    WorkspaceToolbarActionItem(action: .exportCurrent, title: wordZText("导出当前", "Export Current", mode: languageMode), isEnabled: actionEnabled && hasExportableContent)
                ]
            )
        )
    }
}
