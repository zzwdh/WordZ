import Foundation

@MainActor
final class WorkspaceSessionStore {
    private(set) var workspaceSnapshot: WorkspaceSnapshotSummary?
    private(set) var openedCorpus: OpenedCorpus?
    private(set) var openedCorpusSourceID: String?
    private(set) var isDocumentEdited = false
    private(set) var isRestoringState = false

    func applyBootstrap(snapshot: WorkspaceSnapshotSummary) {
        workspaceSnapshot = snapshot
    }

    func applySavedDraft(_ draft: WorkspaceStateDraft) {
        workspaceSnapshot = WorkspaceSnapshotSummary(draft: draft)
        isDocumentEdited = false
    }

    func beginRestore() {
        isRestoringState = true
    }

    func finishRestore() {
        isRestoringState = false
        isDocumentEdited = false
    }

    func setOpenedCorpus(_ corpus: OpenedCorpus, sourceID: String) {
        openedCorpus = corpus
        openedCorpusSourceID = sourceID
    }

    func resetOpenedCorpus() {
        openedCorpus = nil
        openedCorpusSourceID = nil
    }

    func matchesOpenedCorpusSource(_ sourceID: String?) -> Bool {
        guard let sourceID else { return false }
        return openedCorpusSourceID == sourceID && openedCorpus != nil
    }

    func markEdited() {
        guard !isRestoringState else { return }
        isDocumentEdited = true
    }

    func resetToEmptyWorkspace() {
        workspaceSnapshot = .empty
        resetOpenedCorpus()
        isDocumentEdited = false
    }
}
