import Foundation

@MainActor
extension WorkspaceAnalysisWorkflowService {
    func concordanceSavedSetSourceExists(
        _ set: ConcordanceSavedSet,
        features: WorkspaceFeatureSet
    ) -> Bool {
        if let corpusSetID = CorpusSetSourceID.corpusSetID(from: set.corpusID) {
            return features.sidebar.librarySnapshot.corpusSets.contains(where: { $0.id == corpusSetID })
        }
        return features.sidebar.librarySnapshot.corpora.contains(where: { $0.id == set.corpusID })
    }
}
