import Foundation

extension NativeCorpusStore: StoredTokenizedArtifactProvidingLibraryStore {
    func loadStoredTokenizedArtifact(corpusId: String) throws -> StoredTokenizedArtifact? {
        let records = try loadCorpora()
        guard let record = records.first(where: { $0.id == corpusId }) else {
            return nil
        }

        let storageURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        return try NativeCorpusDatabaseSupport.readStoredTokenizedArtifact(at: storageURL)
    }
}
