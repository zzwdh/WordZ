import Foundation

extension NativeWorkspaceRepositoryCore {
    func runCompare(comparisonEntries: [CompareRequestEntry]) -> CompareResult {
        let key = NativeAnalysisResultCacheKey.compare(entries: comparisonEntries)
        return cachedAnalysisResult(for: key) {
            analysisEngine.runCompare(comparisonEntries: comparisonEntries)
        }
    }

    func runKeyword(
        targetEntry: KeywordRequestEntry,
        referenceEntry: KeywordRequestEntry,
        options: KeywordPreprocessingOptions
    ) -> KeywordResult {
        let key = NativeAnalysisResultCacheKey.keyword(
            targetEntry: targetEntry,
            referenceEntry: referenceEntry,
            options: options
        )
        return cachedAnalysisResult(for: key) {
            analysisEngine.runKeyword(
                targetEntry: targetEntry,
                referenceEntry: referenceEntry,
                options: options
            )
        }
    }

    func runChiSquare(a: Int, b: Int, c: Int, d: Int, yates: Bool) -> ChiSquareResult {
        analysisEngine.runChiSquare(a: a, b: b, c: c, d: d, yates: yates)
    }
}
