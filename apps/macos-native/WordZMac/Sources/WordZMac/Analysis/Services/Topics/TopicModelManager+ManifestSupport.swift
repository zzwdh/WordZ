import NaturalLanguage
import Foundation

struct TopicLocalEmbeddingResource: Codable {
    let revision: String
    let dimensions: Int
    let seed: String
    let hashesPerFeature: Int
    let unigramWeight: Double
    let keywordWeight: Double
    let bigramWeight: Double
    let oovWeight: Double?
    let subwordMinLength: Int?
    let subwordMaxLength: Int?
    let tokenEmbeddings: [String: [String: Double]]?
    let bigramEmbeddings: [String: [String: Double]]?
}

struct TopicLocalEmbeddingTable {
    let revision: String
    let dimensions: Int
    let seed: String
    let hashesPerFeature: Int
    let unigramWeight: Double
    let keywordWeight: Double
    let bigramWeight: Double
    let oovWeight: Double
    let subwordMinLength: Int
    let subwordMaxLength: Int
    let tokenEmbeddings: [String: [Double]]
    let bigramEmbeddings: [String: [Double]]

    var hasExplicitEmbeddings: Bool {
        !tokenEmbeddings.isEmpty || !bigramEmbeddings.isEmpty
    }
}

extension TopicModelManager {
    func makeModel(from manifest: TopicModelManifest) throws -> TopicEmbeddingModel {
        let providers = manifest.providerChain
        guard !providers.isEmpty else {
            throw TopicAnalysisError.invalidModelManifest
        }

        for (index, provider) in providers.enumerated() {
            switch provider.type {
            case "bundled-local-embedding", "bundled-lexical-embedding":
                if let model = try makeBundledLocalModel(
                    manifest: manifest,
                    provider: provider,
                    isPrimaryProvider: index == 0
                ) {
                    return model
                }
            case "system-sentence-embedding":
                if let model = makeSystemEmbeddingModel(
                    manifest: manifest,
                    provider: provider,
                    isPrimaryProvider: index == 0
                ) {
                    return model
                }
            case "hashed-fallback":
                return makeHashedFallbackModel(
                    manifest: manifest,
                    provider: provider,
                    isPrimaryProvider: index == 0
                )
            default:
                continue
            }
        }

        throw TopicAnalysisError.embeddingUnavailable
    }

    func makeBundledLocalModel(
        manifest: TopicModelManifest,
        provider: TopicModelProviderManifest,
        isPrimaryProvider: Bool
    ) throws -> TopicEmbeddingModel? {
        let resourceName = manifest.localEmbeddingResource ?? "TopicLocalEmbeddingModel"
        let resourceData: Data
        do {
            resourceData = try localEmbeddingProvider(resourceName)
        } catch {
            return nil
        }

        let resource: TopicLocalEmbeddingResource
        do {
            resource = try JSONDecoder().decode(TopicLocalEmbeddingResource.self, from: resourceData)
        } catch {
            return nil
        }

        let expectedDimensions = max(32, provider.dimensions ?? resource.dimensions)
        let table = Self.compileLocalEmbeddingTable(
            from: resource,
            dimensions: expectedDimensions
        )
        let revision = provider.revision ?? table.revision

        return TopicEmbeddingModel(
            manifest: manifest,
            providerLabel: provider.id,
            providerRevision: providerRevision(
                manifest: manifest,
                providerID: provider.id,
                revision: revision
            ),
            isPrimaryProvider: isPrimaryProvider,
            expectedDimensions: expectedDimensions
        ) { input in
            Self.localEmbeddingVector(for: input, table: table)
        }
    }

    func makeSystemEmbeddingModel(
        manifest: TopicModelManifest,
        provider: TopicModelProviderManifest,
        isPrimaryProvider: Bool
    ) -> TopicEmbeddingModel? {
        let vectorProvider: (String) -> [Double]?
        if let systemSentenceVectorProvider {
            vectorProvider = systemSentenceVectorProvider
        } else {
            guard let embedding = systemEmbeddingProvider() else {
                return nil
            }
            vectorProvider = { text in
                embedding.vector(for: text)
            }
        }

        let sampleDimension = vectorProvider("topic modeling")?.count
            ?? provider.dimensions
            ?? manifest.dimensions

        return TopicEmbeddingModel(
            manifest: manifest,
            providerLabel: provider.id,
            providerRevision: providerRevision(
                manifest: manifest,
                providerID: provider.id,
                revision: provider.revision
            ),
            isPrimaryProvider: isPrimaryProvider,
            expectedDimensions: sampleDimension
        ) { input in
            if let vector = vectorProvider(input.text) {
                return vector
            }
            if !input.keywordTerms.isEmpty,
               let vector = vectorProvider(input.keywordTerms.joined(separator: " ")) {
                return vector
            }
            return Array(repeating: 0.0, count: sampleDimension)
        }
    }

    func makeHashedFallbackModel(
        manifest: TopicModelManifest,
        provider: TopicModelProviderManifest,
        isPrimaryProvider: Bool
    ) -> TopicEmbeddingModel {
        let dimensions = max(32, provider.dimensions ?? manifest.dimensions)
        return TopicEmbeddingModel(
            manifest: manifest,
            providerLabel: provider.id,
            providerRevision: providerRevision(
                manifest: manifest,
                providerID: provider.id,
                revision: provider.revision
            ),
            isPrimaryProvider: isPrimaryProvider,
            expectedDimensions: dimensions
        ) { input in
            let seedTerms = input.keywordTerms.isEmpty ? input.tokens : input.keywordTerms
            return Self.hashedFallbackVector(
                forTerms: seedTerms + input.keywordBigrams,
                dimensions: dimensions
            )
        }
    }

    func providerRevision(
        manifest: TopicModelManifest,
        providerID: String,
        revision: String?
    ) -> String {
        [
            manifest.modelID,
            manifest.version,
            providerID,
            revision ?? manifest.revision ?? "default"
        ]
        .joined(separator: "::")
    }
}
