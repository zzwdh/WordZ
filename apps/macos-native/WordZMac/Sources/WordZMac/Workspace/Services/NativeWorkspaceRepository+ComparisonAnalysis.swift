import Foundation

extension NativeWorkspaceRepositoryCore {
    func runCompare(comparisonEntries: [CompareRequestEntry]) async throws -> CompareResult {
        let key = NativeAnalysisResultCacheKey.compare(entries: comparisonEntries)
        let analysisRuntime = self.analysisRuntime
        let preparedStoredCorpora = try prepareStoredCompareCorpora(from: comparisonEntries)
        return try await cachedAnalysisResult(for: key) {
            if let preparedStoredCorpora {
                return await analysisRuntime.runPreparedCompare(preparedCorpora: preparedStoredCorpora)
            }
            return await analysisRuntime.runCompare(comparisonEntries: comparisonEntries)
        }
    }

    func runKeywordSuite(_ request: KeywordSuiteRunRequest) async throws -> KeywordSuiteResult {
        let key = NativeAnalysisResultCacheKey.keywordSuite(request: request)
        let analysisRuntime = self.analysisRuntime
        let preparedStoredRequest = try prepareStoredKeywordSuiteRequest(from: request)
        return try await cachedAnalysisResult(for: key) {
            if let preparedStoredRequest {
                return await analysisRuntime.runPreparedKeywordSuite(preparedStoredRequest)
            }
            return await analysisRuntime.runKeywordSuite(request)
        }
    }

    func runKeyword(
        targetEntry: KeywordRequestEntry,
        referenceEntry: KeywordRequestEntry,
        options: KeywordPreprocessingOptions
    ) async throws -> KeywordResult {
        let key = NativeAnalysisResultCacheKey.keyword(
            targetEntry: targetEntry,
            referenceEntry: referenceEntry,
            options: options
        )
        let analysisRuntime = self.analysisRuntime
        return try await cachedAnalysisResult(for: key) {
            await analysisRuntime.runKeyword(
                targetEntry: targetEntry,
                referenceEntry: referenceEntry,
                options: options
            )
        }
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) async -> ChiSquareResult {
        await analysisRuntime.runChiSquare(a: a, b: b, c: c, d: d, yates: yates)
    }
}
