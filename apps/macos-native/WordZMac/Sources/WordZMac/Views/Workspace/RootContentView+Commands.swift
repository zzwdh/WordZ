import AppKit
import SwiftUI

import WordZWindowing
import WordZShared
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
            return wordZText("重试导出诊断信息", "Retry Export Diagnostics", mode: languageMode)
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
        execute(WorkspaceWorkflowPlanner.plan(for: WorkspaceIntent(nativeCommand: command)))
    }

    private func execute(_ plan: WorkspaceWorkflowPlan) {
        switch plan.stateMutation {
        case .importCorpora:
            shellActionHandler.handle(.openWindow(.library))
            Task { await workspace.importCorpusFromDialog() }
        case .newWorkspace:
            Task { await workspace.newWorkspace() }
        case .restoreWorkspace:
            Task { await workspace.restoreSavedWorkspace() }
        case .showWelcome:
            shellActionHandler.handle(.presentWelcome)
        case .openWindow(let route):
            shellActionHandler.handle(.openWindow(route))
        case .showSettings:
            openSettings()
        case .toggleInspector:
            shellActionHandler.handle(.toggleInspector)
        case .refreshWorkspace:
            Task { await workspace.refreshAll() }
        case .openSelectedCorpus:
            Task { await workspace.openSelectedCorpus() }
        case .openSourceReader:
            Task { @MainActor in
                guard await workspace.performResultArtifactAction(.openSourceReader) else { return }
                shellActionHandler.handle(.openWindow(.sourceReader))
            }
        case .resultArtifact(let action):
            Task { await workspace.performResultArtifactAction(action) }
        case .runAnalysis(let analysisIntent):
            Task { await workspace.runAnalysis(analysisIntent) }
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
        case .noOp:
            break
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
