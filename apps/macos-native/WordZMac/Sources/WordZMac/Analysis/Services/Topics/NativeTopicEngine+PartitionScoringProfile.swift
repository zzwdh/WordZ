import Foundation

extension TopicPartitionScoringProfile {
    var coverageBonusWeight: Double {
        switch self {
        case .balanced: return 0.1
        case .precisionFirst: return 0.055
        }
    }

    var outlierPenaltyWeight: Double {
        switch self {
        case .balanced: return 0.25
        case .precisionFirst: return 0.14
        }
    }

    var singleClusterPenalty: Double {
        switch self {
        case .balanced: return 0.1
        case .precisionFirst: return 0.15
        }
    }

    var singleClusterLexicalContrastWeight: Double {
        switch self {
        case .balanced: return 0.14
        case .precisionFirst: return 0.22
        }
    }

    func singleClusterLexicalCohesionWeight(_ smallCorpusPurityBonus: Double) -> Double {
        switch self {
        case .balanced:
            return 0.12 + (0.12 * smallCorpusPurityBonus)
        case .precisionFirst:
            return 0.19 + (0.18 * smallCorpusPurityBonus)
        }
    }

    var clusterCountBonusCap: Double {
        switch self {
        case .balanced: return 0.06
        case .precisionFirst: return 0.035
        }
    }

    var clusterCountBonusStep: Double {
        switch self {
        case .balanced: return 0.015
        case .precisionFirst: return 0.01
        }
    }

    var averageWithinBonusWeight: Double {
        switch self {
        case .balanced: return 0
        case .precisionFirst: return 0.12
        }
    }

    var multiClusterLexicalContrastWeight: Double {
        switch self {
        case .balanced: return 0.18
        case .precisionFirst: return 0.26
        }
    }

    func multiClusterLexicalCohesionWeight(_ smallCorpusPurityBonus: Double) -> Double {
        switch self {
        case .balanced:
            return 0.16 + (0.16 * smallCorpusPurityBonus)
        case .precisionFirst:
            return 0.24 + (0.22 * smallCorpusPurityBonus)
        }
    }

    var approximateSingleClusterPenalty: Double {
        switch self {
        case .balanced: return 0.08
        case .precisionFirst: return 0.12
        }
    }

    var approximateAverageWithinWeight: Double {
        switch self {
        case .balanced: return 0.62
        case .precisionFirst: return 0.72
        }
    }

    var approximateSeparationWeight: Double {
        switch self {
        case .balanced: return 0.32
        case .precisionFirst: return 0.36
        }
    }

    var approximateClusterCountBonusCap: Double {
        switch self {
        case .balanced: return 0.04
        case .precisionFirst: return 0.025
        }
    }

    var approximateClusterCountBonusStep: Double {
        switch self {
        case .balanced: return 0.01
        case .precisionFirst: return 0.006
        }
    }
}
