import Foundation

extension NativeWorkspaceRepositoryCore {
    func ensureReady() throws {
        try storage.ensureInitialized()
    }

    func invalidateOpenedCorpusCache(corpusId: String? = nil) {
        if let corpusId {
            openedCorpusCache[corpusId] = nil
        } else {
            openedCorpusCache.removeAll()
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
}
