import Foundation

@MainActor
extension LibraryCoordinator {
    func handleSelectionChange(to selectedCorpusID: String?) -> Bool {
        guard !sessionStore.matchesOpenedCorpusSource(selectedCorpusID) else {
            return false
        }
        sessionStore.resetOpenedCorpus()
        return true
    }
}
