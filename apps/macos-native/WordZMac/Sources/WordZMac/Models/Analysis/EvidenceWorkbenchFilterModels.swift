import Foundation

enum EvidenceSourceFilter: String, CaseIterable, Identifiable, Sendable, Hashable {
    case all
    case kwic
    case locator
    case plot
    case sentiment
    case topics

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .all:
            return wordZText("全部来源", "All Sources", mode: mode)
        case .kwic:
            return EvidenceSourceKind.kwic.title(in: mode)
        case .locator:
            return EvidenceSourceKind.locator.title(in: mode)
        case .plot:
            return EvidenceSourceKind.plot.title(in: mode)
        case .sentiment:
            return EvidenceSourceKind.sentiment.title(in: mode)
        case .topics:
            return EvidenceSourceKind.topics.title(in: mode)
        }
    }

    func includes(_ item: EvidenceItem) -> Bool {
        switch self {
        case .all:
            return true
        case .kwic:
            return item.sourceKind == .kwic
        case .locator:
            return item.sourceKind == .locator
        case .plot:
            return item.sourceKind == .plot
        case .sentiment:
            return item.sourceKind == .sentiment
        case .topics:
            return item.sourceKind == .topics
        }
    }
}

enum EvidenceSentimentFilter: String, CaseIterable, Identifiable, Sendable, Hashable {
    case all
    case positive
    case neutral
    case negative

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .all:
            return wordZText("全部情感", "All Sentiment", mode: mode)
        case .positive:
            return SentimentLabel.positive.title(in: mode)
        case .neutral:
            return SentimentLabel.neutral.title(in: mode)
        case .negative:
            return SentimentLabel.negative.title(in: mode)
        }
    }

    func includes(_ item: EvidenceItem) -> Bool {
        switch self {
        case .all:
            return true
        case .positive:
            return item.sentimentMetadata?.effectiveLabel == .positive
        case .neutral:
            return item.sentimentMetadata?.effectiveLabel == .neutral
        case .negative:
            return item.sentimentMetadata?.effectiveLabel == .negative
        }
    }
}
