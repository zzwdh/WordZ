import Foundation

extension NativeCorpusStore: StoredFrequencyArtifactProvidingLibraryStore {
    func loadStoredFrequencyArtifact(corpusId: String) throws -> StoredFrequencyArtifact? {
        let corpora = try loadCorpora()
        guard let record = corpora.first(where: { $0.id == corpusId }) else {
            return nil
        }
        let storageURL = corporaDirectoryURL.appendingPathComponent(record.storageFileName)
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return nil
        }
        return try NativeCorpusDatabaseSupport.readStoredFrequencyArtifact(at: storageURL)
    }
}
