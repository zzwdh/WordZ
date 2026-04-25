import Foundation

extension NativeCorpusStore: StoredSentenceSearchProvidingLibraryStore {
    func loadCandidateSentenceIDs(corpusId: String, phraseTokens: [String]) throws -> [Int] {
        let records = try loadCorpora()
        guard let existingRecord = records.first(where: { $0.id == corpusId }) else {
            return []
        }

        let (_, storageURL) = try resolvedStorage(for: existingRecord)
        return try NativeCorpusDatabaseSupport.loadCandidateSentenceIDs(
            at: storageURL,
            phraseTokens: phraseTokens
        )
    }
}
