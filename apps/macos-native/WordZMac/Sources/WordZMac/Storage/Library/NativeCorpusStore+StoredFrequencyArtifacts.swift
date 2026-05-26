import Foundation

extension NativeCorpusStore: StoredFrequencyArtifactProvidingLibraryStore {
    func loadStoredFrequencyArtifact(corpusId: String) throws -> StoredFrequencyArtifact? {
        guard let storageURL = try storedDatabaseURL(for: corpusId) else { return nil }
        guard fileManager.fileExists(atPath: storageURL.path) else {
            return nil
        }
        return try NativeCorpusDatabaseSupport.readStoredFrequencyArtifact(at: storageURL)
    }
}
