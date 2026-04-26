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
        features.library.applyRecentCorpusSetIDs(bootstrapState.uiSettings.recentCorpusSetIDs)
        features.settings.applyAppInfo(bootstrapState.appInfo)
        features.settings.apply(bootstrapState.uiSettings)
        features.settings.applyHostPreferences(hostPreferencesStore.load())
        features.sentiment.syncLibrarySnapshot(bootstrapState.librarySnapshot)
        features.sentiment.apply(bootstrapState.workspaceSnapshot)
        features.evidenceWorkbench.apply(bootstrapState.workspaceSnapshot)
        features.cluster.syncLibrarySnapshot(bootstrapState.librarySnapshot)
        features.plot.apply(bootstrapState.workspaceSnapshot)
        features.ngram.apply(bootstrapState.workspaceSnapshot)
        features.cluster.apply(bootstrapState.workspaceSnapshot)
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
        await flowCoordinator.refreshKeywordSavedLists(features: features)
        await flowCoordinator.refreshConcordanceSavedSets(features: features)
        await flowCoordinator.refreshEvidenceItems(features: features)
        await flowCoordinator.refreshSentimentReviewSamples(features: features)
        features.sidebar.clearError()
        flowCoordinator.syncWindowDocumentState(features: features)
    }

    func updateShellAvailability(features: WorkspaceFeatureSet) {
        features.shell.updateSelectionAvailability(
            hasSelection: features.sidebar.selectedCorpusID != nil,
            hasSourceReaderContext: false,
            hasPreviewableCorpus: !(features.library.selectedCorpus?.representedPath.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty,
            corpusCount: features.sidebar.librarySnapshot.corpora.count,
            hasLocatorSource: features.kwic.primaryLocatorSource != nil,
            hasExportableContent: false,
            runSentimentEnabled: features.sentiment.canRun(
                hasOpenedCorpus: features.sidebar.selectedCorpusID != nil,
                hasKWICRows: features.kwic.scene?.rows.isEmpty == false,
                hasTopicRows: features.topics.canAnalyzeVisibleTopicsInSentiment
            )
        )
    }
}
