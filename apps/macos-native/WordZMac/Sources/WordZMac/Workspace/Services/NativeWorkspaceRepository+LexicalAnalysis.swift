import Foundation

extension NativeWorkspaceRepositoryCore {
    func runStats(text: String) async throws -> StatsResult {
        let documentKey = DocumentCacheKey(text: text)
        let key = NativeAnalysisResultCacheKey.stats(digest: documentKey.textDigest)
        if let artifact = storedFrequencyArtifactsByTextDigest[documentKey.textDigest] {
            return try await cachedAnalysisResult(for: key) {
                artifact.statsResult
            }
        }
        let analysisRuntime = self.analysisRuntime
        return try await cachedAnalysisResult(for: key) {
            await analysisRuntime.runStats(text: text, documentKey: documentKey)
        }
    }

    func runTokenize(text: String) async throws -> TokenizeResult {
        let documentKey = DocumentCacheKey(text: text)
        let key = NativeAnalysisResultCacheKey.tokenize(digest: documentKey.textDigest)
        if let artifact = storedTokenizedArtifactsByTextDigest[documentKey.textDigest] {
            let analysisRuntime = self.analysisRuntime
            return try await cachedAnalysisResult(for: key) {
                await analysisRuntime.runTokenize(artifact: artifact)
            }
        }
        let analysisRuntime = self.analysisRuntime
        return try await cachedAnalysisResult(for: key) {
            await analysisRuntime.runTokenize(text: text, documentKey: documentKey)
        }
    }

    func runNgram(text: String, n: Int) async throws -> NgramResult {
        let documentKey = DocumentCacheKey(text: text)
        let key = NativeAnalysisResultCacheKey.ngram(digest: documentKey.textDigest, n: n)
        if let artifact = storedTokenizedArtifactsByTextDigest[documentKey.textDigest] {
            let analysisRuntime = self.analysisRuntime
            return try await cachedAnalysisResult(for: key) {
                await analysisRuntime.runNgram(artifact: artifact, n: n)
            }
        }
        let analysisRuntime = self.analysisRuntime
        return try await cachedAnalysisResult(for: key) {
            await analysisRuntime.runNgram(text: text, n: n, documentKey: documentKey)
        }
    }
}
