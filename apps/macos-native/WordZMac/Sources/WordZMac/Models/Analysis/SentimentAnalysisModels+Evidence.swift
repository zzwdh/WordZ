import Foundation

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

struct SentimentRuleTraceStep: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let tag: String
    let note: String
    let multiplier: Double?

    init(
        id: String = UUID().uuidString,
        tag: String,
        note: String,
        multiplier: Double? = nil
    ) {
        self.id = id
        self.tag = tag
        self.note = note
        self.multiplier = multiplier
    }
}

struct SentimentRuleTrace: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let cueSurface: String
    let cueLemma: String?
    let cueCategory: SentimentCueCategory
    let packID: SentimentDomainPackID?
    let scopeStart: Int
    let scopeEnd: Int
    let clauseIndex: Int
    let clauseWeight: Double
    let baseScore: Double
    let adjustedScore: Double
    let appliedSteps: [SentimentRuleTraceStep]
    let neutralShieldReason: String?

    init(
        id: String = UUID().uuidString,
        cueSurface: String,
        cueLemma: String? = nil,
        cueCategory: SentimentCueCategory,
        packID: SentimentDomainPackID? = nil,
        scopeStart: Int,
        scopeEnd: Int,
        clauseIndex: Int,
        clauseWeight: Double,
        baseScore: Double,
        adjustedScore: Double,
        appliedSteps: [SentimentRuleTraceStep] = [],
        neutralShieldReason: String? = nil
    ) {
        self.id = id
        self.cueSurface = cueSurface
        self.cueLemma = cueLemma
        self.cueCategory = cueCategory
        self.packID = packID
        self.scopeStart = scopeStart
        self.scopeEnd = scopeEnd
        self.clauseIndex = clauseIndex
        self.clauseWeight = clauseWeight
        self.baseScore = baseScore
        self.adjustedScore = adjustedScore
        self.appliedSteps = appliedSteps
        self.neutralShieldReason = neutralShieldReason
    }
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
    var ruleTraces: [SentimentRuleTrace]
    var reviewFlags: [SentimentReviewFlag]
    var activeRuleProfileID: String?
    var activePackIDs: [SentimentDomainPackID]
    var calibrationProfileRevision: String?
    var providerID: String?
    var providerFamily: SentimentModelProviderFamily?
    var inferencePath: SentimentInferencePath?
    var modelInputKind: SentimentModelInputSchemaKind?

    init(
        mixedEvidence: Bool,
        ruleSummary: String?,
        scopeNotes: [String],
        confidence: Double?,
        topMargin: Double?,
        subunitCount: Int?,
        truncated: Bool,
        aggregatedFrom: SentimentAggregationMode?,
        modelRevision: String?,
        ruleTraces: [SentimentRuleTrace] = [],
        reviewFlags: [SentimentReviewFlag] = [],
        activeRuleProfileID: String? = nil,
        activePackIDs: [SentimentDomainPackID] = [],
        calibrationProfileRevision: String? = nil,
        providerID: String? = nil,
        providerFamily: SentimentModelProviderFamily? = nil,
        inferencePath: SentimentInferencePath? = nil,
        modelInputKind: SentimentModelInputSchemaKind? = nil
    ) {
        self.mixedEvidence = mixedEvidence
        self.ruleSummary = ruleSummary
        self.scopeNotes = scopeNotes
        self.confidence = confidence
        self.topMargin = topMargin
        self.subunitCount = subunitCount
        self.truncated = truncated
        self.aggregatedFrom = aggregatedFrom
        self.modelRevision = modelRevision
        self.ruleTraces = ruleTraces
        self.reviewFlags = reviewFlags
        self.activeRuleProfileID = activeRuleProfileID
        self.activePackIDs = activePackIDs
        self.calibrationProfileRevision = calibrationProfileRevision
        self.providerID = providerID
        self.providerFamily = providerFamily
        self.inferencePath = inferencePath
        self.modelInputKind = modelInputKind
    }

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

