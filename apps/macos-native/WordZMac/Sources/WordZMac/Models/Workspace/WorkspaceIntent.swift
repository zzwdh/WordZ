import Foundation

enum WorkspaceIntent: Equatable, Sendable {
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

    init(toolbarAction: WorkspaceToolbarAction) {
        self = WorkspaceActionRegistry.intent(for: toolbarAction)
    }

    init(nativeCommand: NativeAppCommand) {
        if let analysisIntent = WorkspaceAnalysisIntent(nativeCommand: nativeCommand) {
            self = .runAnalysis(analysisIntent)
            return
        }

        switch nativeCommand {
        case .importCorpora:
            self = .importCorpora
        case .newWorkspace:
            self = .newWorkspace
        case .restoreWorkspace:
            self = .restoreWorkspace
        case .showWelcome:
            self = .showWelcome
        case .showLibrary:
            self = .openWindow(.library)
        case .showSettings:
            self = .showSettings
        case .showUpdateWindow:
            self = .openWindow(.updatePrompt)
        case .showAboutWindow:
            self = .openWindow(.about)
        case .showHelpWindow:
            self = .openWindow(.help)
        case .showReleaseNotesWindow:
            self = .openWindow(.releaseNotes)
        case .toggleInspector:
            self = .toggleInspector
        case .refreshWorkspace:
            self = .refreshWorkspace
        case .openSelectedCorpus:
            self = .openSelectedCorpus
        case .openSourceReader:
            self = .openSourceReader
        case .copyCurrentResult:
            self = .resultArtifact(.copy)
        case .quickLookCurrentCorpus:
            self = .resultArtifact(.preview)
        case .shareCurrentContent:
            self = .resultArtifact(.share)
        case .exportCurrent:
            self = .resultArtifact(.export)
        case .checkForUpdates:
            self = .checkForUpdates
        case .downloadUpdate:
            self = .downloadUpdate
        case .installDownloadedUpdate:
            self = .installDownloadedUpdate
        case .exportDiagnostics:
            self = .exportDiagnostics
        case .openProjectHome:
            self = .openProjectHome
        case .openReleaseNotes:
            self = .openReleaseNotes
        case .openFeedback:
            self = .openFeedback
        case .clearRecentDocuments:
            self = .clearRecentDocuments
        case .runStats, .runWord, .runTokenize, .runTopics, .runCompare, .runSentiment,
             .runKeyword, .runChiSquare, .runPlot, .runNgram, .runCluster, .runKWIC,
             .runCollocate, .runLocator:
            self = .noOp
        }
    }

    var nativeCommand: NativeAppCommand? {
        switch self {
        case .importCorpora:
            return .importCorpora
        case .newWorkspace:
            return .newWorkspace
        case .restoreWorkspace:
            return .restoreWorkspace
        case .showWelcome:
            return .showWelcome
        case .openWindow(.library):
            return .showLibrary
        case .openWindow(.updatePrompt):
            return .showUpdateWindow
        case .openWindow(.about):
            return .showAboutWindow
        case .openWindow(.help):
            return .showHelpWindow
        case .openWindow(.releaseNotes):
            return .showReleaseNotesWindow
        case .openWindow(.mainWorkspace), .openWindow(.sourceReader),
             .openWindow(.settings):
            return nil
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
        case .resultArtifact(.copy):
            return .copyCurrentResult
        case .resultArtifact(.preview):
            return .quickLookCurrentCorpus
        case .resultArtifact(.share):
            return .shareCurrentContent
        case .resultArtifact(.export):
            return .exportCurrent
        case .resultArtifact(.openSourceReader):
            return .openSourceReader
        case .resultArtifact:
            return nil
        case .runAnalysis(let analysisIntent):
            return analysisIntent.nativeCommand
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
            return nil
        }
    }
}
