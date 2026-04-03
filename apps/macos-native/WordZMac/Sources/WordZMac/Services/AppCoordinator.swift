import Foundation

@MainActor
final class AppCoordinator {
    private let repository: any WorkspaceRepository
    private let sceneStore: WorkspaceSceneStore
    private let sessionStore: WorkspaceSessionStore
    private let flowCoordinator: WorkspaceFlowCoordinator
    private let hostPreferencesStore: any NativeHostPreferencesStoring

    init(
        repository: any WorkspaceRepository,
        sceneStore: WorkspaceSceneStore,
        sessionStore: WorkspaceSessionStore,
        flowCoordinator: WorkspaceFlowCoordinator,
        hostPreferencesStore: any NativeHostPreferencesStoring = NativeHostPreferencesStore()
    ) {
        self.repository = repository
        self.sceneStore = sceneStore
        self.sessionStore = sessionStore
        self.flowCoordinator = flowCoordinator
        self.hostPreferencesStore = hostPreferencesStore
    }

    func refreshAll(features: WorkspaceFeatureSet) async {
        features.shell.isBusy = true
        features.sidebar.setBusy(true)
        defer {
            features.shell.isBusy = false
            features.sidebar.setBusy(false)
        }

        do {
            try await repository.start(userDataURL: EnginePaths.defaultUserDataURL())
            let bootstrapState = try await repository.loadBootstrapState()
            sessionStore.applyBootstrap(snapshot: bootstrapState.workspaceSnapshot)
            sceneStore.applyAppInfo(bootstrapState.appInfo)
            sceneStore.setBuildSummary("SwiftUI + Swift native engine（mac native preview）")
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
            features.shell.updateSelectionAvailability(
                hasSelection: features.sidebar.selectedCorpusID != nil,
                hasPreviewableCorpus: !(features.library.selectedCorpus?.representedPath.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty,
                corpusCount: features.sidebar.librarySnapshot.corpora.count,
                hasLocatorSource: features.kwic.primaryLocatorSource != nil,
                hasExportableContent: false
            )
            await flowCoordinator.refreshLibraryManagement(features: features)
            features.sidebar.clearError()
            flowCoordinator.syncWindowDocumentState(features: features)
        } catch {
            features.sidebar.setConnectionFailure(error.localizedDescription)
        }
    }

    func shutdown() async {
        await repository.stop()
    }
}
