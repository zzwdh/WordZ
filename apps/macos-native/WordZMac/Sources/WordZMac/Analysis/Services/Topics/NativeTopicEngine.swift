import Foundation

private let topicLogger = WordZTelemetry.logger(category: "Topics")

actor NativeTopicEngine: TopicAnalysisEngine {
    let modelManager: TopicModelManager
    let maxSliceCacheEntries: Int
    let maxEmbeddingCacheEntries: Int
    let maxReductionCacheEntries: Int
    var sliceCache: [String: [TopicTextSlice]] = [:]
    var sliceCacheOrder: [String] = []
    var embeddingCache: [String: [Double]] = [:]
    var embeddingCacheOrder: [String] = []
    var reductionCache: [String: TopicEmbeddingReductionResult] = [:]
    var reductionCacheOrder: [String] = []

    init(
        modelManager: TopicModelManager = TopicModelManager(),
        maxSliceCacheEntries: Int = 8,
        maxEmbeddingCacheEntries: Int = 2048,
        maxReductionCacheEntries: Int = 32
    ) {
        self.modelManager = modelManager
        self.maxSliceCacheEntries = max(1, maxSliceCacheEntries)
        self.maxEmbeddingCacheEntries = max(64, maxEmbeddingCacheEntries)
        self.maxReductionCacheEntries = max(4, maxReductionCacheEntries)
    }

    func analyze(
        text: String,
        options: TopicAnalysisOptions,
        progress: (@Sendable (TopicAnalysisProgress) -> Void)?
    ) async throws -> TopicAnalysisResult {
        let analysisStartedAt = Date()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw TopicAnalysisError.noEnglishParagraphs
        }

        progress?(TopicAnalysisProgress(stage: .preparing, detail: "Loading topic model", progress: 0.05))
        let model = try modelManager.loadModel()
        let providerTier = providerTier(for: model)

        let contentHash = Self.stableHash(for: trimmed)
        progress?(TopicAnalysisProgress(stage: .segmenting, detail: "Segmenting paragraphs", progress: 0.15))
        let slicingStartedAt = Date()
        let slices = try makeSlices(for: trimmed, cacheKey: contentHash)
        guard !slices.isEmpty else {
            throw TopicAnalysisError.noEnglishParagraphs
        }
        logStageCompleted("segmenting", startedAt: slicingStartedAt, metadata: [
            "slices": "\(slices.count)",
            "provider": model.providerLabel
        ])
        try Task.checkCancellation()

        progress?(TopicAnalysisProgress(stage: .embedding, detail: "Embedding paragraph vectors", progress: 0.4))
        let embeddingStartedAt = Date()
        let embeddings = makeEmbeddings(for: slices, model: model)
        let allowsApproximateClustering = shouldUseApproximateClustering(vectorCount: slices.count)
        let reducedEmbeddings = reduceEmbeddingsIfNeeded(
            embeddings,
            contentHash: contentHash,
            model: model,
            allowReduction: allowsApproximateClustering
        )
        logStageCompleted("embedding", startedAt: embeddingStartedAt, metadata: [
            "slices": "\(slices.count)",
            "provider": model.providerLabel,
            "dimensions": "\(embeddings.first?.count ?? 0)",
            "reducedDimensions": "\(reducedEmbeddings.reducedDimensions ?? (embeddings.first?.count ?? 0))",
            "explainedVariance": reducedEmbeddings.explainedVariance.map { String(format: "%.3f", $0) } ?? "n/a"
        ])
        try Task.checkCancellation()

        progress?(TopicAnalysisProgress(stage: .clustering, detail: "Clustering topics", progress: 0.72))
        let clusteringStartedAt = Date()
        let clustered = clusterVectors(
            reducedEmbeddings.vectors,
            slices: slices,
            model: model,
            minTopicSize: max(1, options.minTopicSize)
        )
        guard !clustered.validClusters.isEmpty || !clustered.outlierIndices.isEmpty else {
            throw TopicAnalysisError.noTopicsGenerated
        }
        logStageCompleted("clustering", startedAt: clusteringStartedAt, metadata: [
            "clusters": "\(clustered.validClusters.count)",
            "outliers": "\(clustered.outlierIndices.count)",
            "silhouette": String(format: "%.3f", clustered.silhouetteScore),
            "strategy": clustered.strategy.rawValue
        ])
        try Task.checkCancellation()

        progress?(TopicAnalysisProgress(stage: .summarizing, detail: "Building topic summaries", progress: 0.92))
        let summarizingStartedAt = Date()
        let warnings = modelWarnings(for: model, providerTier: providerTier) + clustered.warnings
        let diagnostics = TopicAnalysisDiagnostics(
            providerTier: providerTier,
            clusteringStrategy: clustered.strategy,
            embeddingReduction: TopicEmbeddingReductionDiagnostics(
                applied: reducedEmbeddings.applied,
                originalDimensions: reducedEmbeddings.originalDimensions,
                reducedDimensions: reducedEmbeddings.reducedDimensions,
                explainedVariance: reducedEmbeddings.explainedVariance
            )
        )
        let result = buildResult(
            slices: slices,
            embeddings: reducedEmbeddings.vectors,
            clustered: clustered,
            model: model,
            diagnostics: diagnostics,
            warnings: warnings
        )
        logStageCompleted("summarizing", startedAt: summarizingStartedAt, metadata: [
            "clusters": "\(result.clusters.count)",
            "warnings": "\(result.warnings.count)"
        ])
        progress?(TopicAnalysisProgress(stage: .summarizing, detail: "Topics ready", progress: 1))

        let outlierRatio = result.totalSegments == 0
            ? 0
            : Double(result.outlierCount) / Double(result.totalSegments)
        topicLogger.info(
            "topics.completed provider=\(model.providerLabel, privacy: .public) slices=\(result.totalSegments) clustered=\(result.clusteredSegments) clusters=\(result.clusters.count) reducedDimensions=\(reducedEmbeddings.reducedDimensions ?? (embeddings.first?.count ?? 0)) explainedVariance=\(reducedEmbeddings.explainedVariance.map { String(format: "%.3f", $0) } ?? "n/a", privacy: .public) outlierRatio=\(String(format: "%.3f", outlierRatio), privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: analysisStartedAt))"
        )
        return result
    }

    func providerTier(for model: TopicEmbeddingModel) -> TopicProviderTier {
        switch model.providerLabel {
        case "bundled-local-embedding", "bundled-lexical-embedding":
            return .bundled
        case "system-sentence-embedding":
            return .systemFallback
        default:
            return .hashedFallback
        }
    }

    func modelWarnings(
        for model: TopicEmbeddingModel,
        providerTier: TopicProviderTier
    ) -> [String] {
        switch providerTier {
        case .bundled:
            return []
        case .systemFallback:
            return model.isPrimaryProvider
                ? ["当前 provider 非 bundled，结果精度已降级。当前使用系统句向量。"]
                : ["当前 provider 非 bundled，结果精度已降级。内置主题向量不可用，已回退到系统句向量。"]
        case .hashedFallback:
            return ["当前 provider 非 bundled，结果精度已降级。内置主题向量和系统句向量不可用，已回退到稳定哈希向量，结果仅供探索性参考。"]
        }
    }

    func stableFallbackProviderWarning() -> String {
        "当前 provider 非 bundled，结果精度已降级。内置主题向量和系统句向量不可用，已回退到稳定哈希向量，结果仅供探索性参考。"
    }

    func degradedProviderWarning() -> String {
        "当前 provider 非 bundled，结果精度已降级。当前使用系统句向量。"
    }

    func approximateClusteringWarning() -> String {
        "大语料已切近似聚类。"
    }

    func conservativeFallbackWarning() -> String {
        "Topics 聚类质量较低，结果已保守收缩为单主题加离群片段。"
    }

    func shouldUseApproximateClustering(vectorCount: Int) -> Bool {
        vectorCount > Self.exactClusteringVectorLimit
    }

    func logStageCompleted(
        _ stage: String,
        startedAt: Date,
        metadata: [String: String] = [:]
    ) {
        let metadataText = metadata
            .sorted { $0.key < $1.key }
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: " ")
        if metadataText.isEmpty {
            topicLogger.info(
                "topics.stage stage=\(stage, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt))"
            )
            return
        }
        topicLogger.info(
            "topics.stage stage=\(stage, privacy: .public) \(metadataText, privacy: .public) durationMs=\(WordZTelemetry.elapsedMilliseconds(since: startedAt))"
        )
    }
}
