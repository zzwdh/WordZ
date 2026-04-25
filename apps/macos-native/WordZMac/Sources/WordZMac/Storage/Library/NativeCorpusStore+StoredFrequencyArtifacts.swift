import Foundation

extension NativeCorpusStore: StoredFrequencyArtifactProvidingLibraryStore {
    func loadStoredFrequencyArtifact(corpusId: String) throws -> StoredFrequencyArtifact? {
        let corpora = try loadCorpora()
        guard let existingRecord = corpora.first(where: { $0.id == corpusId }) else {
            return nil
        }
        let (_, storageURL) = try resolvedStorage(for: existingRecord)
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return nil
        }
        return try NativeCorpusDatabaseSupport.readStoredFrequencyArtifact(at: storageURL)
    }
}
