import Foundation

struct TopicSliceLexicalProfile {
    let tokenCounts: [String: Int]
    let keywordSet: Set<String>
    let bigramSet: Set<String>
    let semanticKeywordVector: [Double]?
}

struct TopicClusteringLexicalContext {
    let profiles: [TopicSliceLexicalProfile]
    let keywordDocumentFrequency: [String: Int]
    let bigramDocumentFrequency: [String: Int]
    let sliceCount: Int
}

extension NativeTopicEngine {

    func shouldUseExactLexicalRefinement(
        vectors: [[Double]],
        lexicalContext: TopicClusteringLexicalContext?
    ) -> Bool {
        guard let lexicalContext else { return false }
        return lexicalContext.sliceCount == vectors.count
            && vectors.count <= Self.exactLexicalRefinementSliceLimit
    }

    func makeLexicalContext(
        for slices: [TopicTextSlice],
        model: TopicEmbeddingModel?
    ) -> TopicClusteringLexicalContext? {
        guard !slices.isEmpty else { return nil }

        let profiles = slices.map { slice in
            TopicSliceLexicalProfile(
                tokenCounts: Dictionary(
                    grouping: slice.tokens.map(canonicalKeyword),
                    by: { $0 }
                )
                .mapValues(\.count),
                keywordSet: Set(candidateTerms(for: slice).map(canonicalKeyword)),
                bigramSet: Set(slice.keywordBigrams.map(canonicalKeyword)),
                semanticKeywordVector: makeSemanticKeywordVector(
                    for: slice,
                    model: model
                )
            )
        }

        var keywordDocumentFrequency: [String: Int] = [:]
        var bigramDocumentFrequency: [String: Int] = [:]
        for profile in profiles {
            for term in profile.keywordSet {
                keywordDocumentFrequency[term, default: 0] += 1
            }
            for bigram in profile.bigramSet {
                bigramDocumentFrequency[bigram, default: 0] += 1
            }
        }

        return TopicClusteringLexicalContext(
            profiles: profiles,
            keywordDocumentFrequency: keywordDocumentFrequency,
            bigramDocumentFrequency: bigramDocumentFrequency,
            sliceCount: slices.count
        )
    }

    func exactHybridSimilarity(
        lhsIndex: Int,
        rhsIndex: Int,
        vectors: [[Double]],
        lexicalContext: TopicClusteringLexicalContext
    ) -> Double {
        let embeddingSimilarity = max(0, cosineSimilarity(vectors[lhsIndex], vectors[rhsIndex]))
        let lhsProfile = lexicalContext.profiles[lhsIndex]
        let rhsProfile = lexicalContext.profiles[rhsIndex]
        let keywordOverlap = weightedSetSimilarity(
            lhsProfile.keywordSet,
            rhsProfile.keywordSet,
            documentFrequency: lexicalContext.keywordDocumentFrequency,
            totalDocuments: lexicalContext.sliceCount
        )
        let bigramOverlap = weightedSetSimilarity(
            lhsProfile.bigramSet,
            rhsProfile.bigramSet,
            documentFrequency: lexicalContext.bigramDocumentFrequency,
            totalDocuments: lexicalContext.sliceCount
        )
        let semanticKeywordSimilarity = semanticKeywordSimilarity(
            lhsProfile.semanticKeywordVector,
            rhsProfile.semanticKeywordVector
        )
        let tokenOverlap = weightedTokenCosineSimilarity(
            lhsProfile.tokenCounts,
            rhsProfile.tokenCounts,
            keywordDocumentFrequency: lexicalContext.keywordDocumentFrequency,
            totalDocuments: lexicalContext.sliceCount
        )

        let semanticSupport = max(
            semanticKeywordSimilarity,
            max(keywordOverlap, max(tokenOverlap * 0.85, bigramOverlap))
        )
        let embeddingCarry = embeddingSimilarity * max(0.18, semanticSupport)
        let blended = (semanticKeywordSimilarity * 0.42)
            + (embeddingCarry * 0.28)
            + (keywordOverlap * 0.18)
            + (tokenOverlap * 0.08)
            + (bigramOverlap * 0.04)

        return max(0, min(1, blended))
    }

    func weightedSetSimilarity(
        _ lhs: Set<String>,
        _ rhs: Set<String>,
        documentFrequency: [String: Int],
        totalDocuments: Int
    ) -> Double {
        let union = lhs.union(rhs)
        guard !union.isEmpty else { return 0 }

        let weightedIntersection = lhs.intersection(rhs).reduce(0.0) { partialResult, term in
            partialResult + lexicalIDF(
                for: term,
                documentFrequency: documentFrequency,
                totalDocuments: totalDocuments
            )
        }
        let weightedUnion = union.reduce(0.0) { partialResult, term in
            partialResult + lexicalIDF(
                for: term,
                documentFrequency: documentFrequency,
                totalDocuments: totalDocuments
            )
        }
        guard weightedUnion > 0 else { return 0 }
        return weightedIntersection / weightedUnion
    }

    func weightedTokenCosineSimilarity(
        _ lhsCounts: [String: Int],
        _ rhsCounts: [String: Int],
        keywordDocumentFrequency: [String: Int],
        totalDocuments: Int
    ) -> Double {
        guard !lhsCounts.isEmpty, !rhsCounts.isEmpty else { return 0 }

        let sharedTerms = Set(lhsCounts.keys).intersection(rhsCounts.keys)
        let numerator = sharedTerms.reduce(0.0) { partialResult, term in
            let weight = lexicalIDF(
                for: term,
                documentFrequency: keywordDocumentFrequency,
                totalDocuments: totalDocuments
            )
            return partialResult + Double((lhsCounts[term] ?? 0) * (rhsCounts[term] ?? 0)) * weight
        }

        let lhsMagnitude = sqrt(lhsCounts.reduce(0.0) { partialResult, entry in
            let weight = lexicalIDF(
                for: entry.key,
                documentFrequency: keywordDocumentFrequency,
                totalDocuments: totalDocuments
            )
            return partialResult + Double(entry.value * entry.value) * weight
        })
        let rhsMagnitude = sqrt(rhsCounts.reduce(0.0) { partialResult, entry in
            let weight = lexicalIDF(
                for: entry.key,
                documentFrequency: keywordDocumentFrequency,
                totalDocuments: totalDocuments
            )
            return partialResult + Double(entry.value * entry.value) * weight
        })

        guard lhsMagnitude > 0, rhsMagnitude > 0 else { return 0 }
        return numerator / (lhsMagnitude * rhsMagnitude)
    }

    func lexicalIDF(
        for term: String,
        documentFrequency: [String: Int],
        totalDocuments: Int
    ) -> Double {
        let df = Double(max(1, documentFrequency[term] ?? 1))
        return log(1 + (Double(max(1, totalDocuments)) / df))
    }

    func makeSemanticKeywordVector(
        for slice: TopicTextSlice,
        model: TopicEmbeddingModel?
    ) -> [Double]? {
        guard let model else { return nil }
        let terms = Array(
            Set((slice.keywordTerms.isEmpty ? slice.tokens : slice.keywordTerms).map(canonicalKeyword))
        )
        .sorted()
        .prefix(8)

        var vectors: [[Double]] = []
        vectors.reserveCapacity(terms.count)
        for term in terms {
            guard let vector = model.vector(
                for: TopicEmbeddingInput(
                    text: term,
                    tokens: [term],
                    keywordTerms: [term],
                    keywordBigrams: []
                )
            ) else {
                continue
            }
            vectors.append(normalize(vector))
        }

        guard let first = vectors.first else { return nil }
        var aggregate = Array(repeating: 0.0, count: first.count)
        for vector in vectors {
            for index in aggregate.indices where vector.indices.contains(index) {
                aggregate[index] += vector[index]
            }
        }
        let count = Double(max(1, vectors.count))
        return normalize(aggregate.map { $0 / count })
    }

    func semanticKeywordSimilarity(
        _ lhs: [Double]?,
        _ rhs: [Double]?
    ) -> Double {
        guard let lhs, let rhs else { return 0 }
        return max(0, cosineSimilarity(lhs, rhs))
    }

    func lexicalClusterContrastScore(
        _ clusters: [ClusterState],
        lexicalContext: TopicClusteringLexicalContext?
    ) -> Double {
        guard let lexicalContext, clusters.count > 1 else { return 0 }

        let allIndices = Set(0..<lexicalContext.sliceCount)
        let clusterScores = clusters.map { cluster -> Double in
            let clusterIndexSet = Set(cluster.memberIndices)
            let restIndices = allIndices.subtracting(clusterIndexSet)

            let insidePresence = keywordPresence(
                for: cluster.memberIndices,
                lexicalContext: lexicalContext
            )
            let outsidePresence = keywordPresence(
                for: Array(restIndices),
                lexicalContext: lexicalContext
            )

            let insideCount = Double(max(1, cluster.memberIndices.count))
            let outsideCount = Double(max(1, restIndices.count))
            let distinctiveness = insidePresence.compactMap { term, presenceCount -> Double? in
                let insideShare = Double(presenceCount) / insideCount
                let outsideShare = Double(outsidePresence[term] ?? 0) / outsideCount
                let contrast = insideShare - outsideShare
                let globalShare = Double(lexicalContext.keywordDocumentFrequency[term] ?? 0)
                    / Double(max(1, lexicalContext.sliceCount))
                guard insideShare >= 0.34, contrast > 0.12, globalShare < 0.8 else {
                    return nil
                }
                let rarity = max(0.18, 1 - globalShare)
                return contrast * rarity
            }
            .sorted(by: >)

            let topSignals = distinctiveness.prefix(3)
            guard !topSignals.isEmpty else { return 0 }
            return topSignals.reduce(0, +) / Double(topSignals.count)
        }

        guard !clusterScores.isEmpty else { return 0 }
        return clusterScores.reduce(0, +) / Double(clusterScores.count)
    }

    func lexicalWithinClusterCohesion(
        _ clusters: [ClusterState],
        lexicalContext: TopicClusteringLexicalContext?
    ) -> Double {
        guard let lexicalContext else { return 0 }

        let clusterScores = clusters.map { cluster -> Double in
            guard cluster.memberIndices.count > 1 else { return 1 }

            var total = 0.0
            var pairs = 0
            for lhsOffset in 0..<cluster.memberIndices.count {
                for rhsOffset in (lhsOffset + 1)..<cluster.memberIndices.count {
                    let lhsProfile = lexicalContext.profiles[cluster.memberIndices[lhsOffset]]
                    let rhsProfile = lexicalContext.profiles[cluster.memberIndices[rhsOffset]]
                    let keywordOverlap = weightedSetSimilarity(
                        lhsProfile.keywordSet,
                        rhsProfile.keywordSet,
                        documentFrequency: lexicalContext.keywordDocumentFrequency,
                        totalDocuments: lexicalContext.sliceCount
                    )
                    let bigramOverlap = weightedSetSimilarity(
                        lhsProfile.bigramSet,
                        rhsProfile.bigramSet,
                        documentFrequency: lexicalContext.bigramDocumentFrequency,
                        totalDocuments: lexicalContext.sliceCount
                    )
                    let tokenOverlap = weightedTokenCosineSimilarity(
                        lhsProfile.tokenCounts,
                        rhsProfile.tokenCounts,
                        keywordDocumentFrequency: lexicalContext.keywordDocumentFrequency,
                        totalDocuments: lexicalContext.sliceCount
                    )
                    let semanticSimilarity = semanticKeywordSimilarity(
                        lhsProfile.semanticKeywordVector,
                        rhsProfile.semanticKeywordVector
                    )
                    total += (semanticSimilarity * 0.55)
                        + (keywordOverlap * 0.22)
                        + (tokenOverlap * 0.18)
                        + (bigramOverlap * 0.05)
                    pairs += 1
                }
            }
            return pairs == 0 ? 1 : total / Double(pairs)
        }

        guard !clusterScores.isEmpty else { return 0 }
        return clusterScores.reduce(0, +) / Double(clusterScores.count)
    }

    func keywordPresence(
        for memberIndices: [Int],
        lexicalContext: TopicClusteringLexicalContext
    ) -> [String: Int] {
        var presence: [String: Int] = [:]
        for memberIndex in memberIndices where lexicalContext.profiles.indices.contains(memberIndex) {
            for term in lexicalContext.profiles[memberIndex].keywordSet {
                presence[term, default: 0] += 1
            }
        }
        return presence
    }

}
