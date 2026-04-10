import Foundation

@MainActor
extension WorkspaceFlowCoordinator {
    func restoreSelectionFromWorkspace(
        features: WorkspaceFeatureSet,
        restoreWorkspace: Bool
    ) {
        sessionStore.beginRestore()
        defer {
            sessionStore.finishRestore()
            features.shell.updateSelectionAvailability(
                hasSelection: features.sidebar.selectedCorpusID != nil,
                hasPreviewableCorpus: !(features.library.selectedCorpus?.representedPath.trimmingCharacters(in: .whitespacesAndNewlines) ?? "").isEmpty,
                corpusCount: features.sidebar.librarySnapshot.corpora.count,
                hasLocatorSource: features.kwic.primaryLocatorSource != nil,
                hasExportableContent: false
            )
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
            applyWorkspacePresentation(features: features)
            syncWindowDocumentState(features: features)
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
            applyWorkspacePresentation(features: features)
            syncWindowDocumentState(features: features)
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

    func prepareCorpusSelectionChange(features: WorkspaceFeatureSet) {
        if libraryCoordinator.handleSelectionChange(to: features.sidebar.selectedCorpusID) {
            resetFeatureResults(features: features)
        }
    }

    func markWorkspaceEdited(features: WorkspaceFeatureSet) {
        guard !sessionStore.isRestoringState else { return }
        sessionStore.markEdited()
        applyWorkspacePresentation(features: features)
        persistWorkspaceState(features: features)
        syncWindowDocumentState(features: features)
    }

    func markInputStateEdited(features: WorkspaceFeatureSet) {
        guard !sessionStore.isRestoringState else { return }
        sessionStore.markEdited()
        persistWorkspaceState(
            features: features,
            refreshPresentationAfterSave: false,
            syncWindowAfterSave: true
        )
    }

    func applyWorkspacePresentation(features: WorkspaceFeatureSet) {
        let presentation = workspacePresentation.buildPresentation(
            appInfo: sceneStore.appInfoSnapshot,
            selectedCorpus: features.sidebar.selectedCorpus,
            openedCorpus: sessionStore.openedCorpus,
            workspaceSnapshot: sessionStore.workspaceSnapshot
        )
        sceneStore.applyPresentation(presentation)
        syncFeatureContexts(features: features)
    }

    func syncWindowDocumentState(features: WorkspaceFeatureSet) {
        let presentation = workspacePresentation.buildPresentation(
            appInfo: sceneStore.appInfoSnapshot,
            selectedCorpus: features.sidebar.selectedCorpus,
            openedCorpus: sessionStore.openedCorpus,
            workspaceSnapshot: sessionStore.workspaceSnapshot
        )
        windowDocumentController.sync(
            displayName: presentation.displayName,
            representedPath: presentation.representedPath,
            edited: sessionStore.isDocumentEdited
        )
    }
}
