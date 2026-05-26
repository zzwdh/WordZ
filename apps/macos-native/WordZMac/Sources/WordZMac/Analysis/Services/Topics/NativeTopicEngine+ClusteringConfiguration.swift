import Foundation

extension NativeTopicEngine {
    static let exactClusteringVectorLimit = 320
    static let exactLexicalRefinementSliceLimit = 48
    static let exactSmallCorpusClusterLimit = 6
    static let exactSmallCorpusSeedVariants = 4
    static let exactSmallCorpusIterationLimit = 18
    static let approximateClusteringIterationLimit = 32
    static let approximateClusteringClusterLimit = 12
    static let approximateClusteringSeedVariants = 5
    static let approximateOutlierSimilarityFloor = 0.18
    static let approximateOutlierMedianOffset = 0.22
}
