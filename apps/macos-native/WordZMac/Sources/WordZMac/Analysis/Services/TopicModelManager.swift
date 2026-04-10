import CryptoKit
import Foundation
import NaturalLanguage

protocol TopicAnalysisEngine: AnyObject {
    func analyze(
        text: String,
        options: TopicAnalysisOptions,
        progress: (@Sendable (TopicAnalysisProgress) -> Void)?
    ) async throws -> TopicAnalysisResult
}

final class TopicEmbeddingModel {
    let manifest: TopicModelManifest
    let providerLabel: String

    private let vectorProvider: (String) -> [Double]?

    init(
        manifest: TopicModelManifest,
        providerLabel: String,
        vectorProvider: @escaping (String) -> [Double]?
    ) {
        self.manifest = manifest
        self.providerLabel = providerLabel
        self.vectorProvider = vectorProvider
    }

    func vector(for text: String) -> [Double]? {
        vectorProvider(text)
    }
}

final class TopicModelManager {
    private let bundle: Bundle
    private let manifestProvider: () throws -> Data
    private let systemEmbeddingProvider: () -> NLEmbedding?
    private var cachedModel: TopicEmbeddingModel?

    init(
        bundle: Bundle = .module,
        manifestProvider: (() throws -> Data)? = nil,
        systemEmbeddingProvider: (() -> NLEmbedding?)? = nil
    ) {
        self.bundle = bundle
        self.manifestProvider = manifestProvider ?? {
            guard let url = bundle.url(forResource: "TopicModelManifest", withExtension: "json") else {
                throw TopicAnalysisError.missingModelManifest
            }
            return try Data(contentsOf: url)
        }
        self.systemEmbeddingProvider = systemEmbeddingProvider ?? {
            NLEmbedding.sentenceEmbedding(for: .english)
        }
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

        let model: TopicEmbeddingModel
        if let embedding = systemEmbeddingProvider() {
            model = TopicEmbeddingModel(
                manifest: manifest,
                providerLabel: manifest.provider
            ) { text in
                embedding.vector(for: text)
            }
        } else {
            model = TopicEmbeddingModel(
                manifest: manifest,
                providerLabel: "hashed-fallback"
            ) { text in
                TopicModelManager.hashedFallbackVector(for: text, dimensions: manifest.dimensions)
            }
        }

        cachedModel = model
        return model
    }

    static func hashedFallbackVector(for text: String, dimensions: Int) -> [Double]? {
        let terms = TopicFilterSupport.tokenize(text)
        guard !terms.isEmpty else { return nil }

        var vector = Array(repeating: 0.0, count: max(32, dimensions))
        for term in terms {
            let hash = stableTermHash(for: term)
            let index = Int(hash.bucket % UInt64(vector.count))
            let sign = hash.isPositive ? 1.0 : -1.0
            vector[index] += sign
        }
        return vector
    }

    private static func stableTermHash(for term: String) -> (bucket: UInt64, isPositive: Bool) {
        let digest = SHA256.hash(data: Data(term.utf8))
        let bytes = Array(digest)

        var bucket: UInt64 = 0
        for byte in bytes.prefix(4) {
            bucket = (bucket << 8) | UInt64(byte)
        }

        let isPositive = bytes.dropFirst(4).first.map { $0.isMultiple(of: 2) } ?? true
        return (bucket, isPositive)
    }
}
