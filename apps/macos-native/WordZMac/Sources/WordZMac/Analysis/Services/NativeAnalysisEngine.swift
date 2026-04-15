import Foundation

final class NativeAnalysisEngine: @unchecked Sendable {
    struct DocumentCacheState {
        var documents: [DocumentCacheKey: ParsedDocumentIndex] = [:]
        var order: [DocumentCacheKey] = []
    }

    let maxCachedDocuments: Int
    private let cacheLock = NSLock()
    private var cacheState = DocumentCacheState()

    init(maxCachedDocuments: Int = 6) {
        self.maxCachedDocuments = max(1, maxCachedDocuments)
    }

    var cachedDocumentCountForTesting: Int {
        withCacheState { $0.documents.count }
    }

    var cachedFrequencySummaryCountForTesting: Int {
        let cachedIndexes = withCacheState { Array($0.documents.values) }
        return cachedIndexes.reduce(0) { partialResult, index in
            partialResult + (index.hasComputedFrequencySummary ? 1 : 0)
        }
    }

    func withCacheState<T>(_ operation: (inout DocumentCacheState) -> T) -> T {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return operation(&cacheState)
    }
}
