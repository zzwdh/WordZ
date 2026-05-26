import Foundation

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

