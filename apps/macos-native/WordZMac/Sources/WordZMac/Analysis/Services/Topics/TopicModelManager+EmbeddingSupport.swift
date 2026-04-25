import CryptoKit
import Foundation

extension TopicModelManager {
    static func compileLocalEmbeddingTable(
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

    static func compileSparseEmbeddings(
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

    static func denseVector(
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

    static func localEmbeddingVector(
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

    static func lexicalEmbeddingFeatures(
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

    static func counted(_ terms: [String]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for term in terms {
            counts[term, default: 0] += 1
        }
        return counts
    }

    static func addDenseVector(
        _ denseVector: [Double],
        into vector: inout [Double],
        weight: Double
    ) {
        guard weight != 0 else { return }
        for index in vector.indices where denseVector.indices.contains(index) {
            vector[index] += denseVector[index] * weight
        }
    }

    static func addProjectedFeature(
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

    static func addProjectedSubwords(
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

    static func characterNGrams(
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

    static func projectFeatures(
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

    static func stableTermHash(for term: String) -> (bucket: UInt64, isPositive: Bool) {
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
