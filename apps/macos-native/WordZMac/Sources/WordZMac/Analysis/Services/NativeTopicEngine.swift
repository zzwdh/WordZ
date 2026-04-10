import Foundation

actor NativeTopicEngine: TopicAnalysisEngine {
    let modelManager: TopicModelManager
    let maxSliceCacheEntries: Int
    let maxEmbeddingCacheEntries: Int
    var sliceCache: [String: [TopicTextSlice]] = [:]
    var sliceCacheOrder: [String] = []
    var embeddingCache: [String: [[Double]]] = [:]
    var embeddingCacheOrder: [String] = []

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
}
