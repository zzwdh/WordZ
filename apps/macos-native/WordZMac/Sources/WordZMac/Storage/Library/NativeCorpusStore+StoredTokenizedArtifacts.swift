import Foundation

extension NativeCorpusStore: StoredTokenizedArtifactProvidingLibraryStore {
    func loadStoredTokenizedArtifact(corpusId: String) throws -> StoredTokenizedArtifact? {
        let records = try loadCorpora()
        guard let existingRecord = records.first(where: { $0.id == corpusId }) else {
            return nil
        }

        let (_, storageURL) = try resolvedStorage(for: existingRecord)
        return try NativeCorpusDatabaseSupport.readStoredTokenizedArtifact(at: storageURL)
    }
}
