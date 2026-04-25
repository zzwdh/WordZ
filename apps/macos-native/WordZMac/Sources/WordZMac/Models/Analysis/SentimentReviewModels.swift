import CryptoKit
import Foundation

enum SentimentReviewDecision: String, CaseIterable, Codable, Sendable {
    case confirmRaw
    case overridePositive
    case overrideNeutral
    case overrideNegative

    var effectiveLabel: SentimentLabel? {
        switch self {
        case .confirmRaw:
            return nil
        case .overridePositive:
            return .positive
        case .overrideNeutral:
            return .neutral
        case .overrideNegative:
            return .negative
        }
    }
}

enum SentimentReviewStatus: String, CaseIterable, Identifiable, Codable, Sendable {
    case unreviewed
    case confirmed
    case overridden

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .unreviewed:
            return wordZText("未审阅", "Unreviewed", mode: mode)
        case .confirmed:
            return wordZText("确认原判", "Confirmed Raw", mode: mode)
        case .overridden:
            return wordZText("人工改标", "Manual Override", mode: mode)
        }
    }
}

enum SentimentReviewStatusFilter: String, CaseIterable, Identifiable, Codable, Sendable {
    case all
    case unreviewed
    case confirmed
    case overridden

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .all:
            return wordZText("全部", "All", mode: mode)
        case .unreviewed:
            return wordZText("未审阅", "Unreviewed", mode: mode)
        case .confirmed:
            return wordZText("确认原判", "Confirmed", mode: mode)
        case .overridden:
            return wordZText("人工改标", "Overridden", mode: mode)
        }
    }

    func includes(_ row: SentimentEffectiveRow) -> Bool {
        switch self {
        case .all:
            return true
        case .unreviewed:
            return row.reviewStatus == .unreviewed
        case .confirmed:
            return row.reviewStatus == .confirmed
        case .overridden:
            return row.reviewStatus == .overridden
        }
    }
}

struct SentimentScoreTriple: Equatable, Codable, Sendable {
    let positivityScore: Double
    let neutralityScore: Double
    let negativityScore: Double
    let netScore: Double

    init(
        positivityScore: Double,
        neutralityScore: Double,
        negativityScore: Double,
        netScore: Double
    ) {
        self.positivityScore = positivityScore
        self.neutralityScore = neutralityScore
        self.negativityScore = negativityScore
        self.netScore = netScore
    }

    static func oneHot(for label: SentimentLabel) -> SentimentScoreTriple {
        switch label {
        case .positive:
            return SentimentScoreTriple(
                positivityScore: 1,
                neutralityScore: 0,
                negativityScore: 0,
                netScore: 1
            )
        case .neutral:
            return SentimentScoreTriple(
                positivityScore: 0,
                neutralityScore: 1,
                negativityScore: 0,
                netScore: 0
            )
        case .negative:
            return SentimentScoreTriple(
                positivityScore: 0,
                neutralityScore: 0,
                negativityScore: 1,
                netScore: -1
            )
        }
    }
}

struct SentimentReviewMatchKey: Equatable, Hashable, Codable, Sendable {
    let source: SentimentInputSource
    let unit: SentimentAnalysisUnit
    let contextBasis: SentimentContextBasis
    let sourceID: String?
    let groupID: String?
    let sentenceID: Int?
    let tokenIndex: Int?
    let normalizedTextHash: String

    var storageKey: String {
        [
            source.rawValue,
            unit.rawValue,
            contextBasis.rawValue,
            sourceID ?? "",
            groupID ?? "",
            sentenceID.map(String.init) ?? "",
            tokenIndex.map(String.init) ?? "",
            normalizedTextHash
        ]
        .joined(separator: "::")
    }

    static func make(
        request: SentimentRunRequest,
        row: SentimentRowResult
    ) -> SentimentReviewMatchKey {
        SentimentReviewMatchKey(
            source: request.source,
            unit: request.unit,
            contextBasis: request.contextBasis,
            sourceID: normalizedReviewKeyText(row.sourceID),
            groupID: normalizedReviewKeyText(row.groupID),
            sentenceID: row.sentenceID,
            tokenIndex: row.tokenIndex,
            normalizedTextHash: normalizedTextDigest(row.text)
        )
    }
}

struct SentimentReviewSample: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let matchKey: SentimentReviewMatchKey
    let decision: SentimentReviewDecision
    let rawLabel: SentimentLabel
    let rawScores: SentimentScoreTriple
    let reviewNote: String?
    let createdAt: String
    let updatedAt: String
    let backendKind: SentimentBackendKind
    let backendRevision: String
    let domainPackID: SentimentDomainPackID
    let ruleProfileID: String
    let calibrationProfileRevision: String
    let activePackIDs: [SentimentDomainPackID]

    var reviewStatus: SentimentReviewStatus {
        switch decision {
        case .confirmRaw:
            return .confirmed
        case .overridePositive, .overrideNeutral, .overrideNegative:
            return .overridden
        }
    }

    var effectiveLabel: SentimentLabel {
        decision.effectiveLabel ?? rawLabel
    }

    var effectiveScores: SentimentScoreTriple {
        decision.effectiveLabel.map(SentimentScoreTriple.oneHot(for:)) ?? rawScores
    }
}

struct SentimentReviewSummary: Equatable, Codable, Sendable {
    let reviewedCount: Int
    let confirmedRawCount: Int
    let overriddenCount: Int
    let pendingHardCaseCount: Int

    static let empty = SentimentReviewSummary(
        reviewedCount: 0,
        confirmedRawCount: 0,
        overriddenCount: 0,
        pendingHardCaseCount: 0
    )
}

struct SentimentEffectiveRow: Identifiable, Equatable, Codable, Sendable {
    let rawRow: SentimentRowResult
    let effectiveLabel: SentimentLabel
    let effectiveScores: SentimentScoreTriple
    let reviewDecision: SentimentReviewDecision?
    let reviewStatus: SentimentReviewStatus
    let reviewNote: String?
    let reviewedAt: String?
    let reviewSampleID: String?

    var id: String { rawRow.id }
    var rawLabel: SentimentLabel { rawRow.finalLabel }
    var rawScores: SentimentScoreTriple { rawRow.scoreTriple }
    var effectiveNetScore: Double { effectiveScores.netScore }
}

struct SentimentPresentationResult: Equatable, Codable, Sendable {
    let rawResult: SentimentRunResult
    let effectiveRows: [SentimentEffectiveRow]
    let effectiveOverallSummary: SentimentAggregateSummary
    let effectiveGroupSummaries: [SentimentAggregateSummary]
    let reviewSummary: SentimentReviewSummary
}

extension SentimentRowResult {
    var scoreTriple: SentimentScoreTriple {
        SentimentScoreTriple(
            positivityScore: positivityScore,
            neutralityScore: neutralityScore,
            negativityScore: negativityScore,
            netScore: netScore
        )
    }
}

private func normalizedReviewKeyText(_ value: String?) -> String? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

private func normalizedTextDigest(_ text: String) -> String {
    let normalized = text
        .lowercased()
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
    let digest = SHA256.hash(data: Data(normalized.utf8))
    return digest.map { String(format: "%02x", $0) }.joined()
}
