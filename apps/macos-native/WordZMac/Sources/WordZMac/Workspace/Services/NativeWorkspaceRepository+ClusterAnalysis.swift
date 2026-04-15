import Foundation

extension NativeWorkspaceRepositoryCore {
    func runCluster(_ request: ClusterRunRequest) async throws -> ClusterResult {
        let key = NativeAnalysisResultCacheKey.cluster(request: request)
        let analysisRuntime = self.analysisRuntime
        return try await cachedAnalysisResult(for: key) {
            await analysisRuntime.runCluster(request)
        }
    }
}
