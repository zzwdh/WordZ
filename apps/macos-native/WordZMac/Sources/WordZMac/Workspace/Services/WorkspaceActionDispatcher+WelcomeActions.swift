import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleWelcomeAction(_ action: WelcomeAction) {
        switch action {
        case .dismiss:
            workspace.dismissWelcome()
        case .openSelection:
            workspace.dismissWelcome()
            launch { await self.workspace.openSelectedCorpus() }
        case .showLibrary:
            workspace.dismissWelcome()
            NativeAppCommandCenter.post(.showLibrary)
        case .openRecent(let corpusID):
            launch { await self.workspace.openRecentDocument(corpusID) }
        case .openReleaseNotes:
            NativeAppCommandCenter.post(.showReleaseNotesWindow)
        case .openFeedback:
            launch { await self.workspace.openFeedback() }
        }
    }
}
