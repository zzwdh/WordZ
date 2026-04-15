import Foundation

extension NativeAnalysisEngine {
    func runSentiment(_ request: SentimentRunRequest) -> SentimentRunResult {
        sentimentAnalysisCoordinator().analyze(request)
    }

    private func sentimentAnalysisCoordinator() -> SentimentAnalysisCoordinator {
        let indexDocument = { [unowned self] (text: String, documentKey: DocumentCacheKey?) in
            self.indexedDocument(for: text, documentKey: documentKey)
        }
        return SentimentAnalysisCoordinator(
            lexiconAnalyzer: LexiconSentimentAnalyzer(indexDocument: indexDocument),
            coreMLAnalyzer: CoreMLSentimentAnalyzer(
                modelManager: SentimentBackendCatalog.sharedModelManager,
                indexDocument: indexDocument
            )
        )
    }
}
