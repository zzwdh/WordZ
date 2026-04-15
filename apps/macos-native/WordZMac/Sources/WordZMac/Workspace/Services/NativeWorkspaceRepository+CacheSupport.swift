import Foundation

extension NativeWorkspaceRepositoryCore {
    func ensureReady() throws {
        try storage.ensureInitialized()
    }

    func invalidateOpenedCorpusCache(corpusId: String? = nil) {
        if let corpusId {
            if let cached = openedCorpusCache[corpusId] {
                let digest = DocumentCacheKey(text: cached.content).textDigest
                storedFrequencyArtifactsByTextDigest[digest] = nil
                storedTokenizedArtifactsByTextDigest[digest] = nil
                storedTokenPositionIndexesByTextDigest[digest] = nil
                storedCorpusIDsByTextDigest[digest] = nil
            }
            openedCorpusCache[corpusId] = nil
        } else {
            openedCorpusCache.removeAll()
            storedFrequencyArtifactsByTextDigest.removeAll()
            storedTokenizedArtifactsByTextDigest.removeAll()
            storedTokenPositionIndexesByTextDigest.removeAll()
            storedCorpusIDsByTextDigest.removeAll()
        }
    }

    func invalidateCorpusInfoCache(corpusId: String? = nil) {
        if let corpusId {
            corpusInfoCache[corpusId] = nil
        } else {
            corpusInfoCache.removeAll()
        }
    }

    func invalidateCompareCache() {
        analysisResultCache.remove(kind: "compare")
        analysisResultCache.remove(kind: "keyword")
    }

    func invalidateStoredFrequencyArtifactCache(corpusId: String? = nil) {
        if let corpusId {
            if let cached = storedFrequencyArtifactsByCorpusID[corpusId], !cached.textDigest.isEmpty {
                storedFrequencyArtifactsByTextDigest[cached.textDigest] = nil
            }
            storedFrequencyArtifactsByCorpusID[corpusId] = nil
        } else {
            storedFrequencyArtifactsByCorpusID.removeAll()
            storedFrequencyArtifactsByTextDigest.removeAll()
        }
    }

    func invalidateStoredTokenizedArtifactCache(corpusId: String? = nil) {
        if let corpusId {
            if let cached = storedTokenizedArtifactsByCorpusID[corpusId], !cached.textDigest.isEmpty {
                storedTokenizedArtifactsByTextDigest[cached.textDigest] = nil
                storedCorpusIDsByTextDigest[cached.textDigest] = nil
            }
            storedTokenizedArtifactsByCorpusID[corpusId] = nil
        } else {
            storedTokenizedArtifactsByCorpusID.removeAll()
            storedTokenizedArtifactsByTextDigest.removeAll()
            storedCorpusIDsByTextDigest.removeAll()
        }
    }

    func invalidateStoredTokenPositionIndexCache(corpusId: String? = nil) {
        if let corpusId {
            if let cached = storedTokenPositionIndexesByCorpusID[corpusId], !cached.textDigest.isEmpty {
                storedTokenPositionIndexesByTextDigest[cached.textDigest] = nil
            }
            storedTokenPositionIndexesByCorpusID[corpusId] = nil
        } else {
            storedTokenPositionIndexesByCorpusID.removeAll()
            storedTokenPositionIndexesByTextDigest.removeAll()
        }
    }

    func storedFrequencyArtifact(for corpusId: String) throws -> StoredFrequencyArtifact? {
        if let cached = storedFrequencyArtifactsByCorpusID[corpusId] {
            return cached
        }
        guard let store = storage as? any StoredFrequencyArtifactProvidingLibraryStore,
              let artifact = try store.loadStoredFrequencyArtifact(corpusId: corpusId) else {
            return nil
        }
        storedFrequencyArtifactsByCorpusID[corpusId] = artifact
        return artifact
    }

    func cacheStoredFrequencyArtifact(for corpusId: String, text: String) throws {
        guard let artifact = try storedFrequencyArtifact(for: corpusId) else { return }
        let textDigest = DocumentCacheKey(text: text).textDigest
        guard artifact.textDigest.isEmpty || artifact.textDigest == textDigest else { return }
        storedFrequencyArtifactsByTextDigest[textDigest] = artifact
    }

    func storedTokenizedArtifact(for corpusId: String) throws -> StoredTokenizedArtifact? {
        if let cached = storedTokenizedArtifactsByCorpusID[corpusId] {
            return cached
        }
        guard let store = storage as? any StoredTokenizedArtifactProvidingLibraryStore,
              let artifact = try store.loadStoredTokenizedArtifact(corpusId: corpusId) else {
            return nil
        }
        storedTokenizedArtifactsByCorpusID[corpusId] = artifact
        return artifact
    }

    func cacheStoredTokenizedArtifact(for corpusId: String, text: String) throws {
        guard let artifact = try storedTokenizedArtifact(for: corpusId) else { return }
        let textDigest = DocumentCacheKey(text: text).textDigest
        guard artifact.textDigest.isEmpty || artifact.textDigest == textDigest else { return }
        storedTokenizedArtifactsByTextDigest[textDigest] = artifact
        storedCorpusIDsByTextDigest[textDigest] = corpusId
    }

    func storedTokenPositionIndex(for corpusId: String) throws -> StoredTokenPositionIndexArtifact? {
        if let cached = storedTokenPositionIndexesByCorpusID[corpusId] {
            return cached
        }
        guard let store = storage as? any StoredTokenPositionIndexProvidingLibraryStore,
              let artifact = try store.loadStoredTokenPositionIndex(corpusId: corpusId) else {
            return nil
        }
        storedTokenPositionIndexesByCorpusID[corpusId] = artifact
        return artifact
    }

    func storedTokenPositionIndex(forTextDigest textDigest: String) throws -> StoredTokenPositionIndexArtifact? {
        if let cached = storedTokenPositionIndexesByTextDigest[textDigest] {
            return cached
        }
        guard let corpusId = storedCorpusIDsByTextDigest[textDigest],
              let artifact = try storedTokenPositionIndex(for: corpusId) else {
            return nil
        }
        guard artifact.textDigest.isEmpty || artifact.textDigest == textDigest else {
            return nil
        }
        storedTokenPositionIndexesByTextDigest[textDigest] = artifact
        return artifact
    }

    func prepareStoredCompareCorpora(from entries: [CompareRequestEntry]) throws -> [PreparedCompareCorpus]? {
        var prepared: [PreparedCompareCorpus] = []
        prepared.reserveCapacity(entries.count)

        for entry in entries {
            guard let artifact = try storedFrequencyArtifact(for: entry.corpusId) else {
                return nil
            }
            let contentDigest = DocumentCacheKey(text: entry.content).textDigest
            guard artifact.textDigest == contentDigest else {
                return nil
            }
            storedFrequencyArtifactsByTextDigest[contentDigest] = artifact
            prepared.append(
                PreparedCompareCorpus(
                    entry: entry,
                    tokenCount: artifact.tokenCount,
                    typeCount: artifact.typeCount,
                    ttr: artifact.ttr,
                    sttr: artifact.sttr,
                    topWord: artifact.topWord,
                    topWordCount: artifact.topWordCount,
                    frequency: artifact.frequencyMap
                )
            )
        }

        return prepared
    }

    func prepareStoredKeywordSuiteRequest(from request: KeywordSuiteRunRequest) throws -> PreparedKeywordSuiteRequest? {
        let preparedFocus = try prepareStoredKeywordSuiteCorpora(from: request.focusEntries)
        let preparedReference = try prepareStoredKeywordSuiteCorpora(from: request.referenceEntries)
        guard preparedFocus != nil || request.focusEntries.isEmpty else {
            return nil
        }
        guard preparedReference != nil || request.referenceEntries.isEmpty else {
            return nil
        }

        return PreparedKeywordSuiteRequest(
            focusCorpora: preparedFocus ?? [],
            referenceCorpora: preparedReference ?? [],
            importedReferenceItems: request.importedReferenceItems,
            focusLabel: request.focusLabel,
            referenceLabel: request.referenceLabel,
            configuration: request.configuration
        )
    }

    private func prepareStoredKeywordSuiteCorpora(
        from entries: [KeywordRequestEntry]
    ) throws -> [PreparedKeywordSuiteCorpus]? {
        var prepared: [PreparedKeywordSuiteCorpus] = []
        prepared.reserveCapacity(entries.count)

        for entry in entries {
            guard let artifact = try storedTokenizedArtifact(for: entry.corpusId) else {
                return nil
            }
            let contentDigest = DocumentCacheKey(text: entry.content).textDigest
            guard artifact.textDigest == contentDigest else {
                return nil
            }
            storedTokenizedArtifactsByTextDigest[contentDigest] = artifact
            prepared.append(
                PreparedKeywordSuiteCorpus(
                    entry: entry,
                    tokenizedArtifact: artifact
                )
            )
        }

        return prepared
    }
}
