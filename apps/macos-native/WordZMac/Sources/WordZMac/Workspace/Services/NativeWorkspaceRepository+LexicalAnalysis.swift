import Foundation

extension NativeWorkspaceRepositoryCore {
    func runStats(text: String) -> StatsResult {
        let documentKey = DocumentCacheKey(text: text)
        let key = NativeAnalysisResultCacheKey.stats(digest: documentKey.textDigest)
        return cachedAnalysisResult(for: key) {
            analysisEngine.runStats(text: text, documentKey: documentKey)
        }
    }

    func runTokenize(text: String) -> TokenizeResult {
        let documentKey = DocumentCacheKey(text: text)
        let key = NativeAnalysisResultCacheKey.tokenize(digest: documentKey.textDigest)
        return cachedAnalysisResult(for: key) {
            analysisEngine.runTokenize(text: text, documentKey: documentKey)
        }
    }

    func runNgram(text: String, n: Int) -> NgramResult {
        let documentKey = DocumentCacheKey(text: text)
        let key = NativeAnalysisResultCacheKey.ngram(digest: documentKey.textDigest, n: n)
        return cachedAnalysisResult(for: key) {
            analysisEngine.runNgram(text: text, n: n, documentKey: documentKey)
        }
    }
}
