import Foundation

@MainActor
final class LibraryCoordinator {
    private let repository: any WorkspaceRepository
    private let sessionStore: WorkspaceSessionStore

    init(
        repository: any WorkspaceRepository,
        sessionStore: WorkspaceSessionStore
    ) {
        self.repository = repository
        self.sessionStore = sessionStore
    }

    func handleSelectionChange(to selectedCorpusID: String?) -> Bool {
        guard !sessionStore.matchesOpenedCorpusSource(selectedCorpusID) else {
            return false
        }
        sessionStore.resetOpenedCorpus()
        return true
    }

    func openSelection(selectedCorpusID: String?) async throws -> OpenedCorpus {
        guard let selectedCorpusID else {
            throw selectionRequiredError()
        }
        let corpus = try await repository.openSavedCorpus(corpusId: selectedCorpusID)
        sessionStore.setOpenedCorpus(corpus, sourceID: selectedCorpusID)
        return corpus
    }

    func ensureOpenedCorpus(selectedCorpusID: String?) async throws -> OpenedCorpus {
        if let openedCorpus = sessionStore.openedCorpus,
           sessionStore.matchesOpenedCorpusSource(selectedCorpusID) {
            return openedCorpus
        }
        return try await openSelection(selectedCorpusID: selectedCorpusID)
    }

    private func selectionRequiredError() -> NSError {
        NSError(
            domain: "WordZMac.Workspace",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: "请先从左侧选择一条已保存语料。"]
        )
    }
}
