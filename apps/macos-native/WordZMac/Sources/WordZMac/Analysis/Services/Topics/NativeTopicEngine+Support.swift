import Foundation

struct TopicTextSlice {
    let id: String
    let paragraphIndex: Int
    let text: String
    let tokens: [String]
    let keywordTerms: [String]
    let keywordBigrams: [String]

    var embeddingInput: TopicEmbeddingInput {
        TopicEmbeddingInput(
            text: text,
            tokens: tokens,
            keywordTerms: keywordTerms,
            keywordBigrams: keywordBigrams
        )
    }
}

struct ClusterState: Equatable {
    var memberIndices: [Int]
    var centroid: [Double]
}

struct TopicClusteringResult {
    let validClusters: [ClusterState]
    let outlierIndices: [Int]
    let similarityMatrix: [[Double]]
    let silhouetteScore: Double
    let strategy: TopicClusteringStrategy
    let warnings: [String]
    let approximateDiagnostics: TopicApproximateClusteringDiagnostics?

    init(
        validClusters: [ClusterState],
        outlierIndices: [Int],
        similarityMatrix: [[Double]],
        silhouetteScore: Double,
        strategy: TopicClusteringStrategy,
        warnings: [String],
        approximateDiagnostics: TopicApproximateClusteringDiagnostics? = nil
    ) {
        self.validClusters = validClusters
        self.outlierIndices = outlierIndices
        self.similarityMatrix = similarityMatrix
        self.silhouetteScore = silhouetteScore
        self.strategy = strategy
        self.warnings = warnings
        self.approximateDiagnostics = approximateDiagnostics
    }
}

struct TopicEmbeddingReductionResult {
    let vectors: [[Double]]
    let applied: Bool
    let originalDimensions: Int?
    let reducedDimensions: Int?
    let explainedVariance: Double?
}

struct TopicNormalizedVectorMatrix {
    let rowCount: Int
    let columnCount: Int
    let storage: [Double]
}

final class TopicApproximateClusteringDiagnosticsBuilder: @unchecked Sendable {
    private let lock = NSLock()
    private var stageDurationsMs: [String: Double] = [:]
    private var candidateEvaluationCount = 0
    private var coarseCandidateCounts: [Int] = []
    private var refinedCandidateCounts: [Int] = []
    private var usedTwoStageSearch = false

    func recordCandidateEvaluation() {
        lock.lock()
        defer { lock.unlock() }
        candidateEvaluationCount += 1
    }

    func setCoarseCandidateCounts(_ counts: [Int]) {
        lock.lock()
        defer { lock.unlock() }
        coarseCandidateCounts = counts
    }

    func setRefinedCandidateCounts(_ counts: [Int]) {
        lock.lock()
        defer { lock.unlock() }
        refinedCandidateCounts = counts
    }

    func setUsedTwoStageSearch(_ used: Bool) {
        lock.lock()
        defer { lock.unlock() }
        usedTwoStageSearch = used
    }

    func measure<T>(_ stage: String, _ work: () -> T) -> T {
        let startedAt = Date()
        let value = work()
        lock.lock()
        defer { lock.unlock() }
        stageDurationsMs[stage, default: 0] += Date().timeIntervalSince(startedAt) * 1000
        return value
    }

    func build() -> TopicApproximateClusteringDiagnostics {
        lock.lock()
        defer { lock.unlock() }
        return TopicApproximateClusteringDiagnostics(
            stageDurationsMs: stageDurationsMs,
            candidateEvaluationCount: candidateEvaluationCount,
            coarseCandidateCounts: coarseCandidateCounts,
            refinedCandidateCounts: refinedCandidateCounts,
            usedTwoStageSearch: usedTwoStageSearch
        )
    }
}
