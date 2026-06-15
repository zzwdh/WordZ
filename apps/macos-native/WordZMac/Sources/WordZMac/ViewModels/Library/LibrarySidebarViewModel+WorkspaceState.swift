import Foundation
import WordZShared

@MainActor
extension LibrarySidebarViewModel {
    func applyBootstrap(_ state: WorkspaceBootstrapState) {
        engineState = .connected
        engineStatus = wordZText("分析功能已就绪", "Analysis features ready", mode: languageMode)
        lastErrorMessage = ""
        applyRecentMetadataSourceLabels(state.uiSettings.recentMetadataSourceLabels)
        applyRecentCorpusSetIDs(state.uiSettings.recentCorpusSetIDs)
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
        referenceSummaryOverride: String? = nil,
        referenceDetailOverride: String? = nil,
        resultsSummary: WorkspaceSidebarResultsSceneModel?
    ) {
        self.activeAnalysisTab = activeAnalysisTab
        self.workflowTargetCorpusID = targetCorpusID
        self.workflowReferenceCorpusID = referenceCorpusID
        self.workflowReferenceSummaryOverride = referenceSummaryOverride
        self.workflowReferenceDetailOverride = referenceDetailOverride
        self.resultsSummary = resultsSummary
        syncScene()
    }

    func setBusy(_ isBusy: Bool) {
        self.isBusy = isBusy
        syncScene()
    }

    func setConnectionFailure(_ message: String) {
        engineState = .failed
        engineStatus = wordZText("分析功能准备失败", "Analysis features could not be prepared", mode: languageMode)
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
