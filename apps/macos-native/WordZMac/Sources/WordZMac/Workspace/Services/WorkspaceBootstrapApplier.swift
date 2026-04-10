import Foundation

@MainActor
struct WorkspaceBootstrapApplier: WorkspaceBootstrapApplying {
    let sceneStore: WorkspaceSceneStore
    let sessionStore: WorkspaceSessionStore
    let flowCoordinator: WorkspaceFlowCoordinator
    let hostPreferencesStore: any NativeHostPreferencesStoring
    let buildMetadataProvider: any NativeBuildMetadataProviding

    func apply(_ bootstrapState: WorkspaceBootstrapState, to features: WorkspaceFeatureSet) {
        sessionStore.applyBootstrap(snapshot: bootstrapState.workspaceSnapshot)
        sceneStore.applyAppInfo(bootstrapState.appInfo)
        sceneStore.setBuildSummary(buildMetadataProvider.current().buildSummary)
        features.sidebar.applyBootstrap(bootstrapState)
        features.library.applyBootstrap(bootstrapState.librarySnapshot)
        features.settings.applyAppInfo(bootstrapState.appInfo)
        features.settings.apply(bootstrapState.uiSettings)
        features.settings.applyHostPreferences(hostPreferencesStore.load())
        features.ngram.apply(bootstrapState.workspaceSnapshot)
        features.kwic.apply(bootstrapState.workspaceSnapshot)
        features.collocate.apply(bootstrapState.workspaceSnapshot)
        features.shell.apply(bootstrapState.workspaceSnapshot)
        flowCoordinator.restoreSelectionFromWorkspace(
            features: features,
            restoreWorkspace: bootstrapState.uiSettings.restoreWorkspace
        )
        flowCoordinator.applyWorkspacePresentation(features: features)
        updateShellAvailability(features: features)
    }

    func finalizeRefresh(features: WorkspaceFeatureSet) async {
        await flowCoordinator.refreshLibraryManagement(features: features)
        features.sidebar.clearError()
        flowCoordinator.syncWindowDocumentState(features: features)
    }

    func updateShellAvailability(features: WorkspaceFeatureSet) {
        features.shell.updateSelectionAvailability(
            hasSelection: features.sidebar.selectedCorpusID != nil,
            hasPreviewableCorpus: !(features.library.selectedCorpus?.representedPath.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty,
            corpusCount: features.sidebar.librarySnapshot.corpora.count,
            hasLocatorSource: features.kwic.primaryLocatorSource != nil,
            hasExportableContent: false
        )
    }
}
