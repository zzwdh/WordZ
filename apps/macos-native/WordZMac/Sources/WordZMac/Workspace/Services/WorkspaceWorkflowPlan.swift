import Foundation

enum WorkspaceStateMutation: Equatable {
    case importCorpora
    case newWorkspace
    case restoreWorkspace
    case showWelcome
    case openWindow(NativeWindowRoute)
    case showSettings
    case toggleInspector
    case refreshWorkspace
    case openSelectedCorpus
    case openSourceReader
    case resultArtifact(WorkspaceResultArtifactAction)
    case runAnalysis(WorkspaceAnalysisIntent)
    case checkForUpdates
    case downloadUpdate
    case installDownloadedUpdate
    case exportDiagnostics
    case openProjectHome
    case openReleaseNotes
    case openFeedback
    case clearRecentDocuments
    case noOp
}

enum WorkspaceWorkflowSceneSync: Equatable {
    case none
    case handledByWorkflow(SceneSyncSource)
    case handledByResultRun
}

struct WorkspaceWorkflowPlan: Equatable {
    let intent: WorkspaceIntent
    let stateMutation: WorkspaceStateMutation
    let sceneSync: WorkspaceWorkflowSceneSync
}

enum WorkspaceWorkflowPlanner {
    static func plan(for intent: WorkspaceIntent) -> WorkspaceWorkflowPlan {
        WorkspaceWorkflowPlan(
            intent: intent,
            stateMutation: stateMutation(for: intent),
            sceneSync: sceneSync(for: intent)
        )
    }

    private static func stateMutation(for intent: WorkspaceIntent) -> WorkspaceStateMutation {
        switch intent {
        case .importCorpora:
            return .importCorpora
        case .newWorkspace:
            return .newWorkspace
        case .restoreWorkspace:
            return .restoreWorkspace
        case .showWelcome:
            return .showWelcome
        case .openWindow(let route):
            return .openWindow(route)
        case .showSettings:
            return .showSettings
        case .toggleInspector:
            return .toggleInspector
        case .refreshWorkspace:
            return .refreshWorkspace
        case .openSelectedCorpus:
            return .openSelectedCorpus
        case .openSourceReader:
            return .openSourceReader
        case .resultArtifact(let action):
            return .resultArtifact(action)
        case .runAnalysis(let analysisIntent):
            return .runAnalysis(analysisIntent)
        case .checkForUpdates:
            return .checkForUpdates
        case .downloadUpdate:
            return .downloadUpdate
        case .installDownloadedUpdate:
            return .installDownloadedUpdate
        case .exportDiagnostics:
            return .exportDiagnostics
        case .openProjectHome:
            return .openProjectHome
        case .openReleaseNotes:
            return .openReleaseNotes
        case .openFeedback:
            return .openFeedback
        case .clearRecentDocuments:
            return .clearRecentDocuments
        case .noOp:
            return .noOp
        }
    }

    private static func sceneSync(for intent: WorkspaceIntent) -> WorkspaceWorkflowSceneSync {
        switch intent {
        case .importCorpora, .newWorkspace, .restoreWorkspace, .refreshWorkspace:
            return .handledByWorkflow(.full)
        case .openSelectedCorpus:
            return .handledByWorkflow(.librarySelection)
        case .resultArtifact(.export):
            return .handledByWorkflow(.resultContent)
        case .runAnalysis:
            return .handledByResultRun
        case .showWelcome, .openWindow, .showSettings, .toggleInspector, .openSourceReader,
             .resultArtifact(.copy), .resultArtifact(.preview), .resultArtifact(.share),
             .resultArtifact(.openSourceReader), .checkForUpdates, .downloadUpdate,
             .installDownloadedUpdate, .exportDiagnostics, .openProjectHome, .openReleaseNotes,
             .openFeedback, .clearRecentDocuments, .noOp:
            return .none
        }
    }
}
