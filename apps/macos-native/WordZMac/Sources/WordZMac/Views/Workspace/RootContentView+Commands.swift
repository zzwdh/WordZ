import AppKit
import SwiftUI

@MainActor
struct RootContentCommandHandler {
    let workspace: MainWorkspaceViewModel
    let shellActionHandler: any RootContentShellActionHandling
    var openSettings: () -> Void = {
        NativeSettingsSupport.openSettingsWindow()
    }

    func selectTab(_ tab: WorkspaceDetailTab) {
        shellActionHandler.handle(.selectRoute(WorkspaceMainRoute(tab: tab)))
    }

    func openHelpCenter() {
        shellActionHandler.handle(.openWindow(.help))
    }

    func exportDiagnostics() {
        Task { await workspace.exportDiagnostics(preferredWindowRoute: .mainWorkspace) }
    }

    func openUserDataDirectory() {
        Task { await workspace.openUserDataDirectory() }
    }

    func recoveryTitle(
        for action: WorkspaceIssueRecoveryAction,
        languageMode: AppLanguageMode
    ) -> String {
        switch action {
        case .refreshWorkspace:
            return wordZText("重试加载", "Retry", mode: languageMode)
        case .checkForUpdates:
            return wordZText("重新检查更新", "Retry Update Check", mode: languageMode)
        case .exportDiagnostics:
            return wordZText("重试导出诊断包", "Retry Export Diagnostics Bundle", mode: languageMode)
        }
    }

    func performRecoveryAction(_ action: WorkspaceIssueRecoveryAction) async {
        switch action {
        case .refreshWorkspace:
            await workspace.refreshAll()
        case .checkForUpdates:
            await workspace.checkForUpdatesNow()
        case .exportDiagnostics:
            await workspace.exportDiagnostics(preferredWindowRoute: .mainWorkspace)
        }
    }

    func handle(_ command: NativeAppCommand) {
        switch command {
        case .importCorpora:
            shellActionHandler.handle(.openWindow(.library))
            Task { await workspace.importCorpusFromDialog() }
        case .newWorkspace:
            Task { await workspace.newWorkspace() }
        case .restoreWorkspace:
            Task { await workspace.restoreSavedWorkspace() }
        case .showWelcome:
            shellActionHandler.handle(.presentWelcome)
        case .showLibrary:
            shellActionHandler.handle(.openWindow(.library))
        case .showSettings:
            openSettings()
        case .showTaskCenterWindow:
            shellActionHandler.handle(.openWindow(.taskCenter))
        case .showUpdateWindow:
            shellActionHandler.handle(.openWindow(.updatePrompt))
        case .showAboutWindow:
            shellActionHandler.handle(.openWindow(.about))
        case .showHelpWindow:
            shellActionHandler.handle(.openWindow(.help))
        case .showReleaseNotesWindow:
            shellActionHandler.handle(.openWindow(.releaseNotes))
        case .toggleInspector:
            shellActionHandler.handle(.toggleInspector)
        case .refreshWorkspace:
            Task { await workspace.refreshAll() }
        case .openSelectedCorpus:
            Task { await workspace.openSelectedCorpus() }
        case .openSourceReader:
            Task {
                guard await workspace.openCurrentSourceReader() else { return }
                shellActionHandler.handle(.openWindow(.sourceReader))
            }
        case .quickLookCurrentCorpus:
            Task { await workspace.quickLookCurrentCorpus() }
        case .shareCurrentContent:
            Task { await workspace.shareCurrentContent() }
        case .runStats:
            Task { await workspace.runStats() }
        case .runWord:
            Task { await workspace.runWord() }
        case .runTokenize:
            Task { await workspace.runTokenize() }
        case .runTopics:
            Task { await workspace.runTopics() }
        case .runCompare:
            Task { await workspace.runCompare() }
        case .runSentiment:
            Task { await workspace.runSentiment() }
        case .runKeyword:
            Task { await workspace.runKeyword() }
        case .runChiSquare:
            Task { await workspace.runChiSquare() }
        case .runPlot:
            Task { await workspace.runPlot() }
        case .runNgram:
            Task { await workspace.runNgram() }
        case .runCluster:
            Task { await workspace.runCluster() }
        case .runKWIC:
            Task { await workspace.runKWIC() }
        case .runCollocate:
            Task { await workspace.runCollocate() }
        case .runLocator:
            Task { await workspace.runLocator() }
        case .exportCurrent:
            Task { await workspace.exportCurrent() }
        case .checkForUpdates:
            Task { await workspace.checkForUpdatesNow() }
        case .downloadUpdate:
            Task { await workspace.downloadLatestUpdate() }
        case .installDownloadedUpdate:
            Task { await workspace.installDownloadedUpdate() }
        case .exportDiagnostics:
            Task { await workspace.exportDiagnostics() }
        case .openProjectHome:
            Task { await workspace.openProjectHome() }
        case .openReleaseNotes:
            Task { await workspace.openReleaseNotes() }
        case .openFeedback:
            Task { await workspace.openFeedback() }
        case .clearRecentDocuments:
            Task { await workspace.clearRecentDocuments() }
        }
    }
}

extension RootContentView {
    var commandHandler: RootContentCommandHandler {
        RootContentCommandHandler(
            workspace: viewModel,
            shellActionHandler: shellActionHandler,
            openSettings: {
                NativeSettingsSupport.openSettingsWindow()
            }
        )
    }
}
