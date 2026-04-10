import Foundation

@MainActor
extension MainWorkspaceViewModel {
    var languageMode: AppLanguageMode {
        WordZLocalization.shared.effectiveMode
    }

    var selectedTab: WorkspaceDetailTab {
        get { shell.selectedTab.mainWorkspaceTab }
        set { shell.selectedTab = newValue.mainWorkspaceTab }
    }

    var selectedRoute: WorkspaceMainRoute {
        get { WorkspaceMainRoute(tab: selectedTab) }
        set { selectedTab = newValue.tab }
    }

    var windowTitle: String { sceneStore.context.appName }
    var canRestoreWorkspace: Bool { sessionStore.workspaceSnapshot != nil }
    var canQuickLookCurrentCorpus: Bool { currentContentTarget != nil }
    var canShareCurrentContent: Bool { currentContentTarget != nil }
    var canManageAnalysisPresets: Bool { analysisPresetRepository != nil }
    var canExportCurrentReportBundle: Bool {
        currentExportSnapshot != nil || !currentReportTextDocuments.isEmpty
    }
}
