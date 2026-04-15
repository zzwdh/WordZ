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

struct ClusterState {
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
}

struct TopicEmbeddingReductionResult {
    let vectors: [[Double]]
    let applied: Bool
    let originalDimensions: Int?
    let reducedDimensions: Int?
    let explainedVariance: Double?
}
