import Foundation
import WordZShared

enum SentimentThresholdPreset: String, CaseIterable, Identifiable, Codable, Sendable {
    case conservative
    case balanced
    case sensitive
    case custom

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .conservative:
            return wordZText("保守", "Conservative", mode: mode)
        case .balanced:
            return wordZText("平衡", "Balanced", mode: mode)
        case .sensitive:
            return wordZText("敏感", "Sensitive", mode: mode)
        case .custom:
            return wordZText("自定义", "Custom", mode: mode)
        }
    }

    var thresholds: SentimentThresholds {
        switch self {
        case .conservative:
            return SentimentThresholds(decisionThreshold: 0.30, minimumEvidence: 0.70, neutralBias: 1.10)
        case .balanced:
            return SentimentThresholds(decisionThreshold: 0.25, minimumEvidence: 0.6, neutralBias: 1.0)
        case .sensitive:
            return SentimentThresholds(decisionThreshold: 0.2, minimumEvidence: 0.4, neutralBias: 0.9)
        case .custom:
            return .default
        }
    }
}

enum SentimentCueMatchMode: String, Codable, Sendable {
    case lemma
    case surface
    case either
}

enum SentimentCueCategory: String, Codable, Sendable {
    case corePositive
    case coreNegative
    case weakEvaluative
    case academicCaution
    case newsEvaluative
    case hedge
    case neutralShield
}

enum SentimentCueDomainTag: String, CaseIterable, Codable, Sendable {
    case core
    case general
    case academic
    case news
    case kwic
}

enum SentimentAggregationMode: String, Codable, Sendable {
    case direct
    case sentenceMean
}

struct SentimentThresholds: Equatable, Codable, Sendable {
    var decisionThreshold: Double
    var minimumEvidence: Double
    var neutralBias: Double

    static let `default` = SentimentThresholdPreset.conservative.thresholds
}

