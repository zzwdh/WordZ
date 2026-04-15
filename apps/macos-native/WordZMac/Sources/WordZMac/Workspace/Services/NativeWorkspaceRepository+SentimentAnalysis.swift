import Foundation

extension NativeWorkspaceRepositoryCore {
    func runSentiment(_ request: SentimentRunRequest) async throws -> SentimentRunResult {
        let key = NativeAnalysisResultCacheKey.sentiment(request: request)
        let analysisRuntime = self.analysisRuntime
        return try await cachedAnalysisResult(for: key) {
            await analysisRuntime.runSentiment(request)
        }
    }
}
