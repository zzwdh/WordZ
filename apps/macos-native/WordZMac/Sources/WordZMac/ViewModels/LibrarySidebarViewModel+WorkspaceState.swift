import Foundation

@MainActor
extension LibrarySidebarViewModel {
    func applyBootstrap(_ state: WorkspaceBootstrapState) {
        engineState = .connected
        engineStatus = wordZText("本地引擎已连接", "Local engine connected", mode: languageMode)
        lastErrorMessage = ""
        librarySnapshot = state.librarySnapshot
    }

    func applyContext(_ context: WorkspaceSceneContext) {
        self.context = context
        syncScene()
    }

    func applyWorkflowState(
        activeAnalysisTab: WorkspaceDetailTab,
        targetCorpusID: String?,
        referenceCorpusID: String?,
        resultsSummary: WorkspaceSidebarResultsSceneModel?
    ) {
        self.activeAnalysisTab = activeAnalysisTab
        self.workflowTargetCorpusID = targetCorpusID
        self.workflowReferenceCorpusID = referenceCorpusID
        self.resultsSummary = resultsSummary
        syncScene()
    }

    func setBusy(_ isBusy: Bool) {
        self.isBusy = isBusy
        syncScene()
    }

    func setConnectionFailure(_ message: String) {
        engineState = .failed
        engineStatus = wordZText("本地引擎连接失败", "Local engine connection failed", mode: languageMode)
        lastErrorMessage = message
        syncScene()
    }

    func clearError() {
        lastErrorMessage = ""
        syncScene()
    }

    func setError(_ message: String) {
        lastErrorMessage = message
        syncScene()
    }
}
