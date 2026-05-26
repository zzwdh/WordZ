import Foundation

extension NativeCorpusStore: StoredLocatorProvidingLibraryStore {
    func loadStoredLocatorResult(
        corpusId: String,
        sentenceId: Int,
        nodeIndex: Int,
        leftWindow: Int,
        rightWindow: Int
    ) throws -> LocatorResult? {
        guard let storageURL = try storedDatabaseURL(for: corpusId) else { return nil }
        return try NativeCorpusDatabaseSupport.readStoredLocatorResult(
            at: storageURL,
            sentenceId: sentenceId,
            nodeIndex: nodeIndex,
            leftWindow: leftWindow,
            rightWindow: rightWindow
        )
    }
}
