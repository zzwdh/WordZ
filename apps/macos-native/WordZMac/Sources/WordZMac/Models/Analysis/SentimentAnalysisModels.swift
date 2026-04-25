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
    case topicSegments

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
        case .topicSegments:
            return wordZText("当前 Topics 片段", "Current Topics Segments", mode: mode)
        }
    }
}

enum SentimentAnalysisUnit: String, CaseIterable, Identifiable, Codable, Sendable {
    case document
    case sentence
    case concordanceLine
    case sourceSentence

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .document:
            return wordZText("整篇文本", "Document", mode: mode)
        case .sentence:
            return wordZText("句子", "Sentence", mode: mode)
        case .concordanceLine:
            return wordZText("索引行", "Concordance Line", mode: mode)
        case .sourceSentence:
            return wordZText("来源句子", "Source Sentence", mode: mode)
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

enum SentimentModelProviderFamily: String, CaseIterable, Codable, Sendable {
    case bundledCoreML
    case embeddingLogReg
    case textMaxEnt
    case transformerCoreML
    case unknown

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .bundledCoreML:
            return wordZText("内置 Core ML", "Bundled Core ML", mode: mode)
        case .embeddingLogReg:
            return wordZText("句向量 + 逻辑回归", "Sentence Embedding + Logistic Regression", mode: mode)
        case .textMaxEnt:
            return wordZText("文本最大熵", "Text MaxEnt", mode: mode)
        case .transformerCoreML:
            return wordZText("Transformer Core ML", "Transformer Core ML", mode: mode)
        case .unknown:
            return wordZText("未知", "Unknown", mode: mode)
        }
    }
}

enum SentimentModelInputSchemaKind: String, CaseIterable, Codable, Sendable {
    case text
    case denseFeatures
    case tokenizedText

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .text:
            return wordZText("原始文本", "Raw Text", mode: mode)
        case .denseFeatures:
            return wordZText("稠密特征", "Dense Features", mode: mode)
        case .tokenizedText:
            return wordZText("分词序列", "Tokenized Sequence", mode: mode)
        }
    }
}

enum SentimentInferencePath: String, CaseIterable, Codable, Sendable {
    case lexicon
    case model
    case hybrid
    case fallback

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .lexicon:
            return wordZText("词典规则", "Lexicon", mode: mode)
        case .model:
            return wordZText("本地模型", "Local Model", mode: mode)
        case .hybrid:
            return wordZText("混合判别", "Hybrid", mode: mode)
        case .fallback:
            return wordZText("回退路径", "Fallback", mode: mode)
        }
    }
}

enum SentimentDomainPackID: String, CaseIterable, Identifiable, Codable, Sendable {
    case general
    case academic
    case news
    case kwic
    case mixed

    var id: String { rawValue }

    func title(in mode: AppLanguageMode) -> String {
        switch self {
        case .general:
            return wordZText("通用", "General", mode: mode)
        case .academic:
            return wordZText("学术", "Academic", mode: mode)
        case .news:
            return wordZText("新闻", "News", mode: mode)
        case .kwic:
            return wordZText("KWIC", "KWIC", mode: mode)
        case .mixed:
            return wordZText("混合", "Mixed", mode: mode)
        }
    }
}

enum SentimentRuleProfileSourceKind: String, CaseIterable, Codable, Sendable {
    case builtInDefault
    case workspace
    case importedBundle
}

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

struct SentimentRulePackManifest: Equatable, Codable, Sendable {
    var version: String
    var backendRevision: String
    var resourceRevision: String
    var bundledPackIDs: [SentimentDomainPackID]

    init(
        version: String,
        backendRevision: String,
        resourceRevision: String,
        bundledPackIDs: [SentimentDomainPackID] = SentimentDomainPackID.allCases
    ) {
        self.version = version
        self.backendRevision = backendRevision
        self.resourceRevision = resourceRevision
        self.bundledPackIDs = bundledPackIDs
    }
}

struct SentimentRulePack: Identifiable, Equatable, Codable, Sendable {
    let id: SentimentDomainPackID
    let title: String
    let entryCount: Int
    let resourceFiles: [String]
}

struct SentimentUserLexiconEntry: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let term: String
    let score: Double
    let category: SentimentCueCategory
    let domainTags: [SentimentCueDomainTag]
    let matchMode: SentimentCueMatchMode

    init(
        id: String = UUID().uuidString,
        term: String,
        score: Double,
        category: SentimentCueCategory,
        domainTags: [SentimentCueDomainTag] = [.general],
        matchMode: SentimentCueMatchMode = .either
    ) {
        self.id = id
        self.term = term
        self.score = score
        self.category = category
        self.domainTags = domainTags
        self.matchMode = matchMode
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case term
        case score
        case category
        case domainTags
        case matchMode
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let score = try container.decode(Double.self, forKey: .score)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.term = try container.decode(String.self, forKey: .term)
        self.score = score
        self.category = try container.decodeIfPresent(SentimentCueCategory.self, forKey: .category)
            ?? (score >= 0 ? .corePositive : .coreNegative)
        self.domainTags = try container.decodeIfPresent([SentimentCueDomainTag].self, forKey: .domainTags) ?? [.general]
        self.matchMode = try container.decodeIfPresent(SentimentCueMatchMode.self, forKey: .matchMode) ?? .either
    }
}

struct SentimentUserLexiconBundleManifest: Equatable, Codable, Sendable {
    let id: String
    let version: String
    let author: String
    let notes: String

    init(
        id: String,
        version: String,
        author: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.version = version
        self.author = author
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case version
        case author
        case notes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? UUID().uuidString
        self.version = try container.decodeIfPresent(String.self, forKey: .version) ?? "1"
        self.author = try container.decodeIfPresent(String.self, forKey: .author) ?? ""
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

struct SentimentUserLexiconBundle: Identifiable, Equatable, Codable, Sendable {
    let manifest: SentimentUserLexiconBundleManifest
    let entries: [SentimentUserLexiconEntry]

    var id: String { manifest.id }
}

struct SentimentRuleProfile: Identifiable, Equatable, Codable, Sendable {
    let id: String
    let title: String
    let sourceKind: SentimentRuleProfileSourceKind
    var preferredPackID: SentimentDomainPackID
    var thresholdPreset: SentimentThresholdPreset
    var neutralShieldStrength: Double
    var quoteDiscountEnabled: Bool
    var quoteDiscountMultiplier: Double
    var reportingDiscountMultiplier: Double
    var customEntries: [SentimentUserLexiconEntry]
    var importedBundleIDs: [String]
    var revision: String

    init(
        id: String = "default",
        title: String = "Default",
        sourceKind: SentimentRuleProfileSourceKind = .builtInDefault,
        preferredPackID: SentimentDomainPackID = .mixed,
        thresholdPreset: SentimentThresholdPreset = .conservative,
        neutralShieldStrength: Double = 0.65,
        quoteDiscountEnabled: Bool = true,
        quoteDiscountMultiplier: Double = 0.85,
        reportingDiscountMultiplier: Double = 0.9,
        customEntries: [SentimentUserLexiconEntry] = [],
        importedBundleIDs: [String] = [],
        revision: String = "rule-profile-v1"
    ) {
        self.id = id
        self.title = title
        self.sourceKind = sourceKind
        self.preferredPackID = preferredPackID
        self.thresholdPreset = thresholdPreset
        self.neutralShieldStrength = neutralShieldStrength
        self.quoteDiscountEnabled = quoteDiscountEnabled
        self.quoteDiscountMultiplier = quoteDiscountMultiplier
        self.reportingDiscountMultiplier = reportingDiscountMultiplier
        self.customEntries = customEntries
        self.importedBundleIDs = importedBundleIDs
        self.revision = revision
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case sourceKind
        case preferredPackID
        case thresholdPreset
        case neutralShieldStrength
        case quoteDiscountEnabled
        case quoteDiscountMultiplier
        case reportingDiscountMultiplier
        case customEntries
        case importedBundleIDs
        case revision
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(String.self, forKey: .id) ?? "default"
        self.title = try container.decodeIfPresent(String.self, forKey: .title) ?? "Default"
        self.sourceKind = try container.decodeIfPresent(SentimentRuleProfileSourceKind.self, forKey: .sourceKind)
            ?? .builtInDefault
        self.preferredPackID = try container.decodeIfPresent(SentimentDomainPackID.self, forKey: .preferredPackID)
            ?? .mixed
        self.thresholdPreset = try container.decodeIfPresent(SentimentThresholdPreset.self, forKey: .thresholdPreset)
            ?? .conservative
        self.neutralShieldStrength = try container.decodeIfPresent(Double.self, forKey: .neutralShieldStrength)
            ?? 0.65
        self.quoteDiscountEnabled = try container.decodeIfPresent(Bool.self, forKey: .quoteDiscountEnabled)
            ?? true
        self.quoteDiscountMultiplier = try container.decodeIfPresent(Double.self, forKey: .quoteDiscountMultiplier)
            ?? 0.85
        self.reportingDiscountMultiplier = try container.decodeIfPresent(Double.self, forKey: .reportingDiscountMultiplier)
            ?? 0.9
        self.customEntries = try container.decodeIfPresent([SentimentUserLexiconEntry].self, forKey: .customEntries)
            ?? []
        self.importedBundleIDs = try container.decodeIfPresent([String].self, forKey: .importedBundleIDs)
            ?? []
        self.revision = try container.decodeIfPresent(String.self, forKey: .revision) ?? "rule-profile-v1"
    }

    static let `default` = SentimentRuleProfile()

    static let workspaceDefault = SentimentRuleProfile(
        id: "workspace",
        title: "Workspace",
        sourceKind: .workspace,
        preferredPackID: .mixed,
        thresholdPreset: .conservative,
        neutralShieldStrength: 0.7,
        quoteDiscountEnabled: true,
        quoteDiscountMultiplier: 0.8,
        reportingDiscountMultiplier: 0.9,
        revision: "workspace-rule-profile-v1"
    )
}

struct SentimentCalibrationProfile: Equatable, Codable, Sendable {
    var id: String
    var decisionThreshold: Double
    var minimumEvidence: Double
    var neutralBias: Double
    var domainBiasAdjustments: [String: Double]
    var preferredPackIDs: [SentimentDomainPackID]
    var revision: String

    init(
        id: String = "default",
        decisionThreshold: Double = SentimentThresholds.default.decisionThreshold,
        minimumEvidence: Double = SentimentThresholds.default.minimumEvidence,
        neutralBias: Double = SentimentThresholds.default.neutralBias,
        domainBiasAdjustments: [String: Double] = [:],
        preferredPackIDs: [SentimentDomainPackID] = [.mixed],
        revision: String = "calibration-v1"
    ) {
        self.id = id
        self.decisionThreshold = decisionThreshold
        self.minimumEvidence = minimumEvidence
        self.neutralBias = neutralBias
        self.domainBiasAdjustments = domainBiasAdjustments
        self.preferredPackIDs = preferredPackIDs
        self.revision = revision
    }

    static let `default` = SentimentCalibrationProfile()

    static let workspaceDefault = SentimentCalibrationProfile(
        id: "workspace",
        decisionThreshold: SentimentThresholds.default.decisionThreshold,
        minimumEvidence: SentimentThresholds.default.minimumEvidence,
        neutralBias: SentimentThresholds.default.neutralBias,
        domainBiasAdjustments: [
            SentimentDomainPackID.academic.rawValue: 0.15,
            SentimentDomainPackID.news.rawValue: 0.05,
            SentimentDomainPackID.kwic.rawValue: -0.05
        ],
        preferredPackIDs: [.mixed],
        revision: "calibration-workspace-v1"
    )

    func thresholds(overriding base: SentimentThresholds) -> SentimentThresholds {
        SentimentThresholds(
            decisionThreshold: decisionThreshold == 0 ? base.decisionThreshold : decisionThreshold,
            minimumEvidence: minimumEvidence == 0 ? base.minimumEvidence : minimumEvidence,
            neutralBias: neutralBias == 0 ? base.neutralBias : neutralBias
        )
    }
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
    let domainPackID: SentimentDomainPackID
    let effectiveDomainPackID: SentimentDomainPackID?
    let ruleProfile: SentimentRuleProfile
    let calibrationProfile: SentimentCalibrationProfile
    let userLexiconBundleIDs: [String]

    init(
        source: SentimentInputSource,
        unit: SentimentAnalysisUnit,
        contextBasis: SentimentContextBasis,
        thresholds: SentimentThresholds,
        texts: [SentimentInputText],
        backend: SentimentBackendKind,
        domainPackID: SentimentDomainPackID = .mixed,
        effectiveDomainPackID: SentimentDomainPackID? = nil,
        ruleProfile: SentimentRuleProfile = .default,
        calibrationProfile: SentimentCalibrationProfile = .default,
        userLexiconBundleIDs: [String] = []
    ) {
        self.source = source
        self.unit = unit
        self.contextBasis = contextBasis
        self.thresholds = thresholds
        self.texts = texts
        self.backend = backend
        self.domainPackID = domainPackID
        self.effectiveDomainPackID = effectiveDomainPackID
        self.ruleProfile = ruleProfile
        self.calibrationProfile = calibrationProfile
        self.userLexiconBundleIDs = userLexiconBundleIDs
    }

    var resolvedDomainPackID: SentimentDomainPackID {
        effectiveDomainPackID ?? domainPackID
    }

    var usesAutomaticDomainPack: Bool {
        effectiveDomainPackID != nil && effectiveDomainPackID != domainPackID
    }

    func domainPackSummary(in mode: AppLanguageMode) -> String {
        if usesAutomaticDomainPack {
            return "\(wordZText("自动", "Auto", mode: mode)) -> \(resolvedDomainPackID.title(in: mode))"
        }
        return domainPackID.title(in: mode)
    }
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
