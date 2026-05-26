import Foundation

extension NativeCorpusStore: StoredTokenPositionIndexProvidingLibraryStore {
    func loadStoredTokenPositionIndex(corpusId: String) throws -> StoredTokenPositionIndexArtifact? {
        guard let storageURL = try storedDatabaseURL(for: corpusId) else { return nil }
        return try NativeCorpusDatabaseSupport.readStoredTokenPositionIndexArtifact(at: storageURL)
    }
}
