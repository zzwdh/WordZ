import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleWorkspaceIntent(_ intent: WorkspaceIntent) {
        execute(WorkspaceWorkflowPlanner.plan(for: intent))
    }

    func execute(_ plan: WorkspaceWorkflowPlan) {
        switch plan.stateMutation {
        case .importCorpora, .newWorkspace, .restoreWorkspace, .showWelcome, .openWindow,
             .showSettings, .toggleInspector, .openSourceReader, .checkForUpdates, .downloadUpdate,
             .installDownloadedUpdate, .exportDiagnostics, .openProjectHome, .openReleaseNotes,
             .openFeedback, .clearRecentDocuments:
            postCommand(for: plan.intent)
        case .refreshWorkspace:
            launch { await self.workspace.refreshAll() }
        case .openSelectedCorpus:
            launch { await self.workspace.openSelectedCorpus() }
        case .resultArtifact(let action):
            launch {
                await self.workspace.performResultArtifactAction(
                    action,
                    preferredWindowRoute: self.preferredWindowRoute
                )
            }
        case .runAnalysis(let analysisIntent):
            launch { await self.workspace.runAnalysis(analysisIntent) }
        case .noOp:
            break
        }
    }

    private func postCommand(for intent: WorkspaceIntent) {
        guard let command = intent.nativeCommand else { return }
        NativeAppCommandCenter.post(command)
    }
}
