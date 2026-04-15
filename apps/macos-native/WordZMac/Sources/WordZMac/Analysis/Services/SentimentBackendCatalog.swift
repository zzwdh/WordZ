import Foundation

enum SentimentBackendCatalog {
    static let sharedModelManager = SentimentModelManager()

    static func availableBackends(
        modelManager: SentimentModelManager = sharedModelManager
    ) -> [SentimentBackendKind] {
        var backends: [SentimentBackendKind] = [.lexicon]
        if modelManager.isModelAvailable {
            backends.append(.coreML)
        }
        return backends
    }
}

