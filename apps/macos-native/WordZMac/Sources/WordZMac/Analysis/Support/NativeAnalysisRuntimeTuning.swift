import Foundation

struct NativeAnalysisRuntimeTuning: Codable, Equatable, Sendable {
    let topicExactClusteringVectorLimit: Int
    let topicApproximateClusteringIterationLimit: Int
    let topicApproximateClusteringClusterLimit: Int
    let topicApproximateClusteringSeedVariants: Int
    let topicEmbeddingBatchSize: Int
    let topicEmbeddingCacheEntries: Int
    let topicReductionCacheEntries: Int
    let shouldConserveResources: Bool
    let hardwareSummary: String

    static func topicTuning(
        profile: NativeHardwareProfile = HardwareAccelerationPolicy.currentHardwareProfile()
    ) -> Self {
        let constrainedMemory = profile.physicalMemoryMegabytes < 8_192
        let conserving = profile.shouldConserveResources || constrainedMemory
        return Self(
            topicExactClusteringVectorLimit: conserving ? 240 : 320,
            topicApproximateClusteringIterationLimit: conserving ? 24 : 32,
            topicApproximateClusteringClusterLimit: conserving ? 10 : 12,
            topicApproximateClusteringSeedVariants: conserving ? 3 : 5,
            topicEmbeddingBatchSize: conserving ? 160 : 320,
            topicEmbeddingCacheEntries: conserving ? 1_024 : 2_048,
            topicReductionCacheEntries: conserving ? 16 : 32,
            shouldConserveResources: conserving,
            hardwareSummary: profile.summaryLine
        )
    }

    var summaryLine: String {
        [
            "conserve=\(shouldConserveResources)",
            "exactLimit=\(topicExactClusteringVectorLimit)",
            "iterations=\(topicApproximateClusteringIterationLimit)",
            "clusterLimit=\(topicApproximateClusteringClusterLimit)",
            "seedVariants=\(topicApproximateClusteringSeedVariants)",
            "batchSize=\(topicEmbeddingBatchSize)",
            "embeddingCache=\(topicEmbeddingCacheEntries)",
            "reductionCache=\(topicReductionCacheEntries)",
            hardwareSummary
        ].joined(separator: " ")
    }
}
