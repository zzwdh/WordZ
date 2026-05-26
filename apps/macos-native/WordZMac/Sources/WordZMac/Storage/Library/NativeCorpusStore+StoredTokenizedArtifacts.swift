import Foundation

extension NativeCorpusStore: StoredTokenizedArtifactProvidingLibraryStore {
    func loadStoredTokenizedArtifact(corpusId: String) throws -> StoredTokenizedArtifact? {
        guard let storageURL = try storedDatabaseURL(for: corpusId) else { return nil }
        return try NativeCorpusDatabaseSupport.readStoredTokenizedArtifact(at: storageURL)
    }
}
