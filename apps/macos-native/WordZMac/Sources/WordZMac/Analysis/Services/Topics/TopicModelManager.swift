import NaturalLanguage
import Foundation
import WordZAnalysis

protocol TopicAnalysisEngine: AnyObject {
    func analyze(
        text: String,
        options: TopicAnalysisOptions,
        progress: (@Sendable (TopicAnalysisProgress) -> Void)?
    ) async throws -> TopicAnalysisResult
}

struct TopicEmbeddingInput {
    let text: String
    let tokens: [String]
    let keywordTerms: [String]
    let keywordBigrams: [String]
}

final class TopicEmbeddingModel {
    let manifest: TopicModelManifest
    let providerLabel: String
    let providerRevision: String
    let isPrimaryProvider: Bool
    let expectedDimensions: Int

    private let vectorProvider: (TopicEmbeddingInput) -> [Double]?

    init(
        manifest: TopicModelManifest,
        providerLabel: String,
        providerRevision: String,
        isPrimaryProvider: Bool,
        expectedDimensions: Int,
        vectorProvider: @escaping (TopicEmbeddingInput) -> [Double]?
    ) {
        self.manifest = manifest
        self.providerLabel = providerLabel
        self.providerRevision = providerRevision
        self.isPrimaryProvider = isPrimaryProvider
        self.expectedDimensions = expectedDimensions
        self.vectorProvider = vectorProvider
    }

    func vector(for input: TopicEmbeddingInput) -> [Double]? {
        vectorProvider(input)
    }
}

final class TopicModelManager {
    let bundle: Bundle
    let manifestProvider: () throws -> Data
    let localEmbeddingProvider: (String) throws -> Data
    let systemEmbeddingProvider: () -> NLEmbedding?
    let systemSentenceVectorProvider: ((String) -> [Double]?)?
    private var cachedModel: TopicEmbeddingModel?

    init(
        bundle: Bundle = WordZAnalysisResources.bundle,
        manifestProvider: (() throws -> Data)? = nil,
        localEmbeddingProvider: ((String) throws -> Data)? = nil,
        systemEmbeddingProvider: (() -> NLEmbedding?)? = nil,
        systemSentenceVectorProvider: ((String) -> [Double]?)? = nil
    ) {
        self.bundle = bundle
        self.manifestProvider = manifestProvider ?? {
            guard let url = bundle.url(forResource: "TopicModelManifest", withExtension: "json") else {
                throw TopicAnalysisError.missingModelManifest
            }
            return try Data(contentsOf: url)
        }
        self.localEmbeddingProvider = localEmbeddingProvider ?? { resourceName in
            guard let url = bundle.url(forResource: resourceName, withExtension: "json") else {
                throw TopicAnalysisError.missingModelManifest
            }
            return try Data(contentsOf: url)
        }
        self.systemEmbeddingProvider = systemEmbeddingProvider ?? {
            NLEmbedding.sentenceEmbedding(for: .english)
        }
        self.systemSentenceVectorProvider = systemSentenceVectorProvider
    }

    func loadModel() throws -> TopicEmbeddingModel {
        if let cachedModel {
            return cachedModel
        }

        let manifestData: Data
        do {
            manifestData = try manifestProvider()
        } catch let error as TopicAnalysisError {
            throw error
        } catch {
            throw TopicAnalysisError.missingModelManifest
        }

        let manifest: TopicModelManifest
        do {
            manifest = try JSONDecoder().decode(TopicModelManifest.self, from: manifestData)
        } catch {
            throw TopicAnalysisError.invalidModelManifest
        }

        let model = try makeModel(from: manifest)
        cachedModel = model
        return model
    }
}
