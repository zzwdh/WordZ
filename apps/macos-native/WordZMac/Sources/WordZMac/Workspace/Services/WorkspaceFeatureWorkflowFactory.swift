import Foundation

import WordZHost
@MainActor
struct WorkspaceFeatureWorkflowFactory: WorkspaceFeatureWorkflowBuilding {
    func make(
        repository: any WorkspaceRepository,
        sessionStore: WorkspaceSessionStore,
        dialogService: NativeDialogServicing,
        hostActionService: any NativeHostActionServicing,
        exportCoordinator: any WorkspaceExportCoordinating,
        taskCenter: NativeTaskCenter,
        analysisWorkflow: WorkspaceAnalysisWorkflowService
    ) -> WorkspaceFeatureWorkflowSet {
        WorkspaceFeatureWorkflowSet(
            sentiment: WorkspaceSentimentWorkflowService(
                analysisWorkflow: analysisWorkflow
            ),
            topics: WorkspaceTopicsWorkflowService(
                repository: repository,
                sessionStore: sessionStore,
                taskCenter: taskCenter,
                analysisWorkflow: analysisWorkflow
            )
        )
    }
}
