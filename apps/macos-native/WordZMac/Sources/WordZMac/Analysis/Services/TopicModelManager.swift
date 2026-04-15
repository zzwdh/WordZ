import CryptoKit
import Foundation
import NaturalLanguage
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

private struct TopicLocalEmbeddingResource: Codable {
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

private struct TopicLocalEmbeddingTable {
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

final class TopicModelManager {
    private let bundle: Bundle
    private let manifestProvider: () throws -> Data
    private let localEmbeddingProvider: (String) throws -> Data
    private let systemEmbeddingProvider: () -> NLEmbedding?
    private let systemSentenceVectorProvider: ((String) -> [Double]?)?
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

    private func makeModel(from manifest: TopicModelManifest) throws -> TopicEmbeddingModel {
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

    private func makeBundledLocalModel(
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

    private func makeSystemEmbeddingModel(
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

    private func makeHashedFallbackModel(
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

    private func providerRevision(
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

    private static func compileLocalEmbeddingTable(
        from resource: TopicLocalEmbeddingResource,
        dimensions: Int
    ) -> TopicLocalEmbeddingTable {
        TopicLocalEmbeddingTable(
            revision: resource.revision,
            dimensions: dimensions,
            seed: resource.seed,
            hashesPerFeature: max(1, resource.hashesPerFeature),
            unigramWeight: resource.unigramWeight,
            keywordWeight: resource.keywordWeight,
            bigramWeight: resource.bigramWeight,
            oovWeight: resource.oovWeight ?? 0.42,
            subwordMinLength: max(2, resource.subwordMinLength ?? 3),
            subwordMaxLength: max(resource.subwordMinLength ?? 3, resource.subwordMaxLength ?? 5),
            tokenEmbeddings: compileSparseEmbeddings(
                resource.tokenEmbeddings ?? [:],
                dimensions: dimensions
            ),
            bigramEmbeddings: compileSparseEmbeddings(
                resource.bigramEmbeddings ?? [:],
                dimensions: dimensions
            )
        )
    }

    private static func compileSparseEmbeddings(
        _ sparseEmbeddings: [String: [String: Double]],
        dimensions: Int
    ) -> [String: [Double]] {
        Dictionary(
            uniqueKeysWithValues: sparseEmbeddings.map { term, sparseVector in
                (
                    term,
                    denseVector(from: sparseVector, dimensions: dimensions)
                )
            }
        )
    }

    private static func denseVector(
        from sparseVector: [String: Double],
        dimensions: Int
    ) -> [Double] {
        var dense = Array(repeating: 0.0, count: max(32, dimensions))
        for (indexString, value) in sparseVector {
            guard let index = Int(indexString), dense.indices.contains(index) else {
                continue
            }
            dense[index] = value
        }
        return dense
    }

    private static func localEmbeddingVector(
        for input: TopicEmbeddingInput,
        table: TopicLocalEmbeddingTable
    ) -> [Double]? {
        if !table.hasExplicitEmbeddings {
            let features = lexicalEmbeddingFeatures(
                for: input,
                unigramWeight: table.unigramWeight,
                keywordWeight: table.keywordWeight,
                bigramWeight: table.bigramWeight
            )
            return projectFeatures(
                features,
                dimensions: table.dimensions,
                seed: table.seed,
                hashesPerFeature: table.hashesPerFeature
            )
        }

        var vector = Array(repeating: 0.0, count: max(32, table.dimensions))
        var hasSignal = false
        let keywordSet = Set(input.keywordTerms)

        for (term, count) in counted(input.tokens) {
            let baseWeight = keywordSet.contains(term) ? table.keywordWeight : table.unigramWeight
            let resolvedWeight = baseWeight * log1p(Double(count))
            if let dense = table.tokenEmbeddings[term] {
                addDenseVector(dense, into: &vector, weight: resolvedWeight)
                addProjectedSubwords(
                    for: term,
                    into: &vector,
                    weight: resolvedWeight * 0.08,
                    seed: table.seed,
                    hashesPerFeature: table.hashesPerFeature,
                    minLength: table.subwordMinLength,
                    maxLength: table.subwordMaxLength
                )
            } else {
                addProjectedFeature(
                    "u:\(term)",
                    into: &vector,
                    weight: resolvedWeight * table.oovWeight,
                    seed: table.seed,
                    hashesPerFeature: table.hashesPerFeature
                )
                addProjectedSubwords(
                    for: term,
                    into: &vector,
                    weight: resolvedWeight * table.oovWeight * 0.55,
                    seed: table.seed,
                    hashesPerFeature: table.hashesPerFeature,
                    minLength: table.subwordMinLength,
                    maxLength: table.subwordMaxLength
                )
            }
            hasSignal = true
        }

        for (bigram, count) in counted(input.keywordBigrams) {
            let resolvedWeight = table.bigramWeight * log1p(Double(count))
            if let dense = table.bigramEmbeddings[bigram] {
                addDenseVector(dense, into: &vector, weight: resolvedWeight)
            } else {
                addProjectedFeature(
                    "b:\(bigram)",
                    into: &vector,
                    weight: resolvedWeight * max(0.5, table.oovWeight),
                    seed: table.seed,
                    hashesPerFeature: table.hashesPerFeature
                )
            }
            hasSignal = true
        }

        return hasSignal ? vector : nil
    }

    private static func lexicalEmbeddingFeatures(
        for input: TopicEmbeddingInput,
        unigramWeight: Double,
        keywordWeight: Double,
        bigramWeight: Double
    ) -> [(String, Double)] {
        var weights: [String: Double] = [:]
        let keywordSet = Set(input.keywordTerms)

        for (term, count) in counted(input.tokens) {
            let baseWeight = keywordSet.contains(term) ? keywordWeight : unigramWeight
            weights["u:\(term)", default: 0] += baseWeight * log1p(Double(count))
        }
        for (bigram, count) in counted(input.keywordBigrams) {
            weights["b:\(bigram)", default: 0] += bigramWeight * log1p(Double(count))
        }

        return weights
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key < rhs.key
                }
                return lhs.value > rhs.value
            }
            .map { ($0.key, $0.value) }
    }

    private static func counted(_ terms: [String]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for term in terms {
            counts[term, default: 0] += 1
        }
        return counts
    }

    private static func addDenseVector(
        _ denseVector: [Double],
        into vector: inout [Double],
        weight: Double
    ) {
        guard weight != 0 else { return }
        for index in vector.indices where denseVector.indices.contains(index) {
            vector[index] += denseVector[index] * weight
        }
    }

    private static func addProjectedFeature(
        _ feature: String,
        into vector: inout [Double],
        weight: Double,
        seed: String,
        hashesPerFeature: Int
    ) {
        guard weight != 0 else { return }
        for projectionIndex in 0..<max(1, hashesPerFeature) {
            let hash = stableTermHash(for: "\(seed)|\(projectionIndex)|\(feature)")
            let bucket = Int(hash.bucket % UInt64(vector.count))
            vector[bucket] += hash.isPositive ? weight : -weight
        }
    }

    private static func addProjectedSubwords(
        for term: String,
        into vector: inout [Double],
        weight: Double,
        seed: String,
        hashesPerFeature: Int,
        minLength: Int,
        maxLength: Int
    ) {
        guard weight != 0 else { return }
        for subword in characterNGrams(for: term, minLength: minLength, maxLength: maxLength) {
            addProjectedFeature(
                "g:\(subword)",
                into: &vector,
                weight: weight,
                seed: seed,
                hashesPerFeature: hashesPerFeature
            )
        }
    }

    private static func characterNGrams(
        for term: String,
        minLength: Int,
        maxLength: Int
    ) -> [String] {
        let padded = "_\(term)_"
        let characters = Array(padded)
        guard !characters.isEmpty else { return [] }

        let lowerBound = max(2, minLength)
        let upperBound = min(maxLength, characters.count)
        guard lowerBound <= upperBound else {
            return [padded]
        }

        var grams: [String] = []
        for length in lowerBound...upperBound {
            guard characters.count >= length else { continue }
            for start in 0...(characters.count - length) {
                grams.append(String(characters[start..<(start + length)]))
            }
        }
        return grams
    }

    private static func projectFeatures(
        _ features: [(String, Double)],
        dimensions: Int,
        seed: String,
        hashesPerFeature: Int
    ) -> [Double]? {
        guard !features.isEmpty else { return nil }

        var vector = Array(repeating: 0.0, count: max(32, dimensions))
        for (feature, weight) in features {
            addProjectedFeature(
                feature,
                into: &vector,
                weight: weight,
                seed: seed,
                hashesPerFeature: hashesPerFeature
            )
        }
        return vector
    }

    static func hashedFallbackVector(for text: String, dimensions: Int) -> [Double]? {
        hashedFallbackVector(
            forTerms: TopicFilterSupport.tokenize(text),
            dimensions: dimensions
        )
    }

    static func hashedFallbackVector(forTerms terms: [String], dimensions: Int) -> [Double]? {
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
