import Foundation

final class NativeAnalysisEngine {
    let maxCachedDocuments: Int
    var documentCache: [DocumentCacheKey: ParsedDocumentIndex] = [:]
    var cacheOrder: [DocumentCacheKey] = []

    init(maxCachedDocuments: Int = 6) {
        self.maxCachedDocuments = max(1, maxCachedDocuments)
    }

    var cachedDocumentCountForTesting: Int {
        documentCache.count
    }

    var cachedFrequencySummaryCountForTesting: Int {
        documentCache.values.reduce(0) { partialResult, index in
            partialResult + (index.hasComputedFrequencySummary ? 1 : 0)
        }
    }
}
