import Foundation

@MainActor
protocol LibraryCoordinating: AnyObject {
    func openSelection(selectedCorpusID: String?) async throws -> OpenedCorpus
    func ensureOpenedCorpus(selectedCorpusID: String?) async throws -> OpenedCorpus
    func handleSelectionChange(to selectedCorpusID: String?) -> Bool
}

