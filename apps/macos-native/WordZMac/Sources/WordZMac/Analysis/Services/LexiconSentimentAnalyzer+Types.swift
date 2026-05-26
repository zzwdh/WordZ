import Foundation

struct SentimentScoringUnit {
    let id: String
    let sourceID: String?
    let sourceTitle: String
    let groupID: String?
    let groupTitle: String?
    let text: String
    let sentenceID: Int?
    let tokenIndex: Int?
    let tokens: [ParsedToken]
}

struct SentimentPhraseMatch {
    let entry: SentimentLexiconEntry
    let tokenIndex: Int
    let tokenLength: Int
    let surface: String
    let lemma: String?
}

struct AdjustedSentimentEvidence {
    let hit: SentimentEvidenceHit
    let trace: SentimentRuleTrace
    let reviewFlags: [SentimentReviewFlag]
}

struct SentimentCueContext {
    let insideQuotes: Bool
    let reportingVerb: String?
    let isReportedSpeech: Bool
}

struct SentimentScoredRow {
    let positivityScore: Double
    let negativityScore: Double
    let neutralityScore: Double
    let finalLabel: SentimentLabel
    let netScore: Double
    let evidence: [SentimentEvidenceHit]
    let evidenceCount: Int
    let mixedEvidence: Bool
    let positiveEvidence: Double
    let negativeEvidence: Double
    let diagnostics: SentimentRowDiagnostics
}

