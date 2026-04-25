import Foundation

extension NativeCorpusStore: StoredTokenPositionIndexProvidingLibraryStore {
    func loadStoredTokenPositionIndex(corpusId: String) throws -> StoredTokenPositionIndexArtifact? {
        let records = try loadCorpora()
        guard let existingRecord = records.first(where: { $0.id == corpusId }) else {
            return nil
        }

        let (_, storageURL) = try resolvedStorage(for: existingRecord)
        return try NativeCorpusDatabaseSupport.readStoredTokenPositionIndexArtifact(at: storageURL)
    }
}
