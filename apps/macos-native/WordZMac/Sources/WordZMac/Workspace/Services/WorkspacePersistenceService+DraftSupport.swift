import Foundation

extension WorkspacePersistenceService {
    func selectedCorpusState(
        selectedCorpus: LibraryCorpusItem?,
        openedCorpus: OpenedCorpus?
    ) -> (ids: [String], names: [String]) {
        let corpusName = openedCorpus?.displayName ?? selectedCorpus?.name ?? ""
        let corpusID = selectedCorpus?.id ?? ""
        return (
            ids: corpusID.isEmpty ? [] : [corpusID],
            names: corpusName.isEmpty ? [] : [corpusName]
        )
    }
}
