import Foundation

extension NativeWorkspaceRepositoryCore {
    func runKWIC(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        searchOptions: SearchOptionsState
    ) throws -> KWICResult {
        let documentKey = DocumentCacheKey(text: text)
        let key = NativeAnalysisResultCacheKey.kwic(
            digest: documentKey.textDigest,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            searchOptions: searchOptions
        )
        return try cachedAnalysisResult(for: key) {
            try analysisEngine.runKWIC(
                text: text,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                searchOptions: searchOptions,
                documentKey: documentKey
            )
        }
    }

    func runCollocate(
        text: String,
        keyword: String,
        leftWindow: Int,
        rightWindow: Int,
        minFreq: Int,
        searchOptions: SearchOptionsState
    ) throws -> CollocateResult {
        let documentKey = DocumentCacheKey(text: text)
        let key = NativeAnalysisResultCacheKey.collocate(
            digest: documentKey.textDigest,
            keyword: keyword,
            leftWindow: leftWindow,
            rightWindow: rightWindow,
            minFreq: minFreq,
            searchOptions: searchOptions
        )
        return try cachedAnalysisResult(for: key) {
            try analysisEngine.runCollocate(
                text: text,
                keyword: keyword,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                minFreq: minFreq,
                searchOptions: searchOptions,
                documentKey: documentKey
            )
        }
    }

    func runLocator(text: String, sentenceId: Int, nodeIndex: Int, leftWindow: Int, rightWindow: Int) -> LocatorResult {
        let documentKey = DocumentCacheKey(text: text)
        let key = NativeAnalysisResultCacheKey.locator(
            digest: documentKey.textDigest,
            sentenceId: sentenceId,
            nodeIndex: nodeIndex,
            leftWindow: leftWindow,
            rightWindow: rightWindow
        )
        return cachedAnalysisResult(for: key) {
            analysisEngine.runLocator(
                text: text,
                sentenceId: sentenceId,
                nodeIndex: nodeIndex,
                leftWindow: leftWindow,
                rightWindow: rightWindow,
                documentKey: documentKey
            )
        }
    }
}
