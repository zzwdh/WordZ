import Foundation

enum SentimentLabel: String, CaseIterable, Identifiable, Codable, Sendable {
    case positive
    case neutral
    case negative

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .positive:
            return wordZText("积极", "Positive", mode: mode)
        case .neutral:
            return wordZText("中性", "Neutral", mode: mode)
        case .negative:
            return wordZText("消极", "Negative", mode: mode)
        }
    }
}

enum SentimentInputSource: String, CaseIterable, Identifiable, Codable, Sendable {
    case openedCorpus
    case pastedText
    case kwicVisible
    case corpusCompare

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .openedCorpus:
            return wordZText("当前语料", "Opened Corpus", mode: mode)
        case .pastedText:
            return wordZText("粘贴文本", "Pasted Text", mode: mode)
        case .kwicVisible:
            return wordZText("当前 KWIC 结果", "Visible KWIC Results", mode: mode)
        case .corpusCompare:
            return wordZText("目标 / 参照语料", "Target / Reference Corpora", mode: mode)
        }
    }
}

enum SentimentAnalysisUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case document
    case sentence
    case concordanceLine

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .document:
            return wordZText("整篇文本", "Document", mode: mode)
        case .sentence:
            return wordZText("句子", "Sentence", mode: mode)
        case .concordanceLine:
            return wordZText("索引行", "Concordance Line", mode: mode)
        }
    }
}

enum SentimentContextBasis: String, CaseIterable, Identifiable, Codable, Sendable {
    case visibleContext
    case fullSentenceWhenAvailable

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .visibleContext:
            return wordZText("可见上下文", "Visible Context", mode: mode)
        case .fullSentenceWhenAvailable:
            return wordZText("可用时取整句", "Full Sentence When Available", mode: mode)
        }
    }
}

enum SentimentBackendKind: String, CaseIterable, Identifiable, Codable, Sendable {
    case lexicon
    case coreML

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .lexicon:
            return wordZText("词典规则", "Lexicon Rules", mode: mode)
        case .coreML:
            return wordZText("本地模型", "Local Model", mode: mode)
        }
    }
}

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
            return SentimentThresholds(decisionThreshold: 0.35, minimumEvidence: 0.8, neutralBias: 1.2)
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
}

enum SentimentCueDomainTag: String, CaseIterable, Codable, Sendable {
    case core
    case general
    case academic
    case news
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

struct SentimentInputText: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let sourceID: String?
    let sourceTitle: String
    let text: String
    let sentenceID: Int?
    let tokenIndex: Int?
    let groupID: String?
    let groupTitle: String?
    let documentText: String?

    init(
        id: String,
        sourceID: String? = nil,
        sourceTitle: String,
        text: String,
        sentenceID: Int? = nil,
        tokenIndex: Int? = nil,
        groupID: String? = nil,
        groupTitle: String? = nil,
        documentText: String? = nil
    ) {
        self.id = id
        self.sourceID = sourceID
        self.sourceTitle = sourceTitle
        self.text = text
        self.sentenceID = sentenceID
        self.tokenIndex = tokenIndex
        self.groupID = groupID
        self.groupTitle = groupTitle
        self.documentText = documentText
    }
}

struct SentimentEvidenceHit: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let surface: String
    let lemma: String?
    let baseScore: Double
    let adjustedScore: Double
    let ruleTags: [String]
    let tokenIndex: Int
    let tokenLength: Int
}

struct SentimentRowDiagnostics: Equatable, Codable, Sendable {
    var mixedEvidence: Bool
    var ruleSummary: String?
    var scopeNotes: [String]
    var confidence: Double?
    var topMargin: Double?
    var subunitCount: Int?
    var truncated: Bool
    var aggregatedFrom: SentimentAggregationMode?
    var modelRevision: String?

    static let empty = SentimentRowDiagnostics(
        mixedEvidence: false,
        ruleSummary: nil,
        scopeNotes: [],
        confidence: nil,
        topMargin: nil,
        subunitCount: nil,
        truncated: false,
        aggregatedFrom: nil,
        modelRevision: nil
    )
}

struct SentimentRowResult: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let sourceID: String?
    let sourceTitle: String
    let groupID: String?
    let groupTitle: String?
    let text: String
    let positivityScore: Double
    let negativityScore: Double
    let neutralityScore: Double
    let finalLabel: SentimentLabel
    let netScore: Double
    let evidence: [SentimentEvidenceHit]
    let evidenceCount: Int
    let mixedEvidence: Bool
    let diagnostics: SentimentRowDiagnostics
    let sentenceID: Int?
    let tokenIndex: Int?
}

struct SentimentAggregateSummary: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let title: String
    let totalTexts: Int
    let positiveCount: Int
    let neutralCount: Int
    let negativeCount: Int
    let positiveRatio: Double
    let neutralRatio: Double
    let negativeRatio: Double
    let averagePositivity: Double
    let averageNeutrality: Double
    let averageNegativity: Double
    let averageNetScore: Double
}

struct SentimentRunRequest: Equatable, Codable, Sendable {
    let source: SentimentInputSource
    let unit: SentimentAnalysisUnit
    let contextBasis: SentimentContextBasis
    let thresholds: SentimentThresholds
    let texts: [SentimentInputText]
    let backend: SentimentBackendKind
}

struct SentimentRunResult: Equatable, Codable, Sendable {
    let request: SentimentRunRequest
    let backendKind: SentimentBackendKind
    let backendRevision: String
    let resourceRevision: String
    let supportsEvidenceHits: Bool
    let rows: [SentimentRowResult]
    let overallSummary: SentimentAggregateSummary
    let groupSummaries: [SentimentAggregateSummary]
    let lexiconVersion: String
}
