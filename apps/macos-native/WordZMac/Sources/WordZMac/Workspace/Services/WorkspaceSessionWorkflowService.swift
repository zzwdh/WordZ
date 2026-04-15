import Foundation

@MainActor
final class WorkspaceSessionWorkflowService {
    private let repository: any WorkspaceRepository
    private let sessionStore: WorkspaceSessionStore
    private let sceneStore: WorkspaceSceneStore
    private let libraryCoordinator: any LibraryCoordinating
    private let persistenceWorkflow: WorkspacePersistenceWorkflowService

    init(
        repository: any WorkspaceRepository,
        sessionStore: WorkspaceSessionStore,
        sceneStore: WorkspaceSceneStore,
        libraryCoordinator: any LibraryCoordinating,
        persistenceWorkflow: WorkspacePersistenceWorkflowService
    ) {
        self.repository = repository
        self.sessionStore = sessionStore
        self.sceneStore = sceneStore
        self.libraryCoordinator = libraryCoordinator
        self.persistenceWorkflow = persistenceWorkflow
    }

    func restoreSelectionFromWorkspace(
        features: WorkspaceFeatureSet,
        restoreWorkspace: Bool
    ) {
        sessionStore.beginRestore()
        defer {
            sessionStore.finishRestore()
            updateSelectionAvailability(features: features)
            syncFeatureContexts(features: features)
        }

        if restoreWorkspace, let workspaceSnapshot = sessionStore.workspaceSnapshot {
            applyWorkspaceSnapshot(workspaceSnapshot, features: features)
            return
        }

        if let currentSelection = features.sidebar.selectedCorpusID,
           features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == currentSelection }) {
            return
        }

        let preferredName = sessionStore.workspaceSnapshot?.corpusNames.first
        if let preferredName,
           let matchingCorpus = features.sidebar.librarySnapshot.corpora.first(where: { $0.name == preferredName }) {
            features.sidebar.selectedCorpusID = matchingCorpus.id
            return
        }

        features.sidebar.selectedCorpusID = features.sidebar.librarySnapshot.corpora.first?.id
    }

    func newWorkspace(features: WorkspaceFeatureSet) async {
        let emptyDraft = WorkspaceStateDraft.empty
        sessionStore.beginRestore()
        defer {
            sessionStore.finishRestore()
            persistenceWorkflow.applyWorkspacePresentation(
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            persistenceWorkflow.syncWindowDocumentState(features: features)
        }

        resetFeatureResults(features: features)
        sessionStore.resetToEmptyWorkspace()
        features.stats.apply(.empty)
        features.word.apply(.empty)
        features.shell.selectedTab = .stats
        features.sidebar.selectedCorpusID = nil
        features.library.selectCorpus(nil)
        features.library.selectRecycleEntry(nil)
        features.library.selectFolder(nil)
        features.sidebar.clearError()
        features.library.setStatus(wordZText("已创建空白工作区。", "Created a new workspace.", mode: .system))

        do {
            try await repository.saveWorkspaceState(emptyDraft)
            sessionStore.applySavedDraft(emptyDraft)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func restoreSavedWorkspace(features: WorkspaceFeatureSet) async {
        guard let workspaceSnapshot = sessionStore.workspaceSnapshot else { return }
        sessionStore.beginRestore()
        defer {
            sessionStore.finishRestore()
            persistenceWorkflow.applyWorkspacePresentation(
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            persistenceWorkflow.syncWindowDocumentState(features: features)
        }

        resetFeatureResults(features: features)
        applyWorkspaceSnapshot(workspaceSnapshot, features: features)
        features.sidebar.clearError()
        features.library.setStatus(wordZText("已恢复最近保存的工作区。", "Restored the last saved workspace.", mode: .system))
    }

    func handleCorpusSelectionChange(features: WorkspaceFeatureSet) {
        prepareCorpusSelectionChange(features: features)
        markWorkspaceEdited(features: features)
    }

    func openSelectedCorpus(features: WorkspaceFeatureSet) async {
        setBusy(true, features: features)
        defer { setBusy(false, features: features) }

        do {
            _ = try await libraryCoordinator.openSelection(selectedCorpusID: features.sidebar.selectedCorpusID)
            persistenceWorkflow.applyWorkspacePresentation(
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            persistenceWorkflow.refreshRecentDocuments(features: features)
            features.sidebar.clearError()
            persistenceWorkflow.persistWorkspaceState(
                features: features,
                syncFeatureContexts: syncFeatureContexts
            )
            persistenceWorkflow.syncWindowDocumentState(features: features)
        } catch {
            features.sidebar.setError(error.localizedDescription)
        }
    }

    func prepareCorpusSelectionChange(features: WorkspaceFeatureSet) {
        if libraryCoordinator.handleSelectionChange(to: features.sidebar.selectedCorpusID) {
            resetFeatureResults(features: features)
        }
    }

    func markWorkspaceEdited(features: WorkspaceFeatureSet) {
        guard !sessionStore.isRestoringState else { return }
        sessionStore.markEdited()
        persistenceWorkflow.applyWorkspacePresentation(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
        persistenceWorkflow.persistWorkspaceState(
            features: features,
            syncFeatureContexts: syncFeatureContexts
        )
        persistenceWorkflow.syncWindowDocumentState(features: features)
    }

    func markInputStateEdited(features: WorkspaceFeatureSet) {
        guard !sessionStore.isRestoringState else { return }
        sessionStore.markEdited()
        persistenceWorkflow.persistWorkspaceState(
            features: features,
            refreshPresentationAfterSave: false,
            syncWindowAfterSave: true,
            syncFeatureContexts: syncFeatureContexts
        )
    }

    func applyWorkspaceSnapshot(_ workspaceSnapshot: WorkspaceSnapshotSummary, features: WorkspaceFeatureSet) {
        features.cluster.syncLibrarySnapshot(features.sidebar.librarySnapshot)
        features.stats.apply(workspaceSnapshot)
        features.word.apply(workspaceSnapshot)
        features.tokenize.apply(workspaceSnapshot)
        features.topics.apply(workspaceSnapshot)
        features.compare.apply(workspaceSnapshot)
        features.sentiment.apply(workspaceSnapshot)
        features.keyword.apply(workspaceSnapshot)
        features.chiSquare.apply(workspaceSnapshot)
        features.plot.apply(workspaceSnapshot)
        features.ngram.apply(workspaceSnapshot)
        features.cluster.apply(workspaceSnapshot)
        features.kwic.apply(workspaceSnapshot)
        features.collocate.apply(workspaceSnapshot)

        if let restoredTab = WorkspaceDetailTab.fromSnapshotValue(workspaceSnapshot.currentTab) {
            features.shell.selectedTab = restoredTab.mainWorkspaceTab
        }

        let preferredFolderID = workspaceSnapshot.currentLibraryFolderId
        if preferredFolderID == "all" || preferredFolderID.isEmpty {
            features.library.selectFolder(nil)
        } else {
            features.library.selectFolder(preferredFolderID)
        }

        let selectedCorpusSet = features.sidebar.librarySnapshot.corpusSets.first(where: { $0.id == workspaceSnapshot.selectedCorpusSetID })
        features.sidebar.applyCorpusSet(selectedCorpusSet)
        features.library.selectCorpusSet(selectedCorpusSet?.id)

        let preferredCorpusID = workspaceSnapshot.corpusIds.first
        if let preferredCorpusID,
           features.sidebar.filteredCorpora.contains(where: { $0.id == preferredCorpusID }) {
            features.sidebar.selectedCorpusID = preferredCorpusID
            features.library.selectCorpus(preferredCorpusID)
            return
        }

        let preferredName = workspaceSnapshot.corpusNames.first
        if let preferredName,
           let matchingCorpus = features.sidebar.filteredCorpora.first(where: { $0.name == preferredName }) {
            features.sidebar.selectedCorpusID = matchingCorpus.id
            features.library.selectCorpus(matchingCorpus.id)
            return
        }

        if let currentSelection = features.sidebar.selectedCorpusID,
           features.sidebar.filteredCorpora.contains(where: { $0.id == currentSelection }) {
            features.library.selectCorpus(currentSelection)
            return
        }

        let fallbackCorpusID = features.library.selectedFolderID == nil
            ? features.sidebar.librarySnapshot.corpora.first?.id
            : features.sidebar.librarySnapshot.corpora.first(where: { $0.folderId == features.library.selectedFolderID })?.id
        features.sidebar.selectedCorpusID = fallbackCorpusID
        features.library.selectCorpus(fallbackCorpusID)
    }

    func resetFeatureResults(features: WorkspaceFeatureSet) {
        features.stats.reset()
        features.word.reset()
        features.tokenize.reset()
        features.topics.reset()
        features.compare.reset()
        features.sentiment.reset()
        features.keyword.reset()
        features.chiSquare.reset()
        features.plot.reset()
        features.ngram.reset()
        features.cluster.reset()
        features.kwic.reset()
        features.collocate.reset()
        features.locator.reset()
    }

    func syncFeatureContexts(features: WorkspaceFeatureSet) {
        let context = sceneStore.context
        features.shell.applyContext(context)
        features.sidebar.applyContext(context)
        features.library.applyContext(context)
        features.settings.applyContext(context)
    }

    private func updateSelectionAvailability(features: WorkspaceFeatureSet) {
        features.shell.updateSelectionAvailability(
            hasSelection: features.sidebar.selectedCorpusID != nil,
            hasSourceReaderContext: false,
            hasPreviewableCorpus: !(features.library.selectedCorpus?.representedPath.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty,
            corpusCount: features.sidebar.librarySnapshot.corpora.count,
            hasLocatorSource: features.kwic.primaryLocatorSource != nil,
            hasExportableContent: false,
            runSentimentEnabled: features.sentiment.canRun(
                hasOpenedCorpus: features.sidebar.selectedCorpusID != nil,
                hasKWICRows: features.kwic.scene?.rows.isEmpty == false
            )
        )
    }

    private func setBusy(_ isBusy: Bool, features: WorkspaceFeatureSet) {
        features.shell.isBusy = isBusy
        features.sidebar.setBusy(isBusy)
        features.library.setBusy(isBusy)
    }
}
