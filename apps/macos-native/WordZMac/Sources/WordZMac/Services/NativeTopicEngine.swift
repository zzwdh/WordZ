import CryptoKit
import Foundation
import NaturalLanguage

actor NativeTopicEngine: TopicAnalysisEngine {
    private struct TopicTextSlice {
        let id: String
        let paragraphIndex: Int
        let text: String
        let tokens: [String]
    }

    private struct ClusterState {
        var memberIndices: [Int]
        var centroid: [Double]
    }

    private let modelManager: TopicModelManager
    private let maxSliceCacheEntries: Int
    private let maxEmbeddingCacheEntries: Int
    private var sliceCache: [String: [TopicTextSlice]] = [:]
    private var sliceCacheOrder: [String] = []
    private var embeddingCache: [String: [[Double]]] = [:]
    private var embeddingCacheOrder: [String] = []

    init(
        modelManager: TopicModelManager = TopicModelManager(),
        maxSliceCacheEntries: Int = 8,
        maxEmbeddingCacheEntries: Int = 8
    ) {
        self.modelManager = modelManager
        self.maxSliceCacheEntries = max(1, maxSliceCacheEntries)
        self.maxEmbeddingCacheEntries = max(1, maxEmbeddingCacheEntries)
    }

    func analyze(
        text: String,
        options: TopicAnalysisOptions,
        progress: (@Sendable (TopicAnalysisProgress) -> Void)?
    ) async throws -> TopicAnalysisResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TopicAnalysisError.noEnglishParagraphs
        }

        progress?(TopicAnalysisProgress(stage: .preparing, detail: "Loading topic model", progress: 0.05))
        let model = try modelManager.loadModel()

        let contentHash = Self.stableHash(for: trimmed)
        progress?(TopicAnalysisProgress(stage: .segmenting, detail: "Segmenting paragraphs", progress: 0.15))
        let slices = try makeSlices(for: trimmed, cacheKey: contentHash)
        guard !slices.isEmpty else {
            throw TopicAnalysisError.noEnglishParagraphs
        }
        try Task.checkCancellation()

        progress?(TopicAnalysisProgress(stage: .embedding, detail: "Embedding paragraph vectors", progress: 0.4))
        let embeddings = makeEmbeddings(for: slices, cacheKey: contentHash, model: model)
        let reducedVectors = reduceVectors(embeddings)
        try Task.checkCancellation()

        progress?(TopicAnalysisProgress(stage: .clustering, detail: "Clustering topics", progress: 0.72))
        let clustered = clusterVectors(reducedVectors, minTopicSize: max(1, options.minTopicSize))
        guard !clustered.validClusters.isEmpty || !clustered.outlierIndices.isEmpty else {
            throw TopicAnalysisError.noTopicsGenerated
        }
        try Task.checkCancellation()

        progress?(TopicAnalysisProgress(stage: .summarizing, detail: "Building topic summaries", progress: 0.92))
        let result = buildResult(
            slices: slices,
            embeddings: reducedVectors,
            clustered: clustered,
            model: model
        )
        progress?(TopicAnalysisProgress(stage: .summarizing, detail: "Topics ready", progress: 1))
        return result
    }

    private func makeSlices(for text: String, cacheKey: String) throws -> [TopicTextSlice] {
        if let cached = sliceCache[cacheKey] {
            touchSliceCacheKey(cacheKey)
            return cached
        }

        let tokenizer = NLTokenizer(unit: .paragraph)
        tokenizer.string = text
        var slices: [TopicTextSlice] = []
        var paragraphIndex = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let paragraph = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            defer { paragraphIndex += 1 }
            guard !paragraph.isEmpty else { return true }

            let tokens = englishTokens(for: paragraph)
            guard tokens.count >= 3 else { return true }
            slices.append(
                TopicTextSlice(
                    id: "paragraph-\(paragraphIndex)",
                    paragraphIndex: paragraphIndex + 1,
                    text: paragraph,
                    tokens: tokens
                )
            )
            return true
        }

        guard !slices.isEmpty else {
            throw TopicAnalysisError.noEnglishParagraphs
        }

        sliceCache[cacheKey] = slices
        sliceCacheOrder.removeAll(where: { $0 == cacheKey })
        sliceCacheOrder.append(cacheKey)
        if sliceCacheOrder.count > maxSliceCacheEntries, let evicted = sliceCacheOrder.first {
            sliceCache.removeValue(forKey: evicted)
            sliceCacheOrder.removeFirst()
        }
        return slices
    }

    private func touchSliceCacheKey(_ cacheKey: String) {
        sliceCacheOrder.removeAll(where: { $0 == cacheKey })
        sliceCacheOrder.append(cacheKey)
    }

    private func makeEmbeddings(
        for slices: [TopicTextSlice],
        cacheKey: String,
        model: TopicEmbeddingModel
    ) -> [[Double]] {
        let key = [
            cacheKey,
            model.manifest.modelID,
            model.manifest.version,
            model.providerLabel,
            "\(model.manifest.dimensions)"
        ].joined(separator: "::")
        if let cached = embeddingCache[key] {
            touchEmbeddingCacheKey(key)
            return cached
        }

        let vectors = slices.map { slice in
            let embedded = model.vector(for: slice.text) ?? model.vector(for: slice.tokens.joined(separator: " "))
            return normalize(embedded ?? [])
        }

        embeddingCache[key] = vectors
        embeddingCacheOrder.removeAll(where: { $0 == key })
        embeddingCacheOrder.append(key)
        if embeddingCacheOrder.count > maxEmbeddingCacheEntries, let evicted = embeddingCacheOrder.first {
            embeddingCache.removeValue(forKey: evicted)
            embeddingCacheOrder.removeFirst()
        }
        return vectors
    }

    private func touchEmbeddingCacheKey(_ cacheKey: String) {
        embeddingCacheOrder.removeAll(where: { $0 == cacheKey })
        embeddingCacheOrder.append(cacheKey)
    }

    private func reduceVectors(_ vectors: [[Double]]) -> [[Double]] {
        guard let dimension = vectors.first?.count, dimension > 0 else { return vectors }
        let targetDimension = min(64, dimension)
        guard dimension > targetDimension else { return vectors }

        var means = Array(repeating: 0.0, count: dimension)
        for vector in vectors {
            for index in 0..<dimension {
                means[index] += vector[index]
            }
        }
        let count = Double(max(1, vectors.count))
        for index in 0..<dimension {
            means[index] /= count
        }

        return vectors.map { vector in
            let centered = zip(vector, means).map { $0 - $1 }
            return normalize(Array(centered.prefix(targetDimension)))
        }
    }

    private func clusterVectors(
        _ vectors: [[Double]],
        minTopicSize: Int
    ) -> (validClusters: [ClusterState], outlierIndices: [Int]) {
        guard !vectors.isEmpty else {
            return ([], [])
        }

        var clusters = vectors.enumerated().map { index, vector in
            ClusterState(memberIndices: [index], centroid: normalize(vector))
        }
        let mergeThreshold = similarityThreshold(for: vectors.count)

        while clusters.count > 1 {
            var bestPair: (Int, Int)?
            var bestSimilarity = -1.0

            for lhs in 0..<clusters.count {
                for rhs in (lhs + 1)..<clusters.count {
                    let similarity = cosineSimilarity(clusters[lhs].centroid, clusters[rhs].centroid)
                    if similarity > bestSimilarity {
                        bestSimilarity = similarity
                        bestPair = (lhs, rhs)
                    }
                }
            }

            guard let bestPair, bestSimilarity >= mergeThreshold else {
                break
            }

            let merged = mergeClusters(clusters[bestPair.0], clusters[bestPair.1], vectors: vectors)
            clusters[bestPair.0] = merged
            clusters.remove(at: bestPair.1)
        }

        let sortedClusters = clusters.sorted {
            if $0.memberIndices.count == $1.memberIndices.count {
                return $0.memberIndices.min() ?? 0 < $1.memberIndices.min() ?? 0
            }
            return $0.memberIndices.count > $1.memberIndices.count
        }

        var valid: [ClusterState] = []
        var outliers: [Int] = []
        for cluster in sortedClusters {
            if cluster.memberIndices.count >= minTopicSize {
                valid.append(cluster)
            } else {
                outliers.append(contentsOf: cluster.memberIndices)
            }
        }

        return (valid, outliers.sorted())
    }

    private func mergeClusters(
        _ lhs: ClusterState,
        _ rhs: ClusterState,
        vectors: [[Double]]
    ) -> ClusterState {
        let mergedIndices = (lhs.memberIndices + rhs.memberIndices).sorted()
        let dimension = lhs.centroid.count
        guard dimension > 0 else {
            return ClusterState(memberIndices: mergedIndices, centroid: [])
        }

        var centroid = Array(repeating: 0.0, count: dimension)
        for index in mergedIndices {
            let vector = vectors[index]
            for component in 0..<dimension {
                centroid[component] += vector[component]
            }
        }
        let count = Double(max(1, mergedIndices.count))
        centroid = centroid.map { $0 / count }
        return ClusterState(memberIndices: mergedIndices, centroid: normalize(centroid))
    }

    private func buildResult(
        slices: [TopicTextSlice],
        embeddings: [[Double]],
        clustered: (validClusters: [ClusterState], outlierIndices: [Int]),
        model: TopicEmbeddingModel
    ) -> TopicAnalysisResult {
        let clusterDocumentFrequency = buildDocumentFrequency(
            slices: slices,
            clusters: clustered.validClusters,
            outlierIndices: clustered.outlierIndices
        )

        var summaries: [TopicClusterSummary] = []
        var segments: [TopicSegmentRow] = []

        for (clusterIndex, cluster) in clustered.validClusters.enumerated() {
            let clusterID = "topic-\(clusterIndex + 1)"
            let clusterSlices = cluster.memberIndices.map { slices[$0] }
            let candidates = buildKeywordCandidates(
                slices: clusterSlices,
                clusterDocumentFrequency: clusterDocumentFrequency,
                clusterCount: max(1, clustered.validClusters.count + (clustered.outlierIndices.isEmpty ? 0 : 1))
            )
            let representativeIDs = representativeSegmentIDs(
                cluster: cluster,
                slices: slices,
                embeddings: embeddings
            )
            summaries.append(
                TopicClusterSummary(
                    id: clusterID,
                    index: clusterIndex + 1,
                    isOutlier: false,
                    size: cluster.memberIndices.count,
                    keywordCandidates: candidates,
                    representativeSegmentIDs: representativeIDs
                )
            )
            for memberIndex in cluster.memberIndices {
                segments.append(
                    TopicSegmentRow(
                        id: slices[memberIndex].id,
                        topicID: clusterID,
                        paragraphIndex: slices[memberIndex].paragraphIndex,
                        text: slices[memberIndex].text,
                        similarityScore: cosineSimilarity(embeddings[memberIndex], cluster.centroid),
                        isOutlier: false
                    )
                )
            }
        }

        if !clustered.outlierIndices.isEmpty {
            let outlierSlices = clustered.outlierIndices.map { slices[$0] }
            let candidates = buildKeywordCandidates(
                slices: outlierSlices,
                clusterDocumentFrequency: clusterDocumentFrequency,
                clusterCount: max(1, clustered.validClusters.count + 1)
            )
            let representativeIDs = clustered.outlierIndices.prefix(3).map { slices[$0].id }
            summaries.append(
                TopicClusterSummary(
                    id: TopicAnalysisResult.outlierTopicID,
                    index: 0,
                    isOutlier: true,
                    size: clustered.outlierIndices.count,
                    keywordCandidates: candidates,
                    representativeSegmentIDs: representativeIDs
                )
            )
            for memberIndex in clustered.outlierIndices {
                segments.append(
                    TopicSegmentRow(
                        id: slices[memberIndex].id,
                        topicID: TopicAnalysisResult.outlierTopicID,
                        paragraphIndex: slices[memberIndex].paragraphIndex,
                        text: slices[memberIndex].text,
                        similarityScore: 0,
                        isOutlier: true
                    )
                )
            }
        }

        let sortedSegments = segments.sorted { lhs, rhs in
            if lhs.topicID == rhs.topicID {
                return lhs.paragraphIndex < rhs.paragraphIndex
            }
            return lhs.topicID < rhs.topicID
        }

        return TopicAnalysisResult(
            modelVersion: "\(model.manifest.modelID)-\(model.manifest.version)",
            modelProvider: model.providerLabel,
            usesFallbackProvider: model.providerLabel == "hashed-fallback",
            clusters: summaries,
            segments: sortedSegments,
            totalSegments: slices.count,
            clusteredSegments: clustered.validClusters.reduce(0) { $0 + $1.memberIndices.count },
            outlierCount: clustered.outlierIndices.count,
            warnings: []
        )
    }

    private func buildDocumentFrequency(
        slices: [TopicTextSlice],
        clusters: [ClusterState],
        outlierIndices: [Int]
    ) -> [String: Int] {
        var frequency: [String: Int] = [:]
        for cluster in clusters {
            let uniqueTerms = Set(cluster.memberIndices.flatMap { slices[$0].tokens })
            for term in uniqueTerms {
                frequency[term, default: 0] += 1
            }
        }
        if !outlierIndices.isEmpty {
            let uniqueTerms = Set(outlierIndices.flatMap { slices[$0].tokens })
            for term in uniqueTerms {
                frequency[term, default: 0] += 1
            }
        }
        return frequency
    }

    private func buildKeywordCandidates(
        slices: [TopicTextSlice],
        clusterDocumentFrequency: [String: Int],
        clusterCount: Int
    ) -> [TopicKeywordCandidate] {
        var counts: [String: Int] = [:]
        var total = 0
        for slice in slices {
            for token in slice.tokens {
                counts[token, default: 0] += 1
                total += 1
            }
        }

        guard total > 0 else { return [] }

        return counts.map { term, count in
            let tf = Double(count) / Double(total)
            let df = Double(max(1, clusterDocumentFrequency[term] ?? 1))
            let idf = log(1 + (Double(clusterCount) / df))
            return TopicKeywordCandidate(term: term, score: tf * idf)
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.term.localizedCaseInsensitiveCompare(rhs.term) == .orderedAscending
            }
            return lhs.score > rhs.score
        }
        .prefix(12)
        .map { $0 }
    }

    private func representativeSegmentIDs(
        cluster: ClusterState,
        slices: [TopicTextSlice],
        embeddings: [[Double]]
    ) -> [String] {
        cluster.memberIndices
            .sorted { lhs, rhs in
                let lhsScore = cosineSimilarity(embeddings[lhs], cluster.centroid)
                let rhsScore = cosineSimilarity(embeddings[rhs], cluster.centroid)
                if lhsScore == rhsScore {
                    return slices[lhs].paragraphIndex < slices[rhs].paragraphIndex
                }
                return lhsScore > rhsScore
            }
            .prefix(3)
            .map { slices[$0].id }
    }

    private func similarityThreshold(for segmentCount: Int) -> Double {
        switch segmentCount {
        case ..<10:
            return 0.82
        case ..<30:
            return 0.78
        default:
            return 0.74
        }
    }

    private func cosineSimilarity(_ lhs: [Double], _ rhs: [Double]) -> Double {
        guard lhs.count == rhs.count, !lhs.isEmpty else { return 0 }
        var dot = 0.0
        var lhsNorm = 0.0
        var rhsNorm = 0.0
        for index in lhs.indices {
            dot += lhs[index] * rhs[index]
            lhsNorm += lhs[index] * lhs[index]
            rhsNorm += rhs[index] * rhs[index]
        }
        guard lhsNorm > 0, rhsNorm > 0 else { return 0 }
        return dot / (sqrt(lhsNorm) * sqrt(rhsNorm))
    }

    private func normalize(_ vector: [Double]) -> [Double] {
        guard !vector.isEmpty else { return [] }
        let magnitude = sqrt(vector.reduce(0) { $0 + ($1 * $1) })
        guard magnitude > 0 else { return vector }
        return vector.map { $0 / magnitude }
    }

    private func englishTokens(for text: String) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = text
        tagger.setLanguage(.english, range: text.startIndex..<text.endIndex)
        var tokens: [String] = []
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .omitOther, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lemma, options: options) { tag, tokenRange in
            let raw = String(text[tokenRange]).lowercased()
            let lemma = (tag?.rawValue ?? raw).lowercased()
            let normalized = lemma.trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalized.range(of: "[a-z]", options: .regularExpression) != nil else {
                return true
            }
            tokens.append(normalized)
            return true
        }
        return tokens
    }

    private static func stableHash(for value: String) -> String {
        let digest = SHA256.hash(data: Data(value.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
