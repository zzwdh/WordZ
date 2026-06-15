import Foundation
import WordZShared

enum SentimentReviewFlag: String, CaseIterable, Codable, Sendable {
    case lowMargin
    case mixedEvidence
    case shielded
    case quoted
    case reported
}

enum SentimentReviewFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case all
    case lowMargin
    case mixedEvidence
    case shielded
    case quoted
    case reported

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .all:
            return wordZText("全部", "All", mode: mode)
        case .lowMargin:
            return wordZText("低边际", "Low Margin", mode: mode)
        case .mixedEvidence:
            return wordZText("混合证据", "Mixed", mode: mode)
        case .shielded:
            return wordZText("中性屏蔽", "Shielded", mode: mode)
        case .quoted:
            return wordZText("引号语句", "Quoted", mode: mode)
        case .reported:
            return wordZText("转述 / 报道", "Reported", mode: mode)
        }
    }
}


extension SentimentReviewFilter {
    func includes(_ row: SentimentRowResult) -> Bool {
        switch self {
        case .all:
            return true
        case .lowMargin:
            return row.diagnostics.reviewFlags.contains(.lowMargin)
                || ((row.diagnostics.topMargin ?? 1.0) < 0.12)
        case .mixedEvidence:
            return row.diagnostics.reviewFlags.contains(.mixedEvidence) || row.mixedEvidence
        case .shielded:
            return row.diagnostics.reviewFlags.contains(.shielded)
                || row.diagnostics.ruleTraces.contains(where: { $0.neutralShieldReason?.isEmpty == false })
        case .quoted:
            return row.diagnostics.reviewFlags.contains(.quoted)
                || row.evidence.contains(where: { $0.ruleTags.contains("quotedEvidence") })
        case .reported:
            return row.diagnostics.reviewFlags.contains(.reported)
                || row.evidence.contains(where: { $0.ruleTags.contains("reportedSpeech") })
        }
    }
}

