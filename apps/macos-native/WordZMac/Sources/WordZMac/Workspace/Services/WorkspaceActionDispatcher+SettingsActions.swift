import Foundation

@MainActor
extension WorkspaceActionDispatcher {
    func handleSettingsAction(_ action: SettingsPaneAction) {
        switch action {
        case .save:
            launch { await self.workspace.saveSettings() }
        case .checkForUpdatesNow:
            launch { await self.workspace.checkForUpdatesNow() }
        case .downloadUpdate:
            launch { await self.workspace.downloadLatestUpdate() }
        case .installDownloadedUpdate:
            launch { await self.workspace.installDownloadedUpdate() }
        case .revealDownloadedUpdate:
            launch { await self.workspace.revealDownloadedUpdate() }
        case .showUpdateWindow:
            NativeAppCommandCenter.post(.showUpdateWindow)
        case .showHelpWindow:
            NativeAppCommandCenter.post(.showHelpWindow)
        case .showAboutWindow:
            NativeAppCommandCenter.post(.showAboutWindow)
        case .showReleaseNotesWindow:
            NativeAppCommandCenter.post(.showReleaseNotesWindow)
        case .exportDiagnostics:
            launch { await self.workspace.exportDiagnostics(preferredWindowRoute: self.preferredWindowRoute) }
        case .openUserDataDirectory:
            launch { await self.workspace.openUserDataDirectory() }
        case .openFeedback:
            launch { await self.workspace.openFeedback() }
        case .openProjectHome:
            launch { await self.workspace.openProjectHome() }
        case .openReleaseNotes:
            launch { await self.workspace.openReleaseNotes() }
        case .clearRecentDocuments:
            launch { await self.workspace.clearRecentDocuments() }
        case .reopenRecent(let corpusID):
            launch { await self.workspace.openRecentDocument(corpusID) }
        }
    }
}
