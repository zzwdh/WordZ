import Foundation

enum SourceReaderOriginFeature: String, Equatable, Sendable {
    case kwic
    case locator
    case plot

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .kwic:
            return "KWIC"
        case .locator:
            return wordZText("定位器", "Locator", mode: mode)
        case .plot:
            return "Plot"
        }
    }
}

struct SourceReaderHitAnchor: Identifiable, Equatable, Sendable {
    let id: String
    let sentenceId: Int
    let tokenIndex: Int?
    let keyword: String
    let leftContext: String?
    let rightContext: String?
    let concordanceText: String?
    let citationText: String?
    let fullSentenceText: String?
}

struct SourceReaderLaunchContext: Equatable, Sendable {
    let origin: SourceReaderOriginFeature
    let corpusID: String?
    let corpusName: String
    let displayName: String
    let filePath: String
    let query: String
    let leftWindow: Int?
    let rightWindow: Int?
    let searchOptionsSummary: String?
    let hitAnchors: [SourceReaderHitAnchor]
    let selectedHitID: String?
    let fallbackText: String?
}

struct SourceReaderHitSceneItem: Identifiable, Equatable {
    let id: String
    let sentenceId: Int
    let sentenceLabel: String
    let keyword: String
    let concordanceText: String
    let citationText: String
    let fullSentenceText: String
}

struct SourceReaderSentenceSceneItem: Identifiable, Equatable {
    let id: String
    let sentenceId: Int
    let sentenceLabel: String
    let text: String
    let containsHit: Bool
    let isSelected: Bool
}

struct SourceReaderSelection: Equatable {
    let hit: SourceReaderHitSceneItem
    let leftContext: String
    let keyword: String
    let rightContext: String
}

struct SourceReaderSceneModel: Equatable {
    let title: String
    let subtitle: String
    let filePath: String
    let originSummary: String
    let hitCountSummary: String
    let hitItems: [SourceReaderHitSceneItem]
    let selectedHitID: String?
    let sentences: [SourceReaderSentenceSceneItem]
    let selection: SourceReaderSelection?
}
