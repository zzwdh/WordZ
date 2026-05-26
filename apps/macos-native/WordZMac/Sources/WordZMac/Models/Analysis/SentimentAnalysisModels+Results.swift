import Foundation

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


struct SentimentRunResult: Equatable, Codable, Sendable {
    let request: SentimentRunRequest
    let backendKind: SentimentBackendKind
    let backendRevision: String
    let resourceRevision: String
    let providerID: String?
    let providerFamily: SentimentModelProviderFamily?
    let supportsEvidenceHits: Bool
    let rows: [SentimentRowResult]
    let overallSummary: SentimentAggregateSummary
    let groupSummaries: [SentimentAggregateSummary]
    let lexiconVersion: String
    let activeRuleProfileRevision: String
    let activePackIDs: [SentimentDomainPackID]
    let calibrationProfileRevision: String
    let userLexiconBundleIDs: [String]

    init(
        request: SentimentRunRequest,
        backendKind: SentimentBackendKind,
        backendRevision: String,
        resourceRevision: String,
        providerID: String? = nil,
        providerFamily: SentimentModelProviderFamily? = nil,
        supportsEvidenceHits: Bool,
        rows: [SentimentRowResult],
        overallSummary: SentimentAggregateSummary,
        groupSummaries: [SentimentAggregateSummary],
        lexiconVersion: String,
        activeRuleProfileRevision: String? = nil,
        activePackIDs: [SentimentDomainPackID] = [],
        calibrationProfileRevision: String? = nil,
        userLexiconBundleIDs: [String] = []
    ) {
        self.request = request
        self.backendKind = backendKind
        self.backendRevision = backendRevision
        self.resourceRevision = resourceRevision
        self.providerID = providerID
        self.providerFamily = providerFamily
        self.supportsEvidenceHits = supportsEvidenceHits
        self.rows = rows
        self.overallSummary = overallSummary
        self.groupSummaries = groupSummaries
        self.lexiconVersion = lexiconVersion
        self.activeRuleProfileRevision = activeRuleProfileRevision ?? request.ruleProfile.revision
        self.activePackIDs = activePackIDs.isEmpty ? [request.resolvedDomainPackID] : activePackIDs
        self.calibrationProfileRevision = calibrationProfileRevision ?? request.calibrationProfile.revision
        self.userLexiconBundleIDs = userLexiconBundleIDs.isEmpty
            ? request.userLexiconBundleIDs
            : userLexiconBundleIDs
    }
}

