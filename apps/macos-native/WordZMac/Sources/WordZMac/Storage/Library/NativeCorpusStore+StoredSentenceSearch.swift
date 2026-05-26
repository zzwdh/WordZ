import Foundation

extension NativeCorpusStore: StoredSentenceSearchProvidingLibraryStore {
    func loadCandidateSentenceIDs(corpusId: String, phraseTokens: [String]) throws -> [Int] {
        guard let storageURL = try storedDatabaseURL(for: corpusId) else { return [] }
        return try NativeCorpusDatabaseSupport.loadCandidateSentenceIDs(
            at: storageURL,
            phraseTokens: phraseTokens
        )
    }
}
