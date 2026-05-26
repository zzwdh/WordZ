import Foundation

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

