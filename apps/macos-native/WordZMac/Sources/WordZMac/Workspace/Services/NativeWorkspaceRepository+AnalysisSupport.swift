import Foundation

extension NativeWorkspaceRepositoryCore {
    func cachedAnalysisResult<T>(
        for key: NativeAnalysisResultCacheKey,
        compute: () throws -> T
    ) rethrows -> T {
        if let cached: T = analysisResultCache.value(for: key) {
            return cached
        }
        let result = try compute()
        analysisResultCache.store(result, for: key)
        return result
    }
}
