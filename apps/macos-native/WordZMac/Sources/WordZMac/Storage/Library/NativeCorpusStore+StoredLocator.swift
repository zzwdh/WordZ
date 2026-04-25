import Foundation

extension NativeCorpusStore: StoredLocatorProvidingLibraryStore {
    func loadStoredLocatorResult(
        corpusId: String,
        sentenceId: Int,
        nodeIndex: Int,
        leftWindow: Int,
        rightWindow: Int
    ) throws -> LocatorResult? {
        let records = try loadCorpora()
        guard let existingRecord = records.first(where: { $0.id == corpusId }) else {
            return nil
        }

        let (_, storageURL) = try resolvedStorage(for: existingRecord)
        return try NativeCorpusDatabaseSupport.readStoredLocatorResult(
            at: storageURL,
            sentenceId: sentenceId,
            nodeIndex: nodeIndex,
            leftWindow: leftWindow,
            rightWindow: rightWindow
        )
    }
}
