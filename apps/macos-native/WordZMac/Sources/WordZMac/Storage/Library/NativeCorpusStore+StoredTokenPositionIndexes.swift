import Foundation

extension NativeCorpusStore: StoredTokenPositionIndexProvidingLibraryStore {
    func loadStoredTokenPositionIndex(corpusId: String) throws -> StoredTokenPositionIndexArtifact? {
        let records = try loadCorpora()
        guard let record = records.first(where: { $0.id == corpusId }) else {
            return nil
        }

        let storageURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        return try NativeCorpusDatabaseSupport.readStoredTokenPositionIndexArtifact(at: storageURL)
    }
}
